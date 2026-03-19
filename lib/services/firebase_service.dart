import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:developer';
import 'package:project_v2/models/user_model.dart';
import 'package:project_v2/models/resource_model.dart';
import 'package:project_v2/models/comment_model.dart';
import 'package:project_v2/models/notification_model.dart';
import 'package:project_v2/models/forum_models.dart';
import 'package:project_v2/models/group_models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- Auth Helpers ---

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signOut() async => _auth.signOut();

  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Sign up failed');
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Sign in failed');
    }
  }

  // --- User Management ---

  Future<void> createUserProfile(UserModel user) async {
    try {
      await _dbRef.child('users').child(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final snapshot = await _dbRef.child('users').child(uid).get();
      if (snapshot.exists) {
        return UserModel.fromMap(uid, snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _dbRef.child('users').child(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // --- Follower System ---

  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      // 1. Add targetUserId to currentUser's 'following' list
      await _dbRef.child('users').child(currentUserId).child('following').child(targetUserId).set(true);
      
      // 2. Add currentUserId to targetUser's 'followers' list
      await _dbRef.child('users').child(targetUserId).child('followers').child(currentUserId).set(true);

      // 3. Send a notification to the targetUser
      final currentUserSnapshot = await _dbRef.child('users').child(currentUserId).get();
      if (currentUserSnapshot.exists) {
        final data = currentUserSnapshot.value as Map<dynamic, dynamic>;
        final currentUserName = data['name'] ?? 'Someone';
        await createNotification(
          targetUserId, 
          'follow', 
          '$currentUserName started following you!'
        );
      }
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      // 1. Remove target from currentUser's following
      await _dbRef.child('users').child(currentUserId).child('following').child(targetUserId).remove();
      
      // 2. Remove currentUser from targetUser's followers
      await _dbRef.child('users').child(targetUserId).child('followers').child(currentUserId).remove();
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  Stream<bool> checkIfFollowing(String currentUserId, String targetUserId) {
    return _dbRef.child('users').child(currentUserId).child('following').child(targetUserId).onValue.map((event) {
      return event.snapshot.exists;
    });
  }

  // --- File Storage ---

  Future<String> uploadResourceFile(File file, String fileName) async {
    try {
      final ref = _storage.ref().child('resources').child(fileName);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<String> uploadResourceFileWeb(dynamic bytes, String fileName) async {
    try {
      final ref = _storage.ref().child('resources').child(fileName);
      final uploadTask = await ref.putData(bytes);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file (Web): $e');
    }
  }

  // --- Resource System ---

  Future<String> createResource(ResourceModel resource) async {
    try {
      final newResourceRef = _dbRef.child('resources').push();
      final resourceId = newResourceRef.key!;
      
      // 1. Create the resource entry
      await newResourceRef.set(resource.toMap());
      
      // 2. Add to user's uploads (Relationship)
      await _dbRef.child('users').child(resource.uploaderId).child('uploads').child(resourceId).set(true);
      
      return resourceId;
    } catch (e) {
      throw Exception('Failed to create resource: $e');
    }
  }

  Future<List<ResourceModel>> getResources() async {
    try {
      final snapshot = await _dbRef.child('resources').get();
      if (!snapshot.exists) return [];
      
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((e) => ResourceModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to get resources: $e');
    }
  }

  Stream<List<ResourceModel>> streamResources() {
    return _dbRef.child('resources').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((e) => ResourceModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
    });
  }

  Stream<ResourceModel?> streamResourceById(String id) {
    return _dbRef.child('resources').child(id).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return ResourceModel.fromMap(id, event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  Stream<List<ResourceModel>> streamTrendingResources({int limit = 5}) {
    // We stream all resources and sort locally because Firebase RTDB 
    // requires strict indexing for orderByChild, and we later filter by Subject.
    return _dbRef.child('resources').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final List<ResourceModel> list = data.entries
          .map((e) => ResourceModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>))
          .toList();
      list.sort((a, b) => b.downloads.compareTo(a.downloads));
      return list.take(limit).toList();
    });
  }

  Stream<List<ResourceModel>> streamLatestResources({int limit = 5}) {
    return _dbRef.child('resources').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final List<ResourceModel> list = data.entries
          .map((e) => ResourceModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    });
  }

  Stream<List<ResourceModel>> streamUserResources(String uid) {
    return _dbRef.child('resources').orderByChild('uploaderId').equalTo(uid).onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final List<ResourceModel> list = data.entries
          .map((e) => ResourceModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> incrementDownloadCount(String resourceId) async {
    try {
      await _dbRef.child('resources').child(resourceId).child('downloads').runTransaction((Object? post) {
        if (post == null) return Transaction.success(1);
        if (post is int) return Transaction.success(post + 1);
        return Transaction.success(1);
      });
    } catch (e) {
      log('Failed to increment download count: $e');
    }
  }

  // --- Intelligent Rating System ---

  Future<void> rateResource(String resourceId, String uid, bool isUpvote) async {
    try {
      final resourceRef = _dbRef.child('resources').child(resourceId);
      
      // Update the user's vote in the database maps
      if (isUpvote) {
        await resourceRef.child('upvotes').child(uid).set(true);
        await resourceRef.child('downvotes').child(uid).remove(); // Remove downvote if switching
      } else {
        await resourceRef.child('downvotes').child(uid).set(true);
        await resourceRef.child('upvotes').child(uid).remove(); // Remove upvote if switching
      }

      // Recalculate intelligence rating
      final snapshot = await resourceRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final upvotes = (data['upvotes'] as Map<dynamic, dynamic>?)?.length ?? 0;
      final downvotes = (data['downvotes'] as Map<dynamic, dynamic>?)?.length ?? 0;

      // Intelligent Rating Formula (Wilson Score adjusted to 1.0 - 5.0 scale)
      // A pure (upvotes / total) is too volatile for 1 vote. We add Bayesian smoothing.
      final totalVotes = upvotes + downvotes;
      double newRating = 0.0;
      
      if (totalVotes > 0) {
        // Assume every resource starts with a baseline '3' star rating (neutral/good).
        // The more votes, the closer the rating gets to the actual (upvotes/total * 5)
        const int baselineVotes = 3; 
        const double baselineRating = 3.0; // Starts at 3.0 out of 5.0

        double rawScore = (upvotes / totalVotes) * 5.0; // 0.0 to 5.0 based strictly on popularity
        
        // Bayesian Average calculation
        newRating = ((baselineVotes * baselineRating) + (totalVotes * rawScore)) / (baselineVotes + totalVotes);
        
        // Clamp between 1.0 and 5.0
        if (newRating < 1.0) newRating = 1.0;
        if (newRating > 5.0) newRating = 5.0;
        
        // Round to 1 decimal place
        newRating = double.parse(newRating.toStringAsFixed(1));
      }

      await resourceRef.child('rating').set(newRating);

      // Create notification for the uploader about the vote
      final String uploaderId = data['uploaderId'] ?? '';
      if (uploaderId.isNotEmpty && uploaderId != uid) {
        final action = isUpvote ? 'upvoted' : 'downvoted';
        await createNotification(uploaderId, 'vote', 'Someone $action your resource: ${data['title']}');
      }

    } catch (e) {
      throw Exception('Failed to rate resource: $e');
    }
  }

  Future<void> deleteResource(String resourceId) async {
    try {
      await _dbRef.child('resources').child(resourceId).remove();
    } catch (e) {
      throw Exception('Failed to delete resource: $e');
    }
  }

  // --- Comments ---

  Future<void> addComment(String resourceId, String text, String userId, {String? parentId}) async {
    try {
      final commentRef = _dbRef.child('comments').child(resourceId).push();
      final comment = CommentModel(
        id: commentRef.key!,
        userId: userId,
        text: text,
        createdAt: DateTime.now(),
        parentId: parentId,
      );
      await commentRef.set(comment.toMap());

      // Fetch the commenter's name
      final userSnapshot = await _dbRef.child('users').child(userId).get();
      String commenterName = 'Someone';
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        commenterName = userData['name'] ?? 'Someone';
      }

      // 1. Notify the Parent Commenter (if it's a reply)
      if (parentId != null) {
        final parentCommentSnapshot = await _dbRef.child('comments').child(resourceId).child(parentId).get();
        if (parentCommentSnapshot.exists) {
          final parentData = parentCommentSnapshot.value as Map<dynamic, dynamic>;
          final parentUserId = parentData['userId']?.toString() ?? '';
          
          if (parentUserId.isNotEmpty && parentUserId != userId) {
            log('addComment -> Notifying parent commenter: $parentUserId');
            await createNotification(
              parentUserId,
              'reply',
              '$commenterName replied to your comment',
            );
          }
        }
      }

      // 2. Notify the Resource Owner
      final resourceSnapshot = await _dbRef.child('resources').child(resourceId).get();
      if (resourceSnapshot.exists) {
        final resourceData = resourceSnapshot.value as Map<dynamic, dynamic>;
        final String ownerId = resourceData['uploaderId']?.toString() ?? '';
        final String resourceTitle = resourceData['title']?.toString() ?? 'your resource';

        // Only notify if someone else is commenting
        if (ownerId.isNotEmpty && ownerId != userId) {
          log('addComment -> Notifying resource owner: $ownerId');
          await createNotification(
            ownerId,
            'comment',
            '$commenterName commented on "$resourceTitle"',
          );
        }
      }
    } catch (e) {
      log('addComment error: $e');
      throw Exception('Failed to add comment: $e');
    }
  }

  Stream<List<CommentModel>> getComments(String resourceId) {
    return _dbRef.child('comments').child(resourceId).onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((e) => CommentModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
    });
  }

  Future<void> deleteComment(String resourceId, String commentId) async {
    try {
      await _dbRef.child('comments').child(resourceId).child(commentId).remove();
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  // --- Bookmarks ---

  Future<void> bookmarkResource(String uid, String resourceId) async {
    try {
      await _dbRef.child('bookmarks').child(uid).child(resourceId).set(true);
    } catch (e) {
      throw Exception('Failed to bookmark resource: $e');
    }
  }

  Future<void> removeBookmark(String uid, String resourceId) async {
    try {
      await _dbRef.child('bookmarks').child(uid).child(resourceId).remove();
    } catch (e) {
      throw Exception('Failed to remove bookmark: $e');
    }
  }

  Future<List<String>> getUserBookmarks(String uid) async {
    try {
      final snapshot = await _dbRef.child('bookmarks').child(uid).get();
      if (!snapshot.exists) return [];
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return data.keys.map((e) => e.toString()).toList();
    } catch (e) {
      throw Exception('Failed to get bookmarks: $e');
    }
  }

  Stream<List<String>> streamUserBookmarkIds(String uid) {
    return _dbRef.child('bookmarks').child(uid).onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.keys.map((e) => e.toString()).toList();
    });
  }

  // --- Forum ---

  Future<void> createForumPost(ForumPostModel post) async {
    try {
      final postRef = _dbRef.child('forumPosts').push();
      await postRef.set(post.toMap());
    } catch (e) {
      throw Exception('Failed to create forum post: $e');
    }
  }

  Future<List<ForumPostModel>> getForumPosts() async {
    try {
      final snapshot = await _dbRef.child('forumPosts').get();
      if (!snapshot.exists) return [];
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((e) => ForumPostModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to get forum posts: $e');
    }
  }

  Stream<List<ForumPostModel>> streamForumPosts() {
    return _dbRef.child('forumPosts').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final posts = data.entries.map((e) => ForumPostModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Future<void> addForumReply(String postId, String text, String userId) async {
    try {
      final replyRef = _dbRef.child('forumReplies').child(postId).push();
      final reply = ForumReplyModel(
        id: replyRef.key!,
        userId: userId,
        text: text,
        createdAt: DateTime.now(),
      );
      await replyRef.set(reply.toMap());

      // Fetch the replier's name
      final userSnapshot = await _dbRef.child('users').child(userId).get();
      String replierName = 'Someone';
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        replierName = userData['name'] ?? 'Someone';
      }

      // Trigger notification for the forum post owner
      final postSnapshot = await _dbRef.child('forumPosts').child(postId).get();
      if (postSnapshot.exists) {
        final postData = postSnapshot.value as Map<dynamic, dynamic>;
        final String ownerId = postData['userId']?.toString() ?? '';
        final String postTitle = postData['title']?.toString() ?? 'your post';

        log('addForumReply -> Post: $postTitle, OwnerID: $ownerId, UserID: $userId');

        // Only notify if someone else is replying
        if (ownerId.isNotEmpty && ownerId != userId) {
          log('addForumReply -> Triggering createNotification for $ownerId');
          await createNotification(
            ownerId,
            'reply',
            '$replierName replied to your discussion "$postTitle"',
          );
        } else {
          log('addForumReply -> Did not notify: ownerId is empty ($ownerId) or equals userId ($userId)');
        }
      } else {
        log('addForumReply -> Snapshot does not exist for forumPosts/$postId');
      }
    } catch (e) {
      log('addForumReply error: $e');
      throw Exception('Failed to add forum reply: $e');
    }
  }

  Stream<List<ForumReplyModel>> getForumReplies(String postId) {
    return _dbRef.child('forumReplies').child(postId).onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final replies = data.entries.map((e) => ForumReplyModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return replies;
    });
  }

  Future<void> upvoteForumPost(String postId) async {
    try {
      await _dbRef.child('forumPosts').child(postId).child('upvotes').runTransaction((Object? current) {
        if (current == null) return Transaction.success(1);
        if (current is int) return Transaction.success(current + 1);
        return Transaction.success(1);
      });
    } catch (e) {
      log('Error upvoting post: $e');
    }
  }

  // --- Study Groups ---

  Future<String> createGroup(GroupModel group) async {
    try {
      final groupRef = _dbRef.child('groups').push();
      await groupRef.set(group.toMap());
      return groupRef.key!;
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  Future<void> joinGroup(String groupId, String userId) async {
    try {
      await _dbRef.child('groups').child(groupId).child('members').update({
        userId: true,
      });
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }

  // --- Group Chat Methods ---
  Future<void> sendGroupMessage(String groupId, String text, String userId) async {
    try {
      final msgRef = _dbRef.child('groupMessages').child(groupId).push();
      final msg = MessageModel(
        id: msgRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        text: text,
        createdAt: DateTime.now(),
      );
      await msgRef.set(msg.toMap());
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Stream<List<MessageModel>> listenToGroupMessages(String groupId) {
    return _dbRef.child('groupMessages').child(groupId).orderByChild('createdAt').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final List<MessageModel> messages = data.entries
          .map((e) => MessageModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>))
          .toList();
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Oldest first
      return messages;
    });
  }

  Future<List<GroupModel>> getGroups() async {
    try {
      final snapshot = await _dbRef.child('groups').get();
      if (!snapshot.exists) return [];
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((e) => GroupModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to get groups: $e');
    }
  }

  Stream<List<GroupModel>> streamGroups() {
    return _dbRef.child('groups').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((e) => GroupModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
    });
  }



  // --- Notifications ---

  Future<void> createNotification(String uid, String type, String message) async {
    try {
      final notifRef = _dbRef.child('notifications').child(uid).push();
      final notification = NotificationModel(
        id: notifRef.key!,
        type: type,
        message: message,
        createdAt: DateTime.now(),
      );
      await notifRef.set(notification.toMap());
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  Stream<List<NotificationModel>> getUserNotifications(String uid) {
    return _dbRef.child('notifications').child(uid).onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((e) => NotificationModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>)).toList();
    });
  }

  Future<void> markNotificationRead(String uid, String notificationId) async {
    try {
      await _dbRef.child('notifications').child(uid).child(notificationId).update({'read': true});
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }
}
