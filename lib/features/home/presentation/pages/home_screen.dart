import 'package:flutter/material.dart';
import 'package:project_v2/features/home/presentation/widgets/resource_card.dart';
import 'package:project_v2/features/resource/presentation/pages/resource_detail_screen.dart';
import 'package:project_v2/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:project_v2/features/study_groups/presentation/pages/study_groups_screen.dart';
import 'package:project_v2/features/forum/presentation/pages/discussion_forum_screen.dart';
import 'package:project_v2/features/saved/presentation/pages/saved_resources_screen.dart';
import 'package:project_v2/features/settings/presentation/pages/settings_screen.dart';
import 'package:project_v2/features/search/presentation/pages/search_screen.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/resource_model.dart';
import 'package:project_v2/models/user_model.dart';
import 'package:project_v2/models/notification_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Computer Science', 'Mathematics', 'Physics', 'Business', 'Other'];

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
              // Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
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
                             // If unselecting, go to all
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
                    );
                  }).toList(),
                ),
              ).animate(delay: 200.ms).fade(duration: 500.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 24),
              // Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _quickAction(Icons.groups, 'Study Groups', context, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupsScreen()));
                   }),
                   _quickAction(Icons.chat_bubble_outline, 'Forum', context, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscussionForumScreen()));
                   }),
                   _quickAction(Icons.bookmark_border, 'Saved', context, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedResourcesScreen()));
                   }),
                   _quickAction(Icons.settings_outlined, 'Settings', context, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                   }),
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
                Text(_getGreeting(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
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
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initial, 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary, 
                          fontWeight: FontWeight.bold
                        )
                      )
                    ),
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
      stream: _firebaseService.streamTrendingResources(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final resources = snapshot.data ?? [];
        final filtered = _selectedCategory == 'All' 
            ? resources 
            : resources.where((r) => r.subject == _selectedCategory).toList();

        if (filtered.isEmpty) return _buildEmptyState('No trending resources in this category');

        return Column(
          children: filtered.map((res) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ResourceCard.fromModel(
              resource: res,
              onTap: () => _navigateToDetail(context, res.id),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildLatestList() {
    return StreamBuilder<List<ResourceModel>>(
      stream: _firebaseService.streamLatestResources(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final resources = snapshot.data ?? [];
        final filtered = _selectedCategory == 'All' 
            ? resources 
            : resources.where((r) => r.subject == _selectedCategory).toList();

        if (filtered.isEmpty) return _buildEmptyState('No recent uploads in this category');

        return Column(
          children: filtered.map((res) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ResourceCard.fromModel(
              resource: res,
              onTap: () => _navigateToDetail(context, res.id),
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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), 
            fontSize: 13
          )
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, BuildContext context, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.light 
                      ? Colors.black.withValues(alpha: 0.05) 
                      : Colors.white.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
            )
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(title == 'Trending' ? '🔥' : '📂', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
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
                )
              )
            );
          }, 
          child: Text(
            'See all', 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
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
