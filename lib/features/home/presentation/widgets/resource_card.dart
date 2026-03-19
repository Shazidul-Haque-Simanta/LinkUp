import 'package:flutter/material.dart';
import 'package:project_v2/models/resource_model.dart';

class ResourceCard extends StatelessWidget {
  final String title;
  final String code;
  final String rating;
  final String downloads;
  final String initial;
  final VoidCallback onTap;
  final ResourceModel? resource;

  const ResourceCard({
    super.key,
    required this.title,
    required this.code,
    required this.rating,
    required this.downloads,
    required this.initial,
    required this.onTap,
    this.resource,
  });

  factory ResourceCard.fromModel({
    required ResourceModel resource,
    required VoidCallback onTap,
  }) {
    return ResourceCard(
      title: resource.title,
      code: resource.courseCode,
      rating: resource.rating.toStringAsFixed(1),
      downloads: _formatDownloads(resource.downloads),
      initial: resource.title.isNotEmpty ? resource.title[0].toUpperCase() : '?',
      onTap: onTap,
      resource: resource,
    );
  }

  static String _formatDownloads(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.light 
                  ? Colors.black.withValues(alpha: 0.04) 
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: resource != null 
                    ? _getTypeColor(resource!.type).withValues(alpha: 0.1) 
                    : Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                resource != null ? _getTypeIcon(resource!.type) : Icons.picture_as_pdf, 
                color: resource != null ? _getTypeColor(resource!.type) : Theme.of(context).colorScheme.primary, 
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                       Text(
                        code, 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), 
                          fontSize: 12, 
                          fontWeight: FontWeight.w500
                        )
                      ),
                      if (resource != null) ...[
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Theme.of(context).dividerColor)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTypeColor(resource!.type).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            resource!.type, 
                            style: TextStyle(color: _getTypeColor(resource!.type), fontSize: 10, fontWeight: FontWeight.bold)
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          resource!.subject, 
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), 
                            fontSize: 11
                          )
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      Text(
                        ' $rating', 
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        )
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.download_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      Text(
                        ' $downloads', 
                        style: TextStyle(
                          fontSize: 12, 
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: _getAvatarColor(initial),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String initial) {
    switch (initial.toUpperCase()) {
      case 'A': case 'B': case 'C': return Colors.blue[300]!;
      case 'D': case 'E': case 'F': return Colors.green[300]!;
      case 'G': case 'H': case 'I': return Colors.orange[300]!;
      case 'J': case 'K': case 'L': return Colors.purple[300]!;
      case 'M': case 'N': case 'O': return Colors.red[300]!;
      case 'P': case 'Q': case 'R': return Colors.teal[300]!;
      case 'S': case 'T': case 'U': return Colors.indigo[300]!;
      default: return Colors.blueGrey[300]!;
    }
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
