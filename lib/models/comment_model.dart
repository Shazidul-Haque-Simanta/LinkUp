class CommentModel {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String? parentId;

  CommentModel({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.parentId,
  });

  factory CommentModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return CommentModel(
      id: id,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      parentId: map['parentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (parentId != null) 'parentId': parentId,
    };
  }
}
