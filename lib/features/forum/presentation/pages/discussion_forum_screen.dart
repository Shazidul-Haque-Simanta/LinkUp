import 'package:flutter/material.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/forum_models.dart';
import 'package:project_v2/features/forum/presentation/pages/forum_post_detail_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

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
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('Start Discussion', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title / Topic',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Details (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                // Image Picker / Preview
                if (selectedImageBytes != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(selectedImageBytes!, height: 150, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setDialogState(() {
                            selectedImageBytes = null;
                            selectedImageName = null;
                          }),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null) {
                        setDialogState(() {
                          selectedImageBytes = result.files.first.bytes;
                          selectedImageName = result.files.first.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Add Image'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (titleController.text.trim().isEmpty) return;
                
                final user = _firebaseService.currentUser;
                if (user == null) return;

                setDialogState(() => isUploading = true);

                try {
                  String? imageUrl;
                  if (selectedImageBytes != null) {
                    if (kIsWeb) {
                      imageUrl = await _firebaseService.uploadResourceFileWeb(selectedImageBytes!, selectedImageName!);
                    } else {
                      // Fallback for native if needed, assuming the same helper works or similar
                      // For now using web helper logic as it's a common pattern in your app
                      imageUrl = await _firebaseService.uploadResourceFileWeb(selectedImageBytes!, selectedImageName!);
                    }
                  }

                  final newPost = ForumPostModel(
                    id: '',
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                    userId: user.uid,
                    imageUrl: imageUrl,
                    createdAt: DateTime.now(),
                  );

                  await _firebaseService.createForumPost(newPost);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  setDialogState(() => isUploading = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: isUploading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Post'),
            ),
          ],
        ),
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
                        child: _forumTopic(post)
                            .animate(delay: (40 * index).ms)
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
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
              if (post.imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Hero(
                    tag: 'post_image_${post.id}',
                    child: Image.network(
                      post.imageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
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
