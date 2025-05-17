import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class PostModel {
  final String id;
  final String userId;
  final String? caption;
  final List<String>? imageUrls;
  final String? location;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final List<String>? hashtags;
  
  PostModel({
    required this.id,
    required this.userId,
    this.caption,
    this.imageUrls,
    this.location,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.hashtags,
  });
  
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      // 디버깅을 위해 데이터 출력
      debugPrint('PostModel 생성 시도: 문서 ID ${doc.id}, 데이터: $data');
      
      // createdAt 필드 처리 - Timestamp가 null일 수 있음
      DateTime createdDateTime;
      if (data['createdAt'] is Timestamp) {
        createdDateTime = (data['createdAt'] as Timestamp).toDate();
      } else {
        // createdAt이 null이거나 Timestamp가 아닌 경우 현재 시간 사용
        debugPrint('⚠️ createdAt이 유효하지 않음, 현재 시간 사용: ${data['createdAt']}');
        createdDateTime = DateTime.now();
      }
      
      // imageUrls 필드 처리
      List<String>? imageUrlsList;
      if (data['imageUrls'] != null) {
        try {
          imageUrlsList = List<String>.from(data['imageUrls']);
        } catch (e) {
          debugPrint('⚠️ imageUrls 변환 오류: $e');
          imageUrlsList = null;
        }
      }
      
      // hashtags 필드 처리
      List<String>? hashtagsList;
      if (data['hashtags'] != null) {
        try {
          hashtagsList = List<String>.from(data['hashtags']);
        } catch (e) {
          debugPrint('⚠️ hashtags 변환 오류: $e');
          hashtagsList = null;
        }
      }
      
      return PostModel(
        id: doc.id,
        userId: data['userId'] ?? '',
        caption: data['caption'],
        imageUrls: imageUrlsList,
        location: data['location'],
        createdAt: createdDateTime,
        likesCount: data['likesCount'] ?? 0,
        commentsCount: data['commentsCount'] ?? 0,
        hashtags: hashtagsList,
      );
    } catch (e) {
      debugPrint('⚠️ PostModel.fromFirestore 예외 발생: $e');
      // 예외가 발생하더라도 기본값으로 객체 생성
      return PostModel(
        id: doc.id,
        userId: '',
        createdAt: DateTime.now(),
      );
    }
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'caption': caption,
      'imageUrls': imageUrls,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'hashtags': hashtags,
    };
  }
}