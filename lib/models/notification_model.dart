class NotificationModel {
  final String id;
  final String type;
  final String message;
  final String? targetId;
  final String? senderId;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    this.targetId,
    this.senderId,
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return NotificationModel(
      id: id,
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      targetId: map['targetId']?.toString(),
      senderId: map['senderId']?.toString(),
      read: map['read'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'message': message,
      if (targetId != null) 'targetId': targetId,
      if (senderId != null) 'senderId': senderId,
      'read': read,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
