import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class CommentModel {
  final String id;
  final String userId;
  final String postId;
  final String text;
  final DateTime createdAt;
  final String? replyToCommentId; // 답글인 경우 부모 댓글 ID
  
  CommentModel({
    required this.id,
    required this.userId,
    required this.postId,
    required this.text,
    required this.createdAt,
    this.replyToCommentId,
  });
  
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // createdAt 필드 처리
      DateTime createdDateTime;
      if (data['createdAt'] is Timestamp) {
        createdDateTime = (data['createdAt'] as Timestamp).toDate();
      } else {
        // createdAt이 null이거나 Timestamp가 아닌 경우 현재 시간 사용
        debugPrint('⚠️ createdAt이 유효하지 않음, 현재 시간 사용: ${data['createdAt']}');
        createdDateTime = DateTime.now();
      }
      
      return CommentModel(
        id: doc.id,
        userId: data['userId'] ?? '',
        postId: data['postId'] ?? '',
        text: data['text'] ?? '',
        createdAt: createdDateTime,
        replyToCommentId: data['replyToCommentId'],
      );
    } catch (e) {
      debugPrint('⚠️ CommentModel.fromFirestore 예외 발생: $e');
      // 예외 발생 시 기본값으로 객체 생성
      return CommentModel(
        id: doc.id,
        userId: '',
        postId: '',
        text: '오류: 댓글을 불러올 수 없습니다',
        createdAt: DateTime.now(),
      );
    }
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'postId': postId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'replyToCommentId': replyToCommentId,
    };
  }
}