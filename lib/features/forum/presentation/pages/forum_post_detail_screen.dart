import 'package:flutter/material.dart';
import 'package:project_v2/features/profile/presentation/pages/profile_screen.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/forum_models.dart';
import 'package:project_v2/models/user_model.dart';

class ForumPostDetailScreen extends StatefulWidget {
  final ForumPostModel post;

  const ForumPostDetailScreen({super.key, required this.post});

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final user = _firebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to reply')),
      );
      return;
    }

    final scaffoldMsg = ScaffoldMessenger.of(context);

    setState(() => _isSending = true);
    try {
      await _firebaseService.addForumReply(widget.post.id, text, user.uid);
      _replyController.clear();
    } catch (e) {
      scaffoldMsg.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _upvotePost() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    try {
      await _firebaseService.upvoteForumPost(widget.post.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
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
                    stream: _firebaseService.getForumReplies(widget.post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final replies = snapshot.data ?? [];
                      if (replies.isEmpty) {
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
                      return Column(
                        children: replies.map((reply) => _buildReplyItem(reply)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Reply Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.primary),
                        onPressed: _submitReply,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return FutureBuilder<UserModel?>(
      future: _firebaseService.getUserProfile(widget.post.userId),
      builder: (context, snapshot) {
        final authorName = snapshot.data?.name ?? 'Loading...';
        final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.post.title,
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (widget.post.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.post.description,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), height: 1.5),
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
                if (widget.post.userId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: widget.post.userId),
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
                        _timeAgo(widget.post.createdAt),
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
                    widget.post.upvotes.toString(), 
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

  Widget _buildReplyItem(ForumReplyModel reply) {
    return FutureBuilder<UserModel?>(
      future: _firebaseService.getUserProfile(reply.userId),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'User';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () {
              if (reply.userId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: reply.userId),
                  ),
                );
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  child: Text(
                    initial,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(_timeAgo(reply.createdAt), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(reply.text, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
