import 'package:flutter/material.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  void _handleNotificationTap(NotificationModel notification) async {
    if (!notification.read) {
      final user = _firebaseService.currentUser;
      if (user != null) {
        try {
          await _firebaseService.markNotificationRead(user.uid, notification.id);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final user = _firebaseService.currentUser;

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
          'Notifications',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view notifications'))
          : StreamBuilder<List<NotificationModel>>(
              stream: _firebaseService.getUserNotifications(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final notifications = snapshot.data ?? [];
                // Sort to keep newest first
                notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        Text('No notifications yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return InkWell(
                      onTap: () => _handleNotificationTap(notif),
                      child: _notificationItem(notif),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _notificationItem(NotificationModel notification) {
    IconData icon;
    Color bgColor;
    Color iconColor;

    switch (notification.type) {
      case 'comment':
        icon = Icons.chat_bubble_outline;
        bgColor = Colors.blue.withValues(alpha: 0.1);
        iconColor = Colors.blue;
        break;
      case 'reply':
        icon = Icons.reply;
        bgColor = Colors.indigo.withValues(alpha: 0.1);
        iconColor = Colors.indigo;
        break;
      case 'vote':
        icon = Icons.star_outline;
        bgColor = Colors.amber.withValues(alpha: 0.1);
        iconColor = Colors.amber;
        break;
      case 'follow':
        icon = Icons.person_add_outlined;
        bgColor = Colors.green.withValues(alpha: 0.1);
        iconColor = Colors.green;
        break;
      case 'upload':
        icon = Icons.cloud_upload_outlined;
        bgColor = Colors.deepPurple.withValues(alpha: 0.1);
        iconColor = Colors.deepPurple;
        break;
      default:
        icon = Icons.notifications_none;
        bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
        iconColor = Theme.of(context).colorScheme.primary;
    }

    return Container(
      color: notification.read ? Colors.transparent : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: !notification.read ? FontWeight.bold : FontWeight.normal,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimeAgo(notification.createdAt),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          if (!notification.read)
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
