import 'package:flutter/material.dart';
import 'package:project_v2/features/home/presentation/widgets/resource_card.dart';
import 'package:project_v2/features/resource/presentation/pages/resource_detail_screen.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/resource_model.dart';

class SavedResourcesScreen extends StatelessWidget {
  const SavedResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    final currentUser = firebaseService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Resources')),
        body: const Center(child: Text('Please log in to view saved resources')),
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
          'Saved Resources',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<String>>(
        stream: firebaseService.streamUserBookmarkIds(currentUser.uid),
        builder: (context, bookmarkSnapshot) {
          if (bookmarkSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final bookmarkIds = bookmarkSnapshot.data ?? [];
          if (bookmarkIds.isEmpty) {
            return _buildEmptyState(context);
          }

          return StreamBuilder<List<ResourceModel>>(
            stream: firebaseService.streamResources(),
            builder: (context, resourcesSnapshot) {
              if (resourcesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allResources = resourcesSnapshot.data ?? [];
              final savedResources = allResources.where((r) => bookmarkIds.contains(r.id)).toList();

              if (savedResources.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: savedResources.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final resource = savedResources[index];
                  return ResourceCard.fromModel(
                    resource: resource,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResourceDetailScreen(resourceId: resource.id),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border, 
            size: 64, 
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'No saved resources yet',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5), 
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Explore resources and tap the bookmark icon to save them.',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.4), 
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
