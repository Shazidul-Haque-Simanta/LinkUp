import 'package:flutter/material.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/forum_models.dart';
import 'package:project_v2/features/forum/presentation/pages/forum_post_detail_screen.dart';

class DiscussionForumScreen extends StatefulWidget {
  const DiscussionForumScreen({super.key});

  @override
  State<DiscussionForumScreen> createState() => _DiscussionForumScreenState();
}

class _DiscussionForumScreenState extends State<DiscussionForumScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAskQuestionDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ask a Question', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title / Subject',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Details',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              
              final user = _firebaseService.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You must be logged in to post')),
                );
                return;
              }

              final newPost = ForumPostModel(
                id: '',
                title: titleController.text.trim(),
                description: descController.text.trim(),
                userId: user.uid,
                createdAt: DateTime.now(),
              );

              final nav = Navigator.of(context);
              final scaffoldMsg = ScaffoldMessenger.of(context);

              try {
                nav.pop();
                await _firebaseService.createForumPost(newPost);
              } catch (e) {
                scaffoldMsg.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Ask'),
          ),
        ],
      ),
    );
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
          'Discussion Forum',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface), onPressed: _showAskQuestionDialog),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [

          FloatingActionButton.extended(
            heroTag: 'create_post_btn',
            onPressed: _showAskQuestionDialog,
            backgroundColor: Theme.of(context).colorScheme.primary,
            icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
            label: Text('Start Discussion', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      hintText: 'Search discussions...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _showAskQuestionDialog,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Ask a Question', 
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: StreamBuilder<List<ForumPostModel>>(
                stream: _firebaseService.streamForumPosts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final posts = snapshot.data ?? [];
                  
                  final filteredPosts = _searchQuery.isEmpty 
                    ? posts 
                    : posts.where((p) => p.title.toLowerCase().contains(_searchQuery) || p.description.toLowerCase().contains(_searchQuery)).toList();

                  if (filteredPosts.isEmpty) {
                    return const Center(child: Text('No posts found', style: TextStyle(color: Colors.grey)));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredPosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = filteredPosts[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ForumPostDetailScreen(post: post),
                          ),
                        ),
                        child: _forumTopic(post),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _forumTopic(ForumPostModel post) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPostDetails(post),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {'author': 'Loading...', 'replies': 0};
        final authorName = data['author'];
        final replyCount = data['replies'];
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
                ],
              ),
              if (post.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.description,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'by $authorName',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  const Spacer(),
                  _statItem(Icons.thumb_up_alt_outlined, post.upvotes.toString()),
                  const SizedBox(width: 16),
                  _statItem(Icons.chat_bubble_outline, replyCount.toString()),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
  
  Future<Map<String, dynamic>> _fetchPostDetails(ForumPostModel post) async {
    String authorName = 'Unknown User';
    int replyCount = 0;
    
    try {
      final userModel = await _firebaseService.getUserProfile(post.userId);
      if (userModel != null) {
        authorName = userModel.name;
      }
      
      final replies = await _firebaseService.getForumReplies(post.id).first;
      replyCount = replies.length;
    } catch (e) {
      // Return defaults on error
    }
    
    return {'author': authorName, 'replies': replyCount};
  }

  Widget _statItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}
