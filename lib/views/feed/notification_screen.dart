import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import 'notification_helpers.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 알림 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllAsRead();
      
      // iOS 앱 배지 초기화
      ref.read(notificationServiceProvider).resetBadgeCount();
    });
  }
  
  // 모든 알림을 읽음 상태로 표시
  Future<void> _markAllAsRead() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser != null) {
      // NotificationController를 통해 모든 알림 읽음 처리
      await ref.read(notificationControllerProvider.notifier)
          .markAllNotificationsAsRead(currentUser.id);
      
      // iOS 앱 배지 초기화
      await ref.read(notificationServiceProvider).resetBadgeCount();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null) {
          return _buildLoginPrompt();
        }
        
        // 사용자가 로그인된 경우 알림 목록 불러오기
        final notifications = ref.watch(userNotificationsProvider(user.id));
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.cardBackground,
            border: const Border(
              bottom: BorderSide(color: AppColors.separator),
            ),
            middle: const Text(
              '알림',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                // 모든 알림 읽음 표시
                await ref.read(notificationControllerProvider.notifier)
                    .markAllNotificationsAsRead(user.id);
              },
              child: const Text(
                '모두 읽음',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          child: SafeArea(
            child: notifications.when(
              data: (notificationList) {
                if (notificationList.isEmpty) {
                  return _buildEmptyNotifications();
                }
                
                return _buildNotificationList(notificationList);
              },
              loading: () => const Center(
                child: CupertinoActivityIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text(
                  '알림을 불러오는 중 오류가 발생했습니다.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textEmphasis),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const CupertinoPageScaffold(
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      ),
      error: (error, stack) => CupertinoPageScaffold(
        child: Center(
          child: Text(
            '오류가 발생했습니다: $error',
            style: const TextStyle(color: AppColors.textEmphasis),
          ),
        ),
      ),
    );
  }
  
  // 로그인 안내 화면
  Widget _buildLoginPrompt() {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.cardBackground,
        middle: Text(
          '알림',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.bell_slash,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                '알림을 확인하려면 로그인하세요',
                style: TextStyle(
                  color: AppColors.textEmphasis,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                child: const Text('로그인하기'),
                onPressed: () {
                  // 로그인 화면으로 이동
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 알림이 없는 경우
  Widget _buildEmptyNotifications() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.bell_slash,
            size: 64,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            '알림이 없습니다',
            style: TextStyle(
              color: AppColors.textEmphasis,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '새로운 활동이 생기면 여기에 표시됩니다',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  // 알림 목록
  Widget _buildNotificationList(List<NotificationModel> notifications) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppColors.separator,
        height: 1,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }
  
  // 알림 항목
  Widget _buildNotificationItem(NotificationModel notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        // 알림 삭제
        ref.read(notificationControllerProvider.notifier)
            .deleteNotification(notification.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.systemRed,
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.white,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          // 알림 클릭 시 처리
          _handleNotificationTap(notification);
        },
        child: Container(
          color: notification.isRead 
            ? AppColors.darkBackground 
            : AppColors.primaryPurple.withAlpha(25),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationIcon(notification.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 알림 아이콘
  Widget _buildNotificationIcon(NotificationType type) {
    IconData iconData;
    Color iconColor;
    
    switch (type) {
      case NotificationType.comment:
        iconData = CupertinoIcons.chat_bubble;
        iconColor = AppColors.primaryPurple;
        break;
      case NotificationType.reply:
        iconData = CupertinoIcons.reply;
        iconColor = AppColors.primaryPurple;
        break;
      case NotificationType.like:
        iconData = CupertinoIcons.heart_fill;
        iconColor = CupertinoColors.systemPink;
        break;
      case NotificationType.follow:
        iconData = CupertinoIcons.person_add_solid;
        iconColor = CupertinoColors.systemBlue;
        break;
      case NotificationType.message:
        iconData = CupertinoIcons.envelope_fill;
        iconColor = CupertinoColors.systemOrange;
        break;
      case NotificationType.other:
        iconData = CupertinoIcons.bell_fill;
        iconColor = AppColors.textEmphasis;
        break;
    }
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withAlpha(50),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }
  
  // 알림 클릭 처리
  void _handleNotificationTap(NotificationModel notification) {
    // 1. 알림을 읽음 표시
    if (!notification.isRead) {
      ref.read(notificationControllerProvider.notifier)
          .markNotificationAsRead(notification.id);
    }
    
    // 2. 알림 타입에 따라 다른 화면으로 이동
    final data = notification.data;
    final targetId = data['targetId'] as String?;
    
    if (targetId == null) {
      debugPrint('알림에 targetId가 없습니다: ${notification.id}');
      return;
    }
    
    // 헬퍼 클래스를 사용하여 네비게이션 처리
    final type = notification.data['type'] as String?;
    NotificationHelpers.navigateToScreenByType(context, type, targetId);
  }
  
  // 시간 포맷 함수
  String _formatTime(DateTime dateTime) {
    // timeago 라이브러리가 한국어를 지원하지 않는 경우 직접 구현
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.month}월 ${dateTime.day}일';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}