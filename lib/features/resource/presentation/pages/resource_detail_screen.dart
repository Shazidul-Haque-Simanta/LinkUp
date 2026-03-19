import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:project_v2/features/resource/presentation/pages/pdf_preview_screen.dart';
import 'package:project_v2/features/profile/presentation/pages/profile_screen.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/resource_model.dart';
import 'package:project_v2/models/user_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:project_v2/models/comment_model.dart';

class ResourceDetailScreen extends StatefulWidget {
  final String? resourceId;
  const ResourceDetailScreen({super.key, this.resourceId});

  @override
  State<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends State<ResourceDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _commentController = TextEditingController();
  bool _isSendingComment = false;
  String? _replyToCommentId;
  String? _replyToUserName;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No URL provided for this resource')),
        );
      }
      return;
    }

    // Ensure the URL has a scheme (http/https)
    String finalUrl = urlString;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final Uri url = Uri.parse(finalUrl);
    try {
      // On web, launchUrl usually works without canLaunchUrl if it's a valid web URL
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched) {
        // Increment the download/visitor counter
        if (widget.resourceId != null) {
          await _firebaseService.incrementDownloadCount(widget.resourceId!);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $finalUrl')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.resourceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid Resource ID')),
      );
    }

    return StreamBuilder<ResourceModel?>(
      stream: _firebaseService.streamResourceById(widget.resourceId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text(snapshot.hasError ? 'Error: ${snapshot.error}' : 'Resource not found')),
          );
        }

        final resource = snapshot.data!;
        
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
              'Resource Detail',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () {},
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PDF Preview Area
                GestureDetector(
                  onTap: () {
                    if (resource.fileurls.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfPreviewScreen(
                            pdfUrl: resource.fileurls,
                            resourceId: resource.id,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getTypeIcon(resource.type), size: 48, color: _getTypeColor(resource.type)),
                        const SizedBox(height: 16),
                        Text(
                          'Tap to preview file', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${resource.type} · ${resource.subject}', 
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), 
                            fontSize: 12
                          )
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                // Title
                Text(
                  resource.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ).animate(delay: 100.ms).fade(duration: 400.ms).slideX(begin: -0.05, curve: Curves.easeOutQuad),
                const SizedBox(height: 16),
                // Uploader Info
                FutureBuilder<UserModel?>(
                  future: _firebaseService.getUserProfile(resource.uploaderId),
                  builder: (context, userSnapshot) {
                    final userName = userSnapshot.data?.name ?? 'Loading...';
                    final university = userSnapshot.data?.university ?? 'Department';
                    
                    return GestureDetector(
                      onTap: () {
                        if (resource.uploaderId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: resource.uploaderId),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userName, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                              Text('$university · ${_getTimeAgo(resource.createdAt)}', 
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ).animate(delay: 200.ms).fade(duration: 400.ms).slideX(begin: 0.05, curve: Curves.easeOutQuad);
                  },
                ),
                const SizedBox(height: 20),
                // Stats
                Row(
                  children: [
                    _statChip(Icons.star, resource.rating.toStringAsFixed(1), Colors.amber),
                    const SizedBox(width: 8),
                    _statChip(Icons.arrow_downward, '${_formatDownloads(resource.downloads)} downloads', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    _statChip(Icons.book_outlined, resource.courseCode, Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ],
                ).animate(delay: 300.ms).fade(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutQuad),
                const SizedBox(height: 16),
                // Intelligent Rating System (Upvotes/Downvotes)
                Row(
                  children: [
                    _voteButton(
                      idleIcon: Icons.thumb_up_alt_outlined, 
                      activeIcon: Icons.thumb_up_alt, 
                      count: resource.upvotes.length, 
                      isActive: resource.upvotes.containsKey(_firebaseService.currentUser?.uid), 
                      activeColor: Colors.blue, 
                      onTap: () {
                        final uid = _firebaseService.currentUser?.uid;
                        if (uid != null) {
                          _firebaseService.rateResource(resource.id, uid, true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to vote')));
                        }
                      }
                    ),
                    const SizedBox(width: 12),
                    _voteButton(
                      idleIcon: Icons.thumb_down_alt_outlined, 
                      activeIcon: Icons.thumb_down_alt, 
                      count: resource.downvotes.length, 
                      isActive: resource.downvotes.containsKey(_firebaseService.currentUser?.uid), 
                      activeColor: Colors.red, 
                      onTap: () {
                        final uid = _firebaseService.currentUser?.uid;
                        if (uid != null) {
                          _firebaseService.rateResource(resource.id, uid, false);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to vote')));
                        }
                      }
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Description
                Text(
                  resource.description,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), height: 1.5),
                ),
                const SizedBox(height: 12),
                // Clickable Link
                GestureDetector(
                  onTap: () => _launchURL(resource.fileurls),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          resource.fileurls,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tags
                if (resource.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: resource.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text('#$tag', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                    )).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
                // Actions
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: () => _launchURL(resource.fileurls),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Download Resource', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<List<String>>(
                      stream: _firebaseService.streamUserBookmarkIds(_firebaseService.currentUser?.uid ?? ''),
                      builder: (context, snapshot) {
                        final isBookmarked = snapshot.data?.contains(resource.id) ?? false;
                        return _iconAction(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border, 
                          isBookmarked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), 
                          () async {
                            final uid = _firebaseService.currentUser?.uid;
                            if (uid == null) return;
                            
                            try {
                              if (isBookmarked) {
                                await _firebaseService.removeBookmark(uid, resource.id);
                              } else {
                                await _firebaseService.bookmarkResource(uid, resource.id);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        );
                      }
                    ),
                    const SizedBox(width: 12),
                    _iconAction(Icons.share_outlined, Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sharing functionality coming soon')),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 20),
                // Dynamic Comments Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                    StreamBuilder<List<CommentModel>>(
                      stream: _firebaseService.getComments(resource.id),
                      builder: (context, snap) {
                        final count = snap.data?.length ?? 0;
                        return Text('$count comment${count == 1 ? '' : 's'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Comments List
                StreamBuilder<List<CommentModel>>(
                  stream: _firebaseService.getComments(resource.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allComments = snapshot.data ?? [];
                    if (allComments.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'Be the first to comment!', 
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
                          ),
                        ),
                      );
                    }

                    // Build the tree (root level)
                    final rootComments = allComments.where((c) => c.parentId == null).toList();
                    rootComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    return Column(
                      children: rootComments.map((root) => _buildCommentTree(root, allComments)).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Add Comment Input
                if (_replyToCommentId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.reply, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Replying to ${_replyToUserName ?? "User"}',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _replyToCommentId = null;
                              _replyToUserName = null;
                            });
                          },
                          child: Icon(Icons.cancel, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideX(begin: -0.1),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: _replyToCommentId != null ? 'Write a reply...' : 'Add a comment...',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSendingComment
                        ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.send_rounded),
                            onPressed: () async {
                              final text = _commentController.text.trim();
                              if (text.isEmpty) return;
                              final uid = _firebaseService.currentUser?.uid;
                              if (uid == null) return;

                              final scaffoldMsg = ScaffoldMessenger.of(context);

                              setState(() => _isSendingComment = true);
                              try {
                                await _firebaseService.addComment(
                                  resource.id, 
                                  text, 
                                  uid,
                                  parentId: _replyToCommentId,
                                );
                                _commentController.clear();
                                setState(() {
                                  _replyToCommentId = null;
                                  _replyToUserName = null;
                                });
                              } catch (e) {
                                scaffoldMsg.showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              } finally {
                                if (mounted) setState(() => _isSendingComment = false);
                              }
                            },
                          ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentTree(CommentModel parent, List<CommentModel> allComments, {int depth = 0}) {
    final children = allComments.where((c) => c.parentId == parent.id).toList();
    children.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dynamicCommentItem(parent, depth: depth),
        if (children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Column(
              children: children.map((child) => _buildCommentTree(child, allComments, depth: depth + 1)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _dynamicCommentItem(CommentModel comment, {int depth = 0}) {
    return FutureBuilder<UserModel?>(
      future: _firebaseService.getUserProfile(comment.userId),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'User';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
                          Row(
                            children: [
                              Text(
                                _getTimeAgo(comment.createdAt), 
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), 
                                  fontSize: 10
                                )
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _replyToCommentId = comment.id;
                                    _replyToUserName = name;
                                  });
                                  // Scroll to input if needed or just focus
                                },
                                child: Text('Reply', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.text, 
                        style: TextStyle(
                          fontSize: 13, 
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9)
                        )
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
            )
          ),
        ],
      ),
    );
  }

  Widget _voteButton({
    required IconData idleIcon,
    required IconData activeIcon,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: activeColor.withValues(alpha: 0.3)) : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : idleIcon, size: 18, color: isActive ? activeColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                count.toString(), 
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.bold, 
                  color: isActive ? activeColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                )
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _formatDownloads(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'notes': return Icons.description;
      case 'slides': return Icons.slideshow;
      case 'question': return Icons.help_outline;
      case 'book': return Icons.menu_book;
      default: return Icons.picture_as_pdf;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'notes': return Colors.blue;
      case 'slides': return Colors.orange;
      case 'question': return Colors.purple;
      case 'book': return Colors.teal;
      default: return Colors.blueGrey;
    }
  }
}
