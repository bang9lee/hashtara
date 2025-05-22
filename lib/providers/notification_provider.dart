import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

// 알림 저장소 프로바이더
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// 사용자 알림 목록 프로바이더
final userNotificationsProvider = StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUserNotifications(userId);
});

// 읽지 않은 알림 개수 프로바이더
final unreadNotificationsCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadNotificationsCount(userId);
});

// 읽지 않은 알림 존재 여부 프로바이더
final hasUnreadNotificationsProvider = FutureProvider.family<bool, String>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.hasUnreadNotifications(userId);
});

// 알림 컨트롤러 프로바이더
final notificationControllerProvider = StateNotifierProvider<NotificationController, AsyncValue<void>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationController(repository);
});

// 알림 컨트롤러
class NotificationController extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repository;
  
  NotificationController(this._repository) : super(const AsyncValue.data(null));
  
  // 단일 알림을 읽음 표시
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      state = const AsyncValue.loading();
      await _repository.markNotificationAsRead(notificationId);
      state = const AsyncValue.data(null);
      debugPrint('알림 읽음 표시 성공: $notificationId');
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      debugPrint('알림 읽음 표시 실패: $e');
    }
  }
  
  // 모든 알림을 읽음 표시
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      state = const AsyncValue.loading();
      await _repository.markAllNotificationsAsRead(userId);
      state = const AsyncValue.data(null);
      debugPrint('모든 알림 읽음 표시 성공');
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      debugPrint('모든 알림 읽음 표시 실패: $e');
    }
  }
  
  // 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    try {
      state = const AsyncValue.loading();
      await _repository.deleteNotification(notificationId);
      state = const AsyncValue.data(null);
      debugPrint('알림 삭제 성공: $notificationId');
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      debugPrint('알림 삭제 실패: $e');
    }
  }
  
  // 오래된 알림 정리
  Future<int> cleanupOldNotifications(String userId) async {
    try {
      state = const AsyncValue.loading();
      final deletedCount = await _repository.cleanupOldNotifications(userId);
      state = const AsyncValue.data(null);
      debugPrint('오래된 알림 정리 완료: $deletedCount개');
      return deletedCount;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      debugPrint('오래된 알림 정리 실패: $e');
      return 0;
    }
  }
}