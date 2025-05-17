import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? username;
  final String? profileImageUrl;
  final DateTime createdAt;
  
  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.profileImageUrl,
    required this.createdAt,
  });
  
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'],
      username: data['username'],
      profileImageUrl: data['profileImageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
  
  UserModel copyWith({
    String? name,
    String? username,
    String? profileImageUrl,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt,
    );
  }
}