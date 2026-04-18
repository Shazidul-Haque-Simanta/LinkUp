import 'package:flutter/material.dart';
import 'package:project_v2/features/home/presentation/widgets/resource_card.dart';
import 'package:project_v2/features/resource/presentation/pages/resource_detail_screen.dart';
import 'package:project_v2/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:project_v2/features/study_groups/presentation/pages/study_groups_screen.dart';
import 'package:project_v2/features/forum/presentation/pages/discussion_forum_screen.dart';
import 'package:project_v2/features/saved/presentation/pages/saved_resources_screen.dart';
import 'package:project_v2/features/settings/presentation/pages/settings_screen.dart';
import 'package:project_v2/features/search/presentation/pages/search_screen.dart';
import 'package:project_v2/features/contributors/presentation/pages/top_contributors_screen.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/resource_model.dart';
import 'package:project_v2/models/user_model.dart';
import 'package:project_v2/models/notification_model.dart';
import 'package:project_v2/shared/widgets/user_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(context).animate().fade(duration: 500.ms).slideY(begin: -0.2, curve: Curves.easeOutQuad),
              const SizedBox(height: 24),
              // Search Bar Placeholder (Navigates to SearchScreen)
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 12),
                      Text('Search resources, subjects...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ).animate(delay: 100.ms).fade(duration: 500.ms).slideX(begin: -0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All'].map((cat) {
                    bool isSelected = cat == _selectedCategory;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat == 'Computer Science' ? 'CS' : cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                          } else {
                            setState(() => _selectedCategory = 'All');
                          }
                        },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected 
                            ? Theme.of(context).colorScheme.onPrimary 
                            : Theme.of(context).colorScheme.onSurface, 
                          fontSize: 13
                        ),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ).animate().fade(duration: 300.ms).slideX(begin: 0.1);
                  }).toList(),
                ),
              ).animate(delay: 200.ms).fade(duration: 500.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 24),
              // Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  QuickAction3DButton(
                    icon: Icons.groups,
                    label: 'Study Groups',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupsScreen()));
                    },
                  ),
                  QuickAction3DButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'Forum',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscussionForumScreen()));
                    },
                  ),
                  QuickAction3DButton(
                    icon: Icons.bookmark_border,
                    label: 'Saved',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedResourcesScreen()));
                    },
                  ),
                  QuickAction3DButton(
                    icon: Icons.emoji_events_outlined,
                    label: 'Leaders',
                    color: const Color(0xFFFFD700),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TopContributorsScreen()));
                    },
                  ),
                  QuickAction3DButton(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    color: Colors.blueGrey,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                ],
              ).animate(delay: 300.ms).fade(duration: 500.ms).scaleXY(begin: 0.9, curve: Curves.easeOutQuad),
              const SizedBox(height: 32),
              // Trending Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _sectionHeader('Trending'),
                   const SizedBox(height: 16),
                   _buildTrendingList(),
                ],
              ).animate(delay: 400.ms).fade(duration: 500.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
              const SizedBox(height: 32),
              // Latest Uploads
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _sectionHeader('Latest Uploads'),
                   const SizedBox(height: 16),
                   _buildLatestList(),
                ],
              ).animate(delay: 500.ms).fade(duration: 500.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Widget _buildHeader(BuildContext context) {
    final user = _firebaseService.currentUser;
    if (user == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Welcome!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          )),
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            child: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface)
          ),
        ],
      );
    }

    return FutureBuilder<UserModel?>(
      future: _firebaseService.getUserProfile(user.uid),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'Loading...';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getGreeting(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                Row(
                  children: [
                    Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    )),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                StreamBuilder<List<NotificationModel>>(
                  stream: _firebaseService.getUserNotifications(user.uid),
                  builder: (context, snapshot) {
                    final notifications = snapshot.data ?? [];
                    final hasUnread = notifications.any((n) => !n.read);

                    return Stack(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                          },
                          icon: Icon(
                            hasUnread ? Icons.notifications : Icons.notifications_none,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 10,
                                minHeight: 10,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                     // Optionally navigate to Profile
                  },
                  child: UserAvatar(
                    imageUrl: snapshot.data?.profileImage,
                    initial: initial,
                    radius: 20, // 40 diameter => 20 radius
                  ),
                ),
              ],
            ),
          ],
        );
      }
    );
  }

  Widget _buildTrendingList() {
    return StreamBuilder<List<ResourceModel>>(
      stream: _firebaseService.streamTrendingResources(limit: 2, subject: _selectedCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final filtered = snapshot.data ?? [];

        if (filtered.isEmpty) return _buildEmptyState('No trending resources in this category');

        return Column(
          children: filtered.map((res) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ResourceCard.fromModel(
              resource: res,
              onTap: () => _navigateToDetail(context, res.id),
              backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.orange.shade50 : Colors.orange.withOpacity(0.05),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildLatestList() {
    return StreamBuilder<List<ResourceModel>>(
      stream: _firebaseService.streamLatestResources(limit: 2, subject: _selectedCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final filtered = snapshot.data ?? [];

        if (filtered.isEmpty) return _buildEmptyState('No recent uploads in this category');

        return Column(
          children: filtered.map((res) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ResourceCard.fromModel(
              resource: res,
              onTap: () => _navigateToDetail(context, res.id),
              backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.teal.shade50 : Colors.teal.withOpacity(0.05),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          message, 
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), 
            fontSize: 13
          )
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final bool isTrending = title == 'Trending';
    final Color iconColor = isTrending ? Colors.deepOrange : Colors.teal;
    final Color bgColor = isTrending ? Colors.orange.withOpacity(0.15) : Colors.teal.withOpacity(0.15);
    final IconData iconData = isTrending ? Icons.local_fire_department_rounded : Icons.fiber_new_rounded;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title, 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              )
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (_) => SearchScreen(
                  initialSubject: _selectedCategory == 'All' ? null : _selectedCategory,
                  initialSortByLatest: title == 'Latest Uploads',
                  initialSortByTopRated: title == 'Trending',
                  enforceStrictTrending: title == 'Trending',
                  enforceStrictLatestHours: title == 'Latest Uploads' ? 4 : null,
                )
              )
            );
          }, 
          child: Text(
            'See all', 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))
          )
        ),
      ],
    );
  }

  void _navigateToDetail(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResourceDetailScreen(resourceId: id)),
    );
  }
}

class QuickAction3DButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const QuickAction3DButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  State<QuickAction3DButton> createState() => _QuickAction3DButtonState();
}

class _QuickAction3DButtonState extends State<QuickAction3DButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 150)
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)
    );
    // Slight 3D rotation effect 
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Transform(
            alignment: FractionalOffset.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateX(_rotateAnimation.value)
              ..rotateZ(_rotateAnimation.value * 0.5)
              ..scale(_scaleAnimation.value),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light 
                        ? widget.color.withOpacity(0.1)
                        : widget.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.light 
                            ? widget.color.withOpacity(0.05 + (_controller.value * 0.05)) 
                            : Colors.black.withOpacity(0.2 + (_controller.value * 0.1)),
                        blurRadius: 10 - (_controller.value * 5),
                        offset: Offset(0, 4 - (_controller.value * 2)),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: widget.color),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label, 
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                  )
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
