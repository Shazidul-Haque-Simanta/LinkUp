import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initial;
  final double radius;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.initial,
    this.radius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: radius * 2,
      width: radius * 2,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        image: (imageUrl != null && imageUrl!.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: radius,
                ),
              ),
            )
          : null,
    );
  }
}
