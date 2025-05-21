import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;          // 보고서 ID
  final String userId;      // 신고한 사용자 ID
  final String postId;      // 신고된 게시물 ID
  final String reason;      // 신고 사유
  final DateTime createdAt; // 신고 날짜
  
  ReportModel({
    required this.id,
    required this.userId,
    required this.postId,
    required this.reason,
    required this.createdAt,
  });
  
  // Firestore 변환 메서드 추가
  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      postId: data['postId'] ?? '',
      reason: data['reason'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'postId': postId,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}