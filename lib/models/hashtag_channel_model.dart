import 'package:cloud_firestore/cloud_firestore.dart';

class HashtagChannelModel {
  final String id;
  final String name; // 해시태그 이름 (# 제외)
  final String? description;
  final int followersCount;
  final int postsCount;
  final DateTime createdAt;
  final String? coverImageUrl;
  
  HashtagChannelModel({
    required this.id,
    required this.name,
    this.description,
    this.followersCount = 0,
    this.postsCount = 0,
    required this.createdAt,
    this.coverImageUrl,
  });
  
  factory HashtagChannelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HashtagChannelModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      followersCount: data['followersCount'] ?? 0,
      postsCount: data['postsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      coverImageUrl: data['coverImageUrl'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'followersCount': followersCount,
      'postsCount': postsCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'coverImageUrl': coverImageUrl,
    };
  }
}