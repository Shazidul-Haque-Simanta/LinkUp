class ForumPostModel {
  final String id;
  final String title;
  final String description;
  final String userId;
  final String? imageUrl;
  final int upvotes;
  final DateTime createdAt;

  ForumPostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    this.imageUrl,
    this.upvotes = 0,
    required this.createdAt,
  });

  factory ForumPostModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ForumPostModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      userId: map['userId'] ?? '',
      imageUrl: map['imageUrl']?.toString(),
      upvotes: map['upvotes'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'userId': userId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'upvotes': upvotes,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

class ForumReplyModel {
  final String id;
  final String userId;
  final String text;
  final String? imageUrl;
  final String? parentId;
  final DateTime createdAt;

  ForumReplyModel({
    required this.id,
    required this.userId,
    required this.text,
    this.imageUrl,
    this.parentId,
    required this.createdAt,
  });

  factory ForumReplyModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ForumReplyModel(
      id: id,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl']?.toString(),
      parentId: map['parentId']?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (parentId != null) 'parentId': parentId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
