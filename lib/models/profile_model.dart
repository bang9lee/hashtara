import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileModel {
  final String userId;
  final String? bio;
  final List<String>? interests;
  final String? location;
  final Map<String, dynamic>? socialLinks;
  final int postCount;
  final int followersCount;
  final int followingCount;
  
  ProfileModel({
    required this.userId,
    this.bio,
    this.interests,
    this.location,
    this.socialLinks,
    this.postCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });
  
  factory ProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProfileModel(
      userId: doc.id,
      bio: data['bio'],
      interests: data['interests'] != null 
          ? List<String>.from(data['interests']) 
          : null,
      location: data['location'],
      socialLinks: data['socialLinks'],
      postCount: data['postCount'] ?? 0,
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'bio': bio,
      'interests': interests,
      'location': location,
      'socialLinks': socialLinks,
      'postCount': postCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }
  
  ProfileModel copyWith({
    String? bio,
    List<String>? interests,
    String? location,
    Map<String, dynamic>? socialLinks,
    int? postCount,
    int? followersCount,
    int? followingCount,
  }) {
    return ProfileModel(
      userId: userId,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      location: location ?? this.location,
      socialLinks: socialLinks ?? this.socialLinks,
      postCount: postCount ?? this.postCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}