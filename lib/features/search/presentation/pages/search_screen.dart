import 'package:flutter/material.dart';
import 'package:project_v2/features/home/presentation/widgets/resource_card.dart';
import 'package:project_v2/features/resource/presentation/pages/resource_detail_screen.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/resource_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class SearchScreen extends StatefulWidget {
  final String? initialSubject;
  final bool initialSortByLatest;
  final bool initialSortByTopRated;
  final bool enforceStrictTrending;
  final int? enforceStrictLatestHours;

  const SearchScreen({
    super.key, 
    this.initialSubject, 
    this.initialSortByLatest = false, 
    this.initialSortByTopRated = false,
    this.enforceStrictTrending = false,
    this.enforceStrictLatestHours,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  
  String _searchQuery = '';
  String? _selectedSubject;
  String? _selectedCourseCode;
  bool _sortByLatest = false;
  bool _sortByTopRated = false;



  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.initialSubject;
    _sortByLatest = widget.initialSortByLatest;
    _sortByTopRated = widget.initialSortByTopRated;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  void _showCourseCodeDialog() {
    final TextEditingController dialogController = TextEditingController(text: _selectedCourseCode);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Course Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: dialogController,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g. CS301',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _selectedCourseCode = null);
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _selectedCourseCode = dialogController.text.trim().toUpperCase());
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(
                              icon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                              hintText: 'Search by title or tags...',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                              border: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.blue)),
                    ),
                ],
              ),
            ),

            StreamBuilder<List<String>>(
              stream: _firebaseService.streamSubjects(),
              builder: (context, snapshot) {
                final subjects = <String>['All', ...(snapshot.data?.cast<String>() ?? [])];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      _filterDropdown('Subject', subjects, _selectedSubject, (val) {
                        setState(() => _selectedSubject = val == 'All' ? null : val);
                      }),
                      _actionChip(
                        _selectedCourseCode ?? 'Course Code', 
                        isActive: _selectedCourseCode != null, 
                        onTap: _showCourseCodeDialog,
                        onClear: _selectedCourseCode != null ? () => setState(() => _selectedCourseCode = null) : null,
                      ),
                      _filterChip(
                        label: 'Latest', 
                        isActive: _sortByLatest, 
                        onSelected: (val) {
                          setState(() {
                            _sortByLatest = val;
                            if (_sortByLatest) _sortByTopRated = false;
                          });
                        }
                      ),
                      _filterChip(
                        label: 'Top Rated', 
                        isActive: _sortByTopRated, 
                        onSelected: (val) {
                          setState(() {
                            _sortByTopRated = val;
                            if (_sortByTopRated) _sortByLatest = false;
                          });
                        }
                      ),
                    ],
                  ),
                );
              }
            ).animate().fade(duration: 400.ms).slideX(begin: 0.1),

            const SizedBox(height: 10),

            // Results List
            Expanded(
              child: Container(
                width: double.infinity,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: StreamBuilder<List<ResourceModel>>(
                  stream: _firebaseService.streamResources(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    
                    final allResources = snapshot.data ?? [];
                    
                    // Client-side filtering
                    final filteredResources = allResources.where((res) {
                      final title = res.title.toLowerCase();
                      final description = res.description.toLowerCase();
                      final query = _searchQuery.toLowerCase();
                      
                      final matchesSearch = title.contains(query) ||
                                           description.contains(query) ||
                                           res.tags.any((t) => t.toLowerCase().contains(query));
                      
                      final matchesSubject = _selectedSubject == null || res.subject == _selectedSubject;
                      
                      final matchesCourse = _selectedCourseCode == null || 
                                           res.courseCode.toUpperCase().contains(_selectedCourseCode!.toUpperCase());
                      
                      if (!(matchesSearch && matchesSubject && matchesCourse)) return false;

                      // Strict Filters from home screen
                      if (widget.enforceStrictTrending) {
                         final int ageInMinutes = DateTime.now().difference(res.createdAt).inMinutes;
                         bool hasHighRating = res.rating >= 3.5;
                         bool hasFastDownloads = res.downloads > 20 && ageInMinutes <= 60;
                         if (!hasHighRating && !hasFastDownloads) return false;
                      }

                      if (widget.enforceStrictLatestHours != null) {
                         final int ageInHours = DateTime.now().difference(res.createdAt).inHours;
                         if (ageInHours > widget.enforceStrictLatestHours!) return false;
                         
                         // Consistency with FirebaseService streamLatestResources quality filter
                         final totalVotes = res.upvotes.length + res.downvotes.length;
                         if (totalVotes >= 3 && res.rating < 2.5) return false;
                      }
                      
                      return true;
                    }).toList();

                    // Sorting
                    if (_sortByLatest) {
                      filteredResources.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    } else if (_sortByTopRated) {
                      filteredResources.sort((a, b) => _firebaseService.calculateTrendingScore(b).compareTo(_firebaseService.calculateTrendingScore(a)));
                    }

                    if (filteredResources.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: filteredResources.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final resource = filteredResources[index];
                        return ResourceCard.fromModel(
                          resource: resource,
                          onTap: () => _navigateToDetail(context, resource),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown(String label, List<String> items, String? current, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: current != null 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: current != null 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) 
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        boxShadow: current != null ? [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ] : [],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current ?? items[0],
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: current != null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface),
          style: TextStyle(
            fontSize: 12, 
            color: current != null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface, 
            fontWeight: current != null ? FontWeight.bold : FontWeight.w500
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value == 'Computer Science' ? 'CS' : value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _filterChip({required String label, required bool isActive, required ValueChanged<bool> onSelected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: onSelected,
        labelStyle: TextStyle(
          fontSize: 12, 
          color: isActive ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        selectedColor: Theme.of(context).colorScheme.primary,
        checkmarkColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent),
      ),
    );
  }

  Widget _actionChip(String label, {required bool isActive, required VoidCallback onTap, VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.close, size: 14, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)),
            ],
          ],
        ),
        onPressed: onClear != null ? onClear : onTap,
        labelStyle: TextStyle(
          fontSize: 12, 
          color: isActive ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal
        ),
        backgroundColor: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent),
        elevation: isActive ? 4 : 0,
        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            'No resources found',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, ResourceModel resource) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResourceDetailScreen(resourceId: resource.id),
      ),
    );
  }
}
