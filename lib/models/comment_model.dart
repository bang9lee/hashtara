import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final String? parentId; // 대댓글인 경우 부모 댓글 ID
  
  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.likesCount = 0,
    this.parentId,
  });
  
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 서버 타임스탬프 처리를 위한 로직 추가
    DateTime createdAtDate;
    try {
      if (data['createdAt'] is Timestamp) {
        createdAtDate = (data['createdAt'] as Timestamp).toDate();
      } else {
        // 타임스탬프가 없거나 다른 형식인 경우 현재 시간 사용
        createdAtDate = DateTime.now();
      }
    } catch (e) {
      debugPrint('날짜 변환 오류: $e, 문서 ID: ${doc.id}');
      createdAtDate = DateTime.now();
    }
    
    return CommentModel(
      id: data['id'] ?? doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      createdAt: createdAtDate,
      likesCount: data['likesCount'] ?? 0,
      parentId: data['parentId'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'parentId': parentId,
    };
  }
  
  // 디버깅을 위한 toString 오버라이드
  @override
  String toString() {
    return 'CommentModel(id: $id, postId: $postId, userId: $userId, text: $text, createdAt: $createdAt, likesCount: $likesCount, parentId: $parentId)';
  }
}