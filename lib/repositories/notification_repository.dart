import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 컬렉션 참조 (테스트 시 쉽게 변경 가능)
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _notificationsCollection => _firestore.collection('notifications');
  
  // 사용자 FCM 토큰 저장
  Future<void> saveUserFCMToken(String userId, String token) async {
    try {
      // 먼저 현재 토큰 목록 확인
      final userDoc = await _usersCollection.doc(userId).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        
        if (userData != null && userData['fcmTokens'] != null) {
          // 이미 같은 토큰이 있는지 확인
          final tokens = List<String>.from(userData['fcmTokens']);
          if (tokens.contains(token)) {
            debugPrint('FCM 토큰이 이미 존재함: $token');
            return;
          }
        }
        
        // 기존 토큰 목록에 추가
        await _usersCollection.doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM 토큰 저장 성공: $userId');
      } else {
        // 사용자 문서가 없는 경우 생성
        await _usersCollection.doc(userId).set({
          'fcmTokens': [token],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('새 사용자 문서 생성 및 FCM 토큰 저장 성공');
      }
    } catch (e) {
      debugPrint('FCM 토큰 저장 실패: $e');
      // 예외를 다시 던져서 호출자가 처리할 수 있게 함
      rethrow;
    }
  }
  
  // 사용자 FCM 토큰 삭제 (로그아웃 또는 특정 기기 해제 시)
  Future<void> deleteUserFCMToken(String userId, {String? specificToken}) async {
    try {
      if (specificToken != null) {
        // 특정 토큰만 삭제
        await _usersCollection.doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([specificToken]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('특정 FCM 토큰 삭제 성공: $specificToken');
      } else {
        // 모든 토큰 삭제 (배열을 빈 배열로 설정)
        await _usersCollection.doc(userId).update({
          'fcmTokens': [],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('모든 FCM 토큰 삭제 성공: $userId');
      }
    } catch (e) {
      debugPrint('FCM 토큰 삭제 실패: $e');
      rethrow;
    }
  }
  
  // 새 알림 저장
  Future<void> saveNotification(NotificationModel notification) async {
    try {
      await _notificationsCollection.doc(notification.id).set(
        notification.toFirestore()
      );
      debugPrint('알림 저장 성공: ${notification.id}');
    } catch (e) {
      debugPrint('알림 저장 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 알림 목록 가져오기 (읽음 여부 관계없이 모든 알림)
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    try {
      return _notificationsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50) // 최신 50개만 가져오기
          .snapshots()
          .map((snapshot) {
            debugPrint('알림 목록 조회: ${snapshot.docs.length}개');
            return snapshot.docs
                .map((doc) => NotificationModel.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      debugPrint('알림 목록 조회 실패: $e');
      return Stream.value([]); // 오류 발생 시 빈 목록 반환
    }
  }
  
  // 안 읽은 알림 개수 가져오기
  Stream<int> getUnreadNotificationsCount(String userId) {
    try {
      return _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      debugPrint('안 읽은 알림 개수 조회 실패: $e');
      return Stream.value(0); // 오류 발생 시 0 반환
    }
  }
  
  // 안 읽은 알림이 있는지 여부 확인
  Future<bool> hasUnreadNotifications(String userId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .limit(1) // 하나만 있어도 충분
          .get();
          
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('안 읽은 알림 확인 실패: $e');
      return false; // 오류 발생 시 false 반환
    }
  }
  
  // 단일 알림 읽음 표시
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      debugPrint('알림 읽음 표시 성공: $notificationId');
    } catch (e) {
      debugPrint('알림 읽음 표시 실패: $e');
      rethrow;
    }
  }
  
  // 모든 알림 읽음 표시 - WriteBatch 사용
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      // 읽지 않은 알림만 조회
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('읽지 않은 알림이 없습니다');
        return;
      }
      
      debugPrint('읽지 않은 알림 ${snapshot.docs.length}개 발견');
      
      // WriteBatch를 사용하여 일괄 업데이트
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      // 배치 실행
      await batch.commit();
      debugPrint('모든 알림 읽음 표시 성공: ${snapshot.docs.length}개 업데이트됨');
    } catch (e) {
      debugPrint('모든 알림 읽음 표시 실패: $e');
      rethrow;
    }
  }
  
  // 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
      debugPrint('알림 삭제 성공: $notificationId');
    } catch (e) {
      debugPrint('알림 삭제 실패: $e');
      rethrow;
    }
  }
  
  // 오래된 알림 정리 (30일 이상)
  Future<int> cleanupOldNotifications(String userId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('삭제할 오래된 알림 없음');
        return 0;
      }
      
      // 배치 작업으로 일괄 삭제
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      final deletedCount = snapshot.docs.length;
      debugPrint('오래된 알림 $deletedCount개 정리 완료');
      return deletedCount;
    } catch (e) {
      debugPrint('오래된 알림 정리 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 모든 알림 삭제 (계정 삭제 시)
  Future<void> deleteAllUserNotifications(String userId) async {
    try {
      const maxBatchSize = 500; // Firestore 배치 최대 크기
      
      var notificationsToDelete = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .get();
          
      while (notificationsToDelete.docs.isNotEmpty) {
        // 배치 크기 제한 내에서 삭제
        final currentBatch = notificationsToDelete.docs.take(maxBatchSize);
        final batch = _firestore.batch();
        
        for (final doc in currentBatch) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        debugPrint('알림 배치 삭제 완료: ${currentBatch.length}개');
        
        // 남은 알림이 있는지 확인
        if (notificationsToDelete.docs.length <= maxBatchSize) {
          break;
        }
        
        // 다음 배치 가져오기
        notificationsToDelete = await _notificationsCollection
            .where('userId', isEqualTo: userId)
            .get();
      }
      
      debugPrint('사용자 모든 알림 삭제 완료: $userId');
    } catch (e) {
      debugPrint('사용자 모든 알림 삭제 실패: $e');
      rethrow;
    }
  }
}