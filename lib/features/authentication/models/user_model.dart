class UserModel {
  final String id;
  final String username;
  final String email;
  final String? profileImageUrl;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.profileImageUrl,
  });

  UserModel copyWith({
    String? username,
    String? email,
    String? profileImageUrl,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      profileImageUrl: map['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profileImageUrl': profileImageUrl,
    };
  }
}