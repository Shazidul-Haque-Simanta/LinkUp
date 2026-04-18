import 'package:flutter/material.dart';
import 'package:project_v2/features/home/presentation/pages/home_screen.dart';
import 'package:project_v2/features/search/presentation/pages/search_screen.dart';
import 'package:project_v2/features/upload/presentation/pages/upload_screen.dart';
import 'package:project_v2/features/profile/presentation/pages/profile_screen.dart';
import 'package:project_v2/features/ai_tutor/presentation/pages/ai_tutor_screen.dart';
import 'package:project_v2/services/firebase_service.dart';

class MainNavigationBar extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigationBar({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationBar> createState() => _MainNavigationBarState();
}

class _MainNavigationBarState extends State<MainNavigationBar> {
  late int _selectedIndex;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _pages = [
    const HomeScreen(),
    const SearchScreen(),
    const UploadScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) => const ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                child: AiTutorScreen(),
              ),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.light ? 0.05 : 0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.file_upload_outlined), activeIcon: Icon(Icons.file_upload), label: 'Upload'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
