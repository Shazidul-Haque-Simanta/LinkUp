class ResourceModel {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String courseCode;
  final String type; // e.g. Notes, Slides, Question, Resource
  final List<String> tags;
  final String fileurls;
  final String uploaderId;
  final int downloads;
  final double rating;
  final Map<String, bool> upvotes;
  final Map<String, bool> downvotes;
  final DateTime createdAt;

  ResourceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.courseCode,
    this.type = 'Resource',
    required this.tags,
    required this.fileurls,
    required this.uploaderId,
    this.downloads = 0,
    this.rating = 0.0,
    this.upvotes = const {},
    this.downvotes = const {},
    required this.createdAt,
  });

  factory ResourceModel.fromMap(String id, Map<dynamic, dynamic> map) {
    // Safely handle tags which might be a List, a single String, or null/empty
    List<String> parsedTags = [];
    if (map['tags'] != null) {
      if (map['tags'] is List) {
        parsedTags = List<String>.from(map['tags']);
      } else if (map['tags'] is String && (map['tags'] as String).isNotEmpty) {
        parsedTags = [(map['tags'] as String)];
      }
    }

    return ResourceModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subject: map['subject'] ?? '',
      courseCode: map['courseCode'] ?? '',
      type: map['type'] ?? 'Resource',
      tags: parsedTags,
      fileurls: map['fileurls'] ?? '',
      uploaderId: map['uploaderId'] ?? '',
      downloads: map['downloads'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      upvotes: Map<String, bool>.from(map['upvotes'] ?? {}),
      downvotes: Map<String, bool>.from(map['downvotes'] ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'subject': subject,
      'courseCode': courseCode,
      'type': type,
      'tags': tags,
      'fileurls': fileurls,
      'uploaderId': uploaderId,
      'downloads': downloads,
      'rating': rating,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
