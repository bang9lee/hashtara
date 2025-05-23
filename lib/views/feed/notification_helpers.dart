import 'package:flutter/cupertino.dart';
// 🔥 추가: 실제 화면 클래스들 import
import '../feed/post_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../feed/chat_detail_screen.dart';

// 🔥 추가: 글로벌 네비게이터 키 import
import '../../../main.dart' as main_file;

// 알림 관련 헬퍼 함수들
class NotificationHelpers {
  // 🔥 수정: 알림 타입에 따라 해당 화면으로 네비게이션 - 글로벌 네비게이터 사용
  static void navigateToScreenByType(BuildContext context, String? type, String targetId) {
    if (type == null || targetId.isEmpty) {
      debugPrint('알림 타입 또는 targetId가 없습니다.');
      return;
    }
    
    try {
      switch (type) {
        case 'comment':
        case 'reply':
        case 'like':
          // 게시물 상세 화면으로 이동
          _navigateToPost(context, targetId);
          break;
          
        case 'follow':
          // 프로필 화면으로 이동
          _navigateToProfile(context, targetId);
          break;
          
        case 'message':
          // 채팅 화면으로 이동
          _navigateToChat(context, targetId);
          break;
          
        default:
          debugPrint('알 수 없는 알림 타입: $type');
          _showErrorDialog(context, '지원하지 않는 알림 타입입니다.');
          break;
      }
    } catch (e) {
      debugPrint('네비게이션 처리 중 오류: $e');
      _showErrorDialog(context, '페이지를 불러올 수 없습니다.');
    }
  }
  
  // 🔥 수정: 게시물 상세 화면으로 이동 - 글로벌 네비게이터 사용
  static void _navigateToPost(BuildContext context, String postId) {
    try {
      debugPrint('게시물 화면으로 이동: $postId');
      
      // 🔥 글로벌 네비게이터 키 사용
      if (main_file.navigatorKey.currentState != null) {
        main_file.navigatorKey.currentState!.pushNamed('/post/$postId');
        debugPrint('글로벌 네비게이터로 게시물 화면 이동 성공');
      } else {
        // 🔥 대체 방법: 직접 네비게이션
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => PostDetailScreen(postId: postId),
          ),
        );
        debugPrint('직접 네비게이션으로 게시물 화면 이동');
      }
    } catch (e) {
      debugPrint('게시물 화면 이동 실패: $e');
      _showErrorDialog(context, '게시물을 불러올 수 없습니다.');
    }
  }
  
  // 🔥 수정: 프로필 화면으로 이동 - 글로벌 네비게이터 사용
  static void _navigateToProfile(BuildContext context, String userId) {
    try {
      debugPrint('프로필 화면으로 이동: $userId');
      
      // 🔥 글로벌 네비게이터 키 사용
      if (main_file.navigatorKey.currentState != null) {
        main_file.navigatorKey.currentState!.pushNamed('/profile/$userId');
        debugPrint('글로벌 네비게이터로 프로필 화면 이동 성공');
      } else {
        // 🔥 대체 방법: 직접 네비게이션
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => ProfileScreen(userId: userId),
          ),
        );
        debugPrint('직접 네비게이션으로 프로필 화면 이동');
      }
    } catch (e) {
      debugPrint('프로필 화면 이동 실패: $e');
      _showErrorDialog(context, '프로필을 불러올 수 없습니다.');
    }
  }
  
  // 🔥 수정: 채팅 화면으로 이동 - 글로벌 네비게이터 사용
  static void _navigateToChat(BuildContext context, String chatId) {
    try {
      debugPrint('채팅 화면으로 이동: $chatId');
      
      // 🔥 글로벌 네비게이터 키 사용
      if (main_file.navigatorKey.currentState != null) {
        main_file.navigatorKey.currentState!.pushNamed('/chat/$chatId');
        debugPrint('글로벌 네비게이터로 채팅 화면 이동 성공');
      } else {
        // 🔥 대체 방법: 직접 네비게이션
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatId,
              chatName: '채팅',
            ),
          ),
        );
        debugPrint('직접 네비게이션으로 채팅 화면 이동');
      }
    } catch (e) {
      debugPrint('채팅 화면 이동 실패: $e');
      _showErrorDialog(context, '채팅을 불러올 수 없습니다.');
    }
  }
  
  // 오류 다이얼로그 표시
  static void _showErrorDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  // 알림 타입별 아이콘 가져오기
  static IconData getNotificationIcon(String type) {
    switch (type) {
      case 'comment':
        return CupertinoIcons.chat_bubble;
      case 'reply':
        return CupertinoIcons.reply;
      case 'like':
        return CupertinoIcons.heart;
      case 'follow':
        return CupertinoIcons.person_add;
      case 'message':
        return CupertinoIcons.envelope;
      default:
        return CupertinoIcons.bell;
    }
  }
  
  // 알림 타입별 색상 가져오기
  static Color getNotificationColor(String type) {
    switch (type) {
      case 'comment':
        return CupertinoColors.systemBlue;
      case 'reply':
        return CupertinoColors.systemPurple;
      case 'like':
        return CupertinoColors.systemPink;
      case 'follow':
        return CupertinoColors.systemGreen;
      case 'message':
        return CupertinoColors.systemOrange;
      default:
        return CupertinoColors.systemGrey;
    }
  }
  
  // 시간 형식 변환 (상대적 시간)
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}';
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