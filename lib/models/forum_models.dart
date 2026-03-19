class ForumPostModel {
  final String id;
  final String title;
  final String description;
  final String userId;
  final int upvotes;
  final DateTime createdAt;

  ForumPostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    this.upvotes = 0,
    required this.createdAt,
  });

  factory ForumPostModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ForumPostModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      userId: map['userId'] ?? '',
      upvotes: map['upvotes'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'userId': userId,
      'upvotes': upvotes,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

class ForumReplyModel {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;

  ForumReplyModel({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory ForumReplyModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ForumReplyModel(
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
