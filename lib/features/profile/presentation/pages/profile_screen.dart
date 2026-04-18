import 'package:flutter/material.dart';
import 'package:project_v2/features/home/presentation/widgets/resource_card.dart';
import 'package:project_v2/features/resource/presentation/pages/resource_detail_screen.dart';
import 'package:project_v2/features/settings/presentation/pages/settings_screen.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/user_model.dart';
import 'package:project_v2/models/resource_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isUploading = false;

  Future<void> _pickAndUploadImage(String uid) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await _firebaseService.updateProfilePictureWeb(uid, bytes);
      } else {
        final File file = File(image.path);
        await _firebaseService.updateProfilePicture(uid, file);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
        setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  void _showEditProfileDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final uniController = TextEditingController(text: user.university);
    final deptController = TextEditingController(text: user.department);
    final semController = TextEditingController(text: user.semester.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
              TextField(controller: uniController, decoration: const InputDecoration(labelText: 'University')),
              TextField(controller: deptController, decoration: const InputDecoration(labelText: 'Department')),
              TextField(
                controller: semController,
                decoration: const InputDecoration(labelText: 'Semester'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              
              final sem = int.tryParse(semController.text.trim()) ?? user.semester;

              final nav = Navigator.of(context);
              final scaffoldMsg = ScaffoldMessenger.of(context);

              try {
                await _firebaseService.updateUserProfile(user.uid, {
                  'name': newName,
                  'university': uniController.text.trim(),
                  'department': deptController.text.trim(),
                  'semester': sem,
                });
                nav.pop();
                if (mounted) {
                  setState(() {}); // Refresh to show new data in FutureBuilder
                }
              } catch (e) {
                scaffoldMsg.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _firebaseService.currentUser;
    final targetUserId = widget.userId ?? currentUser?.uid;
    final isOwner = currentUser != null && targetUserId == currentUser.uid;

    if (targetUserId == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Profile',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: Text('Please log in or register to view this profile.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isOwner ? 'My Profile' : 'User Profile',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
        ],
      ),
      body: FutureBuilder<UserModel?>(
        future: _firebaseService.getUserProfile(targetUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Error loading profile data'));
          }

          final userModel = snapshot.data!;
          final initial = userModel.name.isNotEmpty ? userModel.name[0].toUpperCase() : '?';

          return StreamBuilder<List<ResourceModel>>(
            stream: _firebaseService.streamUserResources(targetUserId, viewerUid: currentUser?.uid),
            builder: (context, uploadsSnapshot) {
              final uploads = uploadsSnapshot.data ?? [];
              final totalUploads = uploads.length;
              final totalDownloads = uploads.fold<int>(0, (sum, item) => sum + item.downloads);
              
              final totalUpvotes = uploads.fold<int>(0, (sum, item) => sum + item.upvotes.length);
              final totalDownvotes = uploads.fold<int>(0, (sum, item) => sum + item.downvotes.length);
              
              double contributionRating = 0.0;
              final totalVotes = totalUpvotes + totalDownvotes;
              if (totalUploads == 0) {
                contributionRating = 0.0;
              } else if (totalVotes == 0) {
                contributionRating = 3.0; // Baseline starting rate
              } else {
                const int baselineVotes = 5; 
                const double baselineRating = 3.0;
                double rawScore = (totalUpvotes / totalVotes) * 5.0;
                contributionRating = ((baselineVotes * baselineRating) + (totalVotes * rawScore)) / (baselineVotes + totalVotes);
                if (contributionRating < 1.0) contributionRating = 1.0;
                if (contributionRating > 5.0) contributionRating = 5.0;
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Profile Header
                    GestureDetector(
                      onTap: isOwner && !_isUploading ? () => _pickAndUploadImage(userModel.uid) : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 110,
                            width: 110,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  image: (userModel.profileImage != null && userModel.profileImage!.isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(userModel.profileImage!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: (userModel.profileImage == null || userModel.profileImage!.isEmpty)
                                    ? Center(
                                        child: Text(
                                          initial, 
                                          style: TextStyle(
                                            fontSize: 44, 
                                            color: Theme.of(context).colorScheme.primary, 
                                            fontWeight: FontWeight.bold
                                          )
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          if (_isUploading)
                            Container(
                              height: 110,
                              width: 110,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          if (isOwner && !_isUploading)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Icon(Icons.camera_alt_rounded, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                              ),
                            ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms).scaleXY(begin: 0.8, curve: Curves.easeOutBack),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Text(
                          userModel.name,
                          style: TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${userModel.university} · ${userModel.department}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
                        ),
                        Text(
                          'Semester ${userModel.semester}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
                        ),
                      ],
                    ).animate(delay: 100.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                    const SizedBox(height: 24),
                    // Stats Room
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statItem(totalUploads.toString(), 'Uploads'),
                          _statItem(userModel.followers.length.toString(), 'Followers'),
                          _statItem(totalUploads > 0 ? contributionRating.toStringAsFixed(1) : 'N/A', '★ Rating'),
                        ],
                      ),
                    ).animate(delay: 200.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                    const SizedBox(height: 32),
                    // Edit Profile / Follow Button
                    if (isOwner) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: OutlinedButton(
                          onPressed: () => _showEditProfileDialog(userModel),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(200, 48),
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Edit Profile', 
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)
                          ),
                        ).animate(delay: 300.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                      ),
                      const SizedBox(height: 24),
                    ] else if (currentUser != null) ...[
                      StreamBuilder<bool>(
                        stream: _firebaseService.checkIfFollowing(currentUser.uid, targetUserId),
                        builder: (context, snapshot) {
                          final isFollowing = snapshot.data ?? false;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isFollowing) {
                                  await _firebaseService.unfollowUser(currentUser.uid, targetUserId);
                                  setState(() {});
                                } else {
                                  await _firebaseService.followUser(currentUser.uid, targetUserId);
                                  setState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing 
                                    ? Theme.of(context).colorScheme.surfaceContainer 
                                    : Theme.of(context).colorScheme.primary,
                                foregroundColor: isFollowing 
                                    ? Theme.of(context).colorScheme.onSurface 
                                    : Theme.of(context).colorScheme.onPrimary,
                                minimumSize: const Size(200, 48),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(isFollowing ? 'Unfollow' : 'Follow', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ).animate(delay: 300.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Tabs
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: Theme.of(context).colorScheme.onSurface,
                            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            indicatorColor: Theme.of(context).colorScheme.primary,
                            indicatorWeight: 2,
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.file_upload_outlined, size: 18), SizedBox(width: 8), Text('Uploaded')])),
                              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bookmark_border, size: 18), SizedBox(width: 8), Text('Saved')])),
                            ],
                          ),
                          SizedBox(
                            height: 600, // Fixed height for tab bar view within scroll view
                            child: TabBarView(
                              children: [
                                _buildUploadsList(uploads),
                                _buildSavedList(targetUserId),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 400.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                  ],
                ),
              );
            }
          );
        },
      ),
    );
  }

  String _formatDownloads(int downloads) {
    if (downloads >= 1000) {
      return '${(downloads / 1000).toStringAsFixed(1)}k';
    }
    return downloads.toString();
  }

  void _showResourceOptions(ResourceModel resource) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(resource.isPrivate ? Icons.public : Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
            title: Text(resource.isPrivate ? 'Make Public' : 'Make Private'),
            onTap: () async {
              final scaffoldMsg = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await _firebaseService.toggleResourcePrivacy(resource.id, !resource.isPrivate);
                if (mounted) {
                  scaffoldMsg.showSnackBar(
                    SnackBar(content: Text(resource.isPrivate ? 'Resource is now public' : 'Resource is now private')),
                  );
                }
              } catch (e) {
                if (mounted) scaffoldMsg.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Delete Resource', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final scaffoldMsg = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Resource?'),
                  content: const Text('This will permanently remove the record and the physical file. This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await _firebaseService.deleteResource(resource.id);
                  if (mounted) {
                    scaffoldMsg.showSnackBar(
                      const SnackBar(content: Text('Resource deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) scaffoldMsg.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _buildUploadsList(List<ResourceModel> uploads) {
    if (uploads.isEmpty) {
      return Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text('No uploaded resources yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        ),
      );
    }
    return Container(
      color: Colors.transparent,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(), // Scroll managed by outer SingleChildScrollView
        itemCount: uploads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final resource = uploads[index];
          final isOwner = _firebaseService.currentUser?.uid == resource.uploaderId;
          return ResourceCard.fromModel(
            resource: resource,
            onTap: () => _navigateToDetail(context, resource.id),
            onMenuTap: isOwner ? () => _showResourceOptions(resource) : null,
          );
        },
      ),
    );
  }

  Widget _buildSavedList(String uid) {
    return StreamBuilder<List<String>>(
      stream: _firebaseService.streamUserBookmarkIds(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final bookmarkIds = snapshot.data ?? [];
        if (bookmarkIds.isEmpty) {
          return Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('No saved resources yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ),
          );
        }

        return StreamBuilder<List<ResourceModel>>(
          stream: _firebaseService.streamResources(), // Could optimize this to only fetch specific IDs, but this works for now
          builder: (context, resourcesSnapshot) {
            if (resourcesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allResources = resourcesSnapshot.data ?? [];
            final savedResources = allResources.where((r) => bookmarkIds.contains(r.id)).toList();

            if (savedResources.isEmpty) {
              return Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('Your saved resources are no longer available.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ),
              );
            }

            return Container(
              color: Colors.transparent,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: savedResources.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final resource = savedResources[index];
                  return ResourceCard.fromModel(
                    resource: resource,
                    onTap: () => _navigateToDetail(context, resource.id),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context, String resourceId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResourceDetailScreen(resourceId: resourceId)),
    );
  }
}
