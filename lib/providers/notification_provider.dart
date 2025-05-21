import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';

// 알림 저장소 프로바이더
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// 사용자 알림 스트림 프로바이더
final userNotificationsProvider = StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
  debugPrint('사용자 알림 스트림 시작: $userId');
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUserNotifications(userId);
});

// 안 읽은 알림 개수 스트림 프로바이더
final unreadNotificationsCountProvider = StreamProvider.family<int, String>((ref, userId) {
  debugPrint('안 읽은 알림 개수 스트림 시작: $userId');
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getUnreadNotificationsCount(userId);
});

// 새 알림 여부 상태 프로바이더 (전역 상태)
final hasUnreadNotificationsProvider = StateProvider<bool>((ref) => false);

// 현재 사용자의 안 읽은 알림 여부 자동 동기화 프로바이더
final autoSyncUnreadNotificationsProvider = Provider<void>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  
  currentUser.whenData((user) {
    if (user != null) {
      // 사용자가 로그인되어 있으면 안 읽은 알림 상태 자동 동기화
      ref.listen<AsyncValue<int>>(
        unreadNotificationsCountProvider(user.id),
        (_, next) {
          next.whenData((count) {
            ref.read(hasUnreadNotificationsProvider.notifier).state = count > 0;
          });
        },
      );
    } else {
      // 로그인 되지 않은 경우 알림 없음으로 설정
      ref.read(hasUnreadNotificationsProvider.notifier).state = false;
    }
  });
  
  return;
});

// 현재 사용자 알림 스트림 프로바이더 (조합형)
final currentUserNotificationsProvider = Provider<AsyncValue<List<NotificationModel>>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  
  return currentUser.when(
    data: (user) {
      if (user == null) {
        return const AsyncValue.data([]);
      }
      
      final notifications = ref.watch(userNotificationsProvider(user.id));
      return notifications;
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

// 알림 컨트롤러 프로바이더
final notificationControllerProvider = StateNotifierProvider<NotificationController, AsyncValue<void>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return NotificationController(repository, notificationService, ref);
});

// 알림 컨트롤러 클래스
class NotificationController extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repository;
  final NotificationService _service;
  final Ref _ref;
  
  NotificationController(this._repository, this._service, this._ref) : super(const AsyncValue.data(null));
  
  // 알림 읽음 표시
  Future<void> markNotificationAsRead(String notificationId) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.markNotificationAsRead(notificationId);
      
      // 안 읽은 알림이 남아있는지 확인
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        final hasUnread = await _repository.hasUnreadNotifications(user.id);
        _ref.read(hasUnreadNotificationsProvider.notifier).state = hasUnread;
        
        // 알림 목록 UI 갱신을 위해 userNotificationsProvider 다시 로드
        // unused_result 경고 수정
        final _ = _ref.refresh(userNotificationsProvider(user.id));
      }
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('알림 읽음 표시 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 모든 알림 읽음 표시
  Future<void> markAllNotificationsAsRead() async {
    state = const AsyncValue.loading();
    
    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        await _service.markNotificationsAsRead();
        
        // 알림 표시 상태 업데이트
        _ref.read(hasUnreadNotificationsProvider.notifier).state = false;
        
        // 알림 목록 UI 갱신을 위해 userNotificationsProvider 다시 로드
        // unused_result 경고 수정
        final _ = _ref.refresh(userNotificationsProvider(user.id));
        
        state = const AsyncValue.data(null);
      } else {
        state = const AsyncValue.error('로그인된 사용자가 없습니다', StackTrace.empty);
      }
    } catch (e, stack) {
      debugPrint('모든 알림 읽음 표시 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.deleteNotification(notificationId);
      
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        // 알림 목록 UI 갱신을 위해 userNotificationsProvider 다시 로드
        // unused_result 경고 수정
        final _ = _ref.refresh(userNotificationsProvider(user.id));
        
        // 안 읽은 알림 상태 갱신
        final hasUnread = await _repository.hasUnreadNotifications(user.id);
        _ref.read(hasUnreadNotificationsProvider.notifier).state = hasUnread;
      }
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('알림 삭제 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 오래된 알림 정리
  Future<int> cleanupOldNotifications() async {
    try {
      state = const AsyncValue.loading();
      
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        state = const AsyncValue.data(null);
        return 0;
      }
      
      final deletedCount = await _repository.cleanupOldNotifications(user.id);
      
      // 알림 목록 UI 갱신을 위해 userNotificationsProvider 다시 로드
      // unused_result 경고 수정
      final _ = _ref.refresh(userNotificationsProvider(user.id));
      
      state = const AsyncValue.data(null);
      return deletedCount;
    } catch (e, stack) {
      debugPrint('오래된 알림 정리 실패: $e');
      state = AsyncValue.error(e, stack);
      return 0;
    }
  }
}