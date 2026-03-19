class GroupModel {
  final String id;
  final String name;
  final String subject;
  final String createdBy;
  final Map<String, bool> members;

  GroupModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.createdBy,
    required this.members,
  });

  factory GroupModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      subject: map['subject'] ?? '',
      createdBy: map['createdBy'] ?? '',
      members: Map<String, bool>.from(map['members'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subject': subject,
      'createdBy': createdBy,
      'members': members,
    };
  }
}

class MessageModel {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory MessageModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return MessageModel(
      id: id,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
