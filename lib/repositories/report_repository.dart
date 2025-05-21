import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 게시물 신고 저장
  Future<void> reportPost({
    required String userId,
    required String postId,
    required String reason,
  }) async {
    try {
      debugPrint('게시물 신고 저장 시도: $userId -> $postId (사유: $reason)');
      
      await _firestore.collection('reports').add({
        'userId': userId,
        'postId': postId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('게시물 신고 저장 성공');
    } catch (e) {
      debugPrint('게시물 신고 저장 실패: $e');
      throw Exception('게시물 신고 중 오류 발생: $e');
    }
  }
  
  // 사용자가 신고한 게시물 ID 목록 가져오기
  Future<List<String>> getUserReportedPostIds(String userId) async {
    try {
      debugPrint('사용자가 신고한 게시물 목록 조회: $userId');
      
      final snapshot = await _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .get();
      
      final reportedPostIds = snapshot.docs.map((doc) {
        final data = doc.data();
        return data['postId'] as String;
      }).toList();
      
      debugPrint('신고된 게시물 수: ${reportedPostIds.length}');
      return reportedPostIds;
    } catch (e) {
      debugPrint('신고된 게시물 목록 조회 실패: $e');
      return [];
    }
  }
  
  // 사용자가 특정 게시물을 신고했는지 확인
  Future<bool> hasUserReportedPost(String userId, String postId) async {
    try {
      debugPrint('사용자의 게시물 신고 여부 확인: $userId -> $postId');
      
      final snapshot = await _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .where('postId', isEqualTo: postId)
          .limit(1)
          .get();
      
      final hasReported = snapshot.docs.isNotEmpty;
      debugPrint('신고 여부: $hasReported');
      return hasReported;
    } catch (e) {
      debugPrint('신고 여부 확인 실패: $e');
      return false;
    }
  }
  
  // 실시간 신고 게시물 스트림 (사용자별)
  Stream<List<String>> getUserReportedPostIdsStream(String userId) {
    try {
      debugPrint('사용자 신고 게시물 스트림 시작: $userId');
      
      return _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
            final reportedPostIds = snapshot.docs.map((doc) {
              final data = doc.data();
              return data['postId'] as String;
            }).toList();
            
            debugPrint('실시간 신고된 게시물 수: ${reportedPostIds.length}');
            return reportedPostIds;
          });
    } catch (e) {
      debugPrint('신고 게시물 스트림 에러: $e');
      return Stream.value([]);
    }
  }
  
  // 신고 취소 (테스트용, 실제로는 구현하지 않을 수도 있음)
  Future<void> cancelReport({
    required String userId,
    required String postId,
  }) async {
    try {
      debugPrint('신고 취소 시도: $userId -> $postId');
      
      final snapshot = await _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .where('postId', isEqualTo: postId)
          .get();
      
      // 배치 처리로 한 번에 삭제
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('신고 취소 성공');
    } catch (e) {
      debugPrint('신고 취소 실패: $e');
      throw Exception('신고 취소 중 오류 발생: $e');
    }
  }
}