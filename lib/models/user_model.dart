class UserModel {
  final String uid;
  final String name;
  final String email;
  final String university;
  final String department;
  final int semester;
  final String? profileImage;
  final Map<String, bool> followers;
  final Map<String, bool> following;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.university,
    required this.department,
    required this.semester,
    this.profileImage,
    this.followers = const {},
    this.following = const {},
    required this.createdAt,
  });

  factory UserModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      university: map['university'] ?? '',
      department: map['department'] ?? '',
      semester: map['semester'] is int ? map['semester'] : int.tryParse(map['semester'].toString()) ?? 0,
      profileImage: map['profileImage'],
      followers: Map<String, bool>.from(map['followers'] ?? {}),
      following: Map<String, bool>.from(map['following'] ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'university': university,
      'department': department,
      'semester': semester,
      'profileImage': profileImage,
      'followers': followers,
      'following': following,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
