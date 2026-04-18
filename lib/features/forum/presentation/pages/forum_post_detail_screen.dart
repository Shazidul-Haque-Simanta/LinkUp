import 'package:flutter/material.dart';
import 'package:project_v2/features/profile/presentation/pages/profile_screen.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/forum_models.dart';
import 'package:project_v2/models/user_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;

class ForumPostDetailScreen extends StatefulWidget {
  final ForumPostModel? post;
  final String? postId;

  const ForumPostDetailScreen({super.key, this.post, this.postId});

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;
  ForumPostModel? _post; // Local copy to handle postId fetching
  bool _isLoadingPost = false;
  
  // Nesting & Media State
  String? _replyingToId;
  String? _replyingToName;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    if (_post == null && widget.postId != null) {
      _fetchPost();
    }
  }

  Future<void> _fetchPost() async {
    setState(() => _isLoadingPost = true);
    try {
      final snapshot = await _firebaseService.getForumPosts(); // Or a specific getForumPost(id)
      // Since there's no getForumPostById, I'll use the list or add one.
      // Firebase RTDB get() is better.
      final postSnapshot = await _firebaseService.getUserProfile(widget.postId!); // Wait, this is user.
      // I'll just find it in the list for now or assume I have a stream.
      // Better: Use streamForumPosts and find the one.
      _firebaseService.streamForumPosts().first.then((posts) {
        if (mounted) {
          setState(() {
            final foundPost = posts.any((p) => p.id == widget.postId) 
                ? posts.firstWhere((p) => p.id == widget.postId)
                : null;
            _post = foundPost;
            _isLoadingPost = false;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingPost = false);
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) return;

    final user = _firebaseService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to reply')),
        );
      }
      return;
    }

    setState(() => _isSending = true);
    try {
      String? imageUrl;
      if (_selectedImageBytes != null) {
        if (kIsWeb) {
          imageUrl = await _firebaseService.uploadResourceFileWeb(_selectedImageBytes!, _selectedImageName!);
        } else {
          imageUrl = await _firebaseService.uploadResourceFileWeb(_selectedImageBytes!, _selectedImageName!);
        }
      }

      await _firebaseService.addForumReply(
        _post!.id, 
        text, 
        user.uid,
        imageUrl: imageUrl,
        parentId: _replyingToId,
      );
      
      _replyController.clear();
      _cancelReplyMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _cancelReplyMode() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _upvotePost() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    try {
      if (_post != null) {
        await _firebaseService.upvoteForumPost(_post!.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPost) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Post...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Not Found')),
        body: const Center(child: Text('This discussion may have been deleted.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Discussion',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post Header
                  _buildPostHeader(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Replies',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Replies Stream
                  StreamBuilder<List<ForumReplyModel>>(
                    stream: _firebaseService.getForumReplies(_post!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final allReplies = snapshot.data ?? [];
                      if (allReplies.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.0),
                            child: Text(
                              'No replies yet. Be the first to reply!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      // Group replies: Top-level vs Children
                      final topLevel = allReplies.where((r) => r.parentId == null).toList();
                      final children = allReplies.where((r) => r.parentId != null).toList();

                      return Column(
                        children: topLevel.map((reply) {
                          // Find children for this specific reply
                          final replyChildren = children.where((c) => c.parentId == reply.id).toList();
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReplyItem(reply),
                              if (replyChildren.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 32.0),
                                  child: Column(
                                    children: replyChildren.map((child) => _buildReplyItem(child, isChild: true)).toList(),
                                  ),
                                ),
                            ],
                          ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Reply Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingToId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.reply, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Replying to $_replyingToName',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: _cancelReplyMode,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(alignment: Alignment.centerLeft),
                
                if (_selectedImageBytes != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 100,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover, width: 100, height: 100),
                        ),
                        Positioned(
                          top: 4,
                          left: 70,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 12, color: Colors.white),
                              onPressed: () => setState(() => _selectedImageBytes = null),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),

                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.primary),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(type: FileType.image);
                        if (result != null) {
                          setState(() {
                            _selectedImageBytes = result.files.first.bytes;
                            _selectedImageName = result.files.first.name;
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: InputDecoration(
                          hintText: _replyingToId == null ? 'Write a reply...' : 'Write a nested reply...',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSending
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.primary),
                            onPressed: _submitReply,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    if (_post == null) return const SizedBox.shrink();

    return FutureBuilder<UserModel?>(
      future: _firebaseService.getUserProfile(_post!.userId),
      builder: (context, snapshot) {
        final authorName = snapshot.data?.name ?? 'Loading...';
        final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _post!.title,
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (_post!.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _post!.description,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), height: 1.5),
              ),
            ],
            if (_post!.imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Hero(
                  tag: 'post_image_${_post!.id}',
                  child: Image.network(
                    _post!.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 200,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: GestureDetector(
              onTap: () {
                if (_post!.userId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: _post!.userId),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      initial,
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName, 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        )
                      ),
                      Text(
                        _timeAgo(_post!.createdAt),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.thumb_up_alt_outlined, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    onPressed: _upvotePost,
                  ),
                  Text(
                    _post!.upvotes.toString(), 
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      },
    );
  }

  Widget _buildReplyItem(ForumReplyModel reply, {bool isChild = false}) {
    return FutureBuilder<UserModel?>(
      future: _firebaseService.getUserProfile(reply.userId),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'User';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: reply.userId))),
                child: CircleAvatar(
                  radius: isChild ? 12 : 14,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    initial,
                    style: TextStyle(fontSize: isChild ? 10 : 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.only(
                          topRight: const Radius.circular(16),
                          bottomLeft: const Radius.circular(16),
                          bottomRight: const Radius.circular(16),
                          topLeft: isChild ? const Radius.circular(16) : Radius.zero,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          if (reply.imageUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(reply.imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(reply.text, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(_timeAgo(reply.createdAt), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
                        const SizedBox(width: 16),
                        if (!isChild)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _replyingToId = reply.id;
                                _replyingToName = name;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
