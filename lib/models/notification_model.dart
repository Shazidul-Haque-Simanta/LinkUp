class NotificationModel {
  final String id;
  final String type;
  final String message;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return NotificationModel(
      id: id,
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      read: map['read'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'message': message,
      'read': read,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
