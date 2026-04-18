import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:project_v2/models/user_model.dart';
import 'package:project_v2/models/resource_model.dart';
import 'package:project_v2/models/comment_model.dart';
import 'package:project_v2/models/notification_model.dart';
import 'package:project_v2/models/forum_models.dart';
import 'package:project_v2/models/group_models.dart';

class FirebaseService {
  final FirebaseAuth _auth;
  final DatabaseReference _dbRef;
  final FirebaseStorage _storage;

  FirebaseService({
    FirebaseAuth? auth,
    DatabaseReference? dbRef,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _dbRef = dbRef ?? FirebaseDatabase.instance.ref(),
       _storage = storage ?? FirebaseStorage.instance;

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
    if (currentUser?.uid != uid) throw Exception('Unauthorized: You can only update your own profile.');
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
          '$currentUserName started following you!',
          senderId: currentUserId,
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

  // --- File Storage (Custom Web Server via shazid.info) ---

  Future<String> uploadResourceFile(File file, String fileName) async {
    try {
      final dio = Dio();
      FormData formData = FormData.fromMap({
        // The key 'file' must strictly match $_FILES["file"] in your upload.php
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });

      dio.options.connectTimeout = const Duration(minutes: 5);
      dio.options.receiveTimeout = const Duration(minutes: 5);

      final response = await dio.post(
        "http://shazid.info/uploadLinkup.php",
        data: formData,
      );

      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData is String) {
          responseData = jsonDecode(responseData);
        }

        if (responseData['status'] == 'success') {
          return responseData['url']; // e.g., https://shazid.info/uploads/171000_...
        } else {
          final sMsg = responseData['message'] ?? responseData['status'];
          throw Exception("Server upload failed: $sMsg");
        }
      } else {
         throw Exception("Server returned status: ${response.statusCode}");
      }
    } catch (e) {
      log('uploadResourceFile error: $e');
      throw Exception('Failed to upload file to shazid.info: $e');
    }
  }

  Future<String> uploadResourceFileWeb(dynamic bytes, String fileName) async {
    try {
      final dio = Dio();
      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(bytes as List<int>, filename: fileName),
      });

      dio.options.connectTimeout = const Duration(minutes: 5);
      dio.options.receiveTimeout = const Duration(minutes: 5);

      final response = await dio.post(
        "http://shazid.info/uploadLinkup.php",
        data: formData,
      );

      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData is String) {
          responseData = jsonDecode(responseData);
        }

        if (responseData['status'] == 'success') {
          return responseData['url'];
        } else {
          final sMsg = responseData['message'] ?? responseData['status'];
          throw Exception("Server upload failed: $sMsg");
        }
      } else {
         throw Exception("Server returned status: ${response.statusCode}");
      }
    } catch (e) {
      log('uploadResourceFileWeb error: $e');
      throw Exception('Failed to upload file to shazid.info (Web): $e');
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

  Future<bool> checkQuestionExists(String courseCode) async {
    try {
      final snapshot = await _dbRef.child('resources')
          .orderByChild('type')
          .equalTo('Question')
          .get();
      
      if (!snapshot.exists) return false;
      
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      // Check if any matching type also matches the course code
      return data.values.any((r) => 
        r is Map && 
        r['courseCode'].toString().toLowerCase() == courseCode.toLowerCase().trim()
      );
    } catch (e) {
      log('checkQuestionExists error: $e');
      return false;
    }
  }

  Future<List<ResourceModel>> getResources() async {
    try {
      final snapshot = await _dbRef.child('resources').get();
      if (!snapshot.exists) return [];
      
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) => ResourceModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>))
          .where((r) => !r.isPrivate) // Never expose private resources to callers
          .toList();
    } catch (e) {
      throw Exception('Failed to get resources: $e');
    }
  }

  Stream<List<ResourceModel>> streamResources() {
    return _dbRef.child('resources').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      
      final dynamic rawData = event.snapshot.value;
      Map<dynamic, dynamic> data = {};
      
      if (rawData is Map) {
        data = rawData;
      } else if (rawData is List) {
        // Handle case where RTDB returns a list for numeric-like keys
        for (int i = 0; i < rawData.length; i++) {
          if (rawData[i] != null) data[i.toString()] = rawData[i];
        }
      }

      final List<ResourceModel> items = [];
      data.forEach((key, value) {
        try {
          if (value is Map) {
            final resource = ResourceModel.fromMap(key.toString(), value);
            if (!resource.isPrivate) {
              items.add(resource);
            }
          }
        } catch (e) {
          log('Error parsing resource $key: $e');
        }
      });
      return items;
    });
  }

  Stream<ResourceModel?> streamResourceById(String id) {
    return _dbRef.child('resources').child(id).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final resource = ResourceModel.fromMap(id, event.snapshot.value as Map<dynamic, dynamic>);
      
      // Privacy Check: Only owner can see private resources
      if (resource.isPrivate && resource.uploaderId != currentUser?.uid) {
        return null;
      }
      return resource;
    });
  }

  double calculateTrendingScore(ResourceModel resource) {
    // 1. Engagement (downloads are good, but votes are active engagement)
    final int totalVotes = resource.upvotes.length + resource.downvotes.length;
    final int engagement = resource.downloads + (totalVotes * 5);
    
    // 2. Quality (ratings are dynamically Bayesian from 1.0 to 5.0)
    final double quality = resource.rating;
    
    // 3. Base Score
    final double baseScore = (engagement + 1) * quality;
    
    // 4. Time Decay
    final int ageInHours = DateTime.now().difference(resource.createdAt).inHours;
    // Hacker News style gravity. Items older than a week (168 hours) naturally fall off.
    const double gravity = 1.5; 
    
    return baseScore / math.pow(ageInHours + 2, gravity);
  }

  Stream<List<ResourceModel>> streamTrendingResources({int limit = 5, String? subject}) {
    return _dbRef.child('resources').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      
      final dynamic rawData = event.snapshot.value;
      Map<dynamic, dynamic> data = {};
      if (rawData is Map) data = rawData;
      else if (rawData is List) {
        for (int i = 0; i < rawData.length; i++) {
          if (rawData[i] != null) data[i.toString()] = rawData[i];
        }
      }

      var list = <ResourceModel>[];
      data.forEach((key, value) {
        try {
          if (value is Map) {
            final res = ResourceModel.fromMap(key.toString(), value);
            if (!res.isPrivate) {
              if (subject == null || subject == 'All' || res.subject == subject) {
                list.add(res);
              }
            }
          }
        } catch (e) { /* skip */ }
      });

      // Relaxation: Don't filter strictly if it results in an empty list.
      // Instead, just sort by Trending Score and take the top ones.
      list.sort((a, b) => calculateTrendingScore(b).compareTo(calculateTrendingScore(a)));
      
      return list.take(limit).toList();
    });
  }

  Stream<List<ResourceModel>> streamLatestResources({int limit = 5, String? subject}) {
    return _dbRef.child('resources').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      
      final dynamic rawData = event.snapshot.value;
      Map<dynamic, dynamic> data = {};
      if (rawData is Map) data = rawData;
      else if (rawData is List) {
        for (int i = 0; i < rawData.length; i++) {
          if (rawData[i] != null) data[i.toString()] = rawData[i];
        }
      }

      var list = <ResourceModel>[];
      data.forEach((key, value) {
        try {
          if (value is Map) {
            final res = ResourceModel.fromMap(key.toString(), value);
            if (!res.isPrivate) {
              if (subject == null || subject == 'All' || res.subject == subject) {
                list.add(res);
              }
            }
          }
        } catch (e) { /* skip */ }
      });
      
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    });
  }

  Stream<List<ResourceModel>> streamUserResources(String uid, {String? viewerUid}) {
    return _dbRef.child('resources').orderByChild('uploaderId').equalTo(uid).onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final List<ResourceModel> list = data.entries
          .map((e) => ResourceModel.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>))
          .where((r) => !r.isPrivate || (viewerUid != null && r.uploaderId == viewerUid))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> toggleResourcePrivacy(String resourceId, bool isPrivate) async {
    try {
      await _dbRef.child('resources').child(resourceId).update({'isPrivate': isPrivate});
    } catch (e) {
      throw Exception('Failed to update privacy: $e');
    }
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
        await createNotification(
          uploaderId, 
          'resource_vote', 
          'Someone $action your resource: ${data['title']}',
          targetId: resourceId,
          senderId: uid,
        );
      }

    } catch (e) {
      throw Exception('Failed to rate resource: $e');
    }
  }

  Future<void> deletePhysicalFile(String fileUrl) async {
    if (fileUrl.isEmpty || !fileUrl.contains('shazid.info')) return;
    try {
      final dio = Dio();
      FormData formData = FormData.fromMap({
        'action': 'delete',
        'file_url': fileUrl,
      });
      await dio.post(
        "http://shazid.info/uploadLinkup.php",
        data: formData,
      );
      log('Successfully sent wipe request to server for physical file.');
    } catch (e) {
      log('Failed to delete physical file from server: $e');
    }
  }

  Future<void> deleteResource(String resourceId) async {
    try {
      // Find the resource first to wipe its physical file securely!
      final snapshot = await _dbRef.child('resources').child(resourceId).get();
      if (!snapshot.exists) {
        throw Exception('Resource not found: $resourceId');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final String uploaderId = data['uploaderId'] ?? '';

      // Ownership Check
      if (uploaderId != currentUser?.uid) {
        throw Exception('Unauthorized: You are not the owner of this resource.');
      }

      if (data['fileurls'] != null) {
          await deletePhysicalFile(data['fileurls']);
      }
      
      await _dbRef.child('resources').child(resourceId).remove();
      // Also remove from user's uploads relationship
      await _dbRef.child('users').child(uploaderId).child('uploads').child(resourceId).remove();
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
              'resource_reply',
              '$commenterName replied to your comment',
              targetId: resourceId,
              senderId: userId,
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
            targetId: resourceId,
            senderId: userId,
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
      final snapshot = await _dbRef.child('comments').child(resourceId).child(commentId).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data['userId'] != currentUser?.uid) {
          throw Exception('Unauthorized: You can only delete your own comments.');
        }
      }
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

  Future<void> addForumReply(String postId, String text, String userId, {String? imageUrl, String? parentId}) async {
    try {
      final replyRef = _dbRef.child('forumReplies').child(postId).push();
      final reply = ForumReplyModel(
        id: replyRef.key!,
        userId: userId,
        text: text,
        imageUrl: imageUrl,
        parentId: parentId,
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

        // Only notify if someone else is replying
        if (ownerId.isNotEmpty && ownerId != userId) {
          await createNotification(
            ownerId,
            'forum_reply',
            '$replierName replied to your discussion "$postTitle"',
            targetId: postId,
            senderId: userId,
          );
        }
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
      final postRef = _dbRef.child('forumPosts').child(postId);
      await postRef.child('upvotes').runTransaction((Object? current) {
        if (current == null) return Transaction.success(1);
        if (current is int) return Transaction.success(current + 1);
        return Transaction.success(1);
      });

      // Notify the author about the upvote
      final snapshot = await postRef.get();
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final String ownerId = data['userId']?.toString() ?? '';
        final String postTitle = data['title']?.toString() ?? 'your post';
        final String currentUid = currentUser?.uid ?? '';

        if (ownerId.isNotEmpty && ownerId != currentUid) {
          await createNotification(
            ownerId, 
            'forum_vote', 
            'Someone upvoted your post: "$postTitle"',
            targetId: postId,
            senderId: currentUid,
          );
        }
      }
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
  Future<void> sendGroupMessage(String groupId, String text, String userId, {String? fileUrl, String? fileName}) async {
    try {
      final msgRef = _dbRef.child('groupMessages').child(groupId).push();
      final msg = MessageModel(
        id: msgRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        text: text,
        fileUrl: fileUrl,
        fileName: fileName,
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

  Future<void> createNotification(String uid, String type, String message, {String? targetId, String? senderId}) async {
    try {
      final notifRef = _dbRef.child('notifications').child(uid).push();
      final notification = NotificationModel(
        id: notifRef.key!,
        type: type,
        message: message,
        targetId: targetId,
        senderId: senderId,
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

  Future<void> markAllNotificationsRead(String uid) async {
    try {
      final snapshot = await _dbRef.child('notifications').child(uid).get();
      if (!snapshot.exists) return;

      final Map<dynamic, dynamic> notifications = snapshot.value as Map<dynamic, dynamic>;
      final Map<String, dynamic> updates = {};

      for (var entry in notifications.entries) {
        final notifData = entry.value as Map<dynamic, dynamic>;
        if (notifData['read'] == false) {
          updates['${entry.key}/read'] = true;
        }
      }

      if (updates.isNotEmpty) {
        await _dbRef.child('notifications').child(uid).update(updates);
      }
    } catch (e) {
      log('markAllNotificationsRead error: $e');
      throw Exception('Failed to clear notifications: $e');
    }
  }

  Stream<List<String>> streamSubjects() {
    return _dbRef.child('resources').onValue.map((event) {
      final defaultSubjects = ['Computer Science', 'Mathematics', 'Physics', 'Business', 'Other'];
      if (!event.snapshot.exists) return defaultSubjects;
      
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final subjects = <String>{...defaultSubjects};
      
      for (var entry in data.values) {
        // Only collect subjects from PUBLIC resources to avoid leaking private resource metadata
        if (entry is Map && entry['subject'] != null && entry['isPrivate'] != true) {
          subjects.add(entry['subject'].toString());
        }
      }
      final list = subjects.toList();
      list.sort((a, b) {
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        return a.compareTo(b);
      });
      return list;
    });
  }

  Future<void> updateProfilePicture(String uid, File file) async {
    try {
      final String fileName = 'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String imageUrl = await uploadResourceFile(file, fileName);
      await _dbRef.child('users').child(uid).update({'profileImage': imageUrl});
    } catch (e) {
      log('updateProfilePicture error: $e');
      throw Exception('Failed to update profile picture: $e');
    }
  }

  Future<void> updateProfilePictureWeb(String uid, dynamic bytes) async {
    try {
      final String fileName = 'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String imageUrl = await uploadResourceFileWeb(bytes, fileName);
      await _dbRef.child('users').child(uid).update({'profileImage': imageUrl});
    } catch (e) {
      log('updateProfilePicture error: $e');
      throw Exception('Failed to update profile picture: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      log('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      log('sendPasswordResetEmail error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Failed to send reset email');
    } catch (e) {
      log('sendPasswordResetEmail unexpected error: $e');
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // --- Top Contributors ---

  /// Fetches all users, computes their contributor score, assigns a tier level,
  /// and returns a list sorted by score descending.
  Future<List<ContributorModel>> getTopContributors({int limit = 50}) async {
    try {
      // 1. Fetch all users
      final usersSnap = await _dbRef.child('users').get();
      if (!usersSnap.exists) return [];
      final usersMap = usersSnap.value as Map<dynamic, dynamic>;

      // 2. Fetch all PUBLIC resources once
      final resourcesSnap = await _dbRef.child('resources').get();
      Map<dynamic, dynamic> allResources = {};
      if (resourcesSnap.exists && resourcesSnap.value != null) {
        final raw = resourcesSnap.value;
        if (raw is Map) allResources = raw;
      }

      // 3. Pre-group resources by uploaderId for fast lookup
      final Map<String, List<Map<dynamic, dynamic>>> resourcesByUser = {};
      allResources.forEach((key, value) {
        if (value is Map && value['isPrivate'] != true) {
          final uid = value['uploaderId']?.toString() ?? '';
          if (uid.isNotEmpty) {
            resourcesByUser.putIfAbsent(uid, () => []);
            resourcesByUser[uid]!.add(value);
          }
        }
      });

      // 4. Build ContributorModel for each user
      final List<ContributorModel> contributors = [];
      usersMap.forEach((uid, userData) {
        try {
          if (userData is! Map) return;
          final user = UserModel.fromMap(uid.toString(), userData);
          final userResources = resourcesByUser[uid.toString()] ?? [];

          final int uploadCount = userResources.length;
          final int followerCount = user.followers.length;

          double totalRating = 0;
          int totalDownloads = 0;
          for (final r in userResources) {
            totalRating += (r['rating'] ?? 0.0) is num
                ? (r['rating'] as num).toDouble()
                : 0.0;
            totalDownloads += (r['downloads'] ?? 0) is int
                ? (r['downloads'] as int)
                : int.tryParse(r['downloads'].toString()) ?? 0;
          }
          final double avgRating =
              uploadCount > 0 ? totalRating / uploadCount : 0.0;

          // Composite score formula
          final double score = (uploadCount * 10) +
              (followerCount * 5) +
              (avgRating * 15) +
              (totalDownloads * 1);

          contributors.add(ContributorModel(
            user: user,
            uploadCount: uploadCount,
            followerCount: followerCount,
            avgRating: avgRating,
            totalDownloads: totalDownloads,
            score: score,
          ));
        } catch (e) {
          log('getTopContributors: error parsing user $uid: $e');
        }
      });

      // 5. Sort by score descending, take top [limit]
      contributors.sort((a, b) => b.score.compareTo(a.score));
      return contributors.take(limit).toList();
    } catch (e) {
      log('getTopContributors error: $e');
      throw Exception('Failed to fetch top contributors: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Contributor data model (lives here for locality — no extra file needed)
// ---------------------------------------------------------------------------

enum ContributorLevel {
  legend,
  diamond,
  platinum,
  gold,
  silver,
  bronze,
}

class ContributorModel {
  final UserModel user;
  final int uploadCount;
  final int followerCount;
  final double avgRating;
  final int totalDownloads;
  final double score;

  ContributorModel({
    required this.user,
    required this.uploadCount,
    required this.followerCount,
    required this.avgRating,
    required this.totalDownloads,
    required this.score,
  });

  ContributorLevel get level {
    if (score >= 500) return ContributorLevel.legend;
    if (score >= 200) return ContributorLevel.diamond;
    if (score >= 100) return ContributorLevel.platinum;
    if (score >= 50)  return ContributorLevel.gold;
    if (score >= 20)  return ContributorLevel.silver;
    return ContributorLevel.bronze;
  }

  String get levelName {
    switch (level) {
      case ContributorLevel.legend:   return 'Legend';
      case ContributorLevel.diamond:  return 'Diamond';
      case ContributorLevel.platinum: return 'Platinum';
      case ContributorLevel.gold:     return 'Gold';
      case ContributorLevel.silver:   return 'Silver';
      case ContributorLevel.bronze:   return 'Bronze';
    }
  }
}


