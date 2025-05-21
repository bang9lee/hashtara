import 'package:flutter/cupertino.dart';

/// NotificationHelpers 클래스는 알림 관련 네비게이션 로직을 서비스 클래스에서 분리하여
/// 화면 위젯 생성 및 네비게이션 처리를 담당합니다.
class NotificationHelpers {
  
  /// 알림 유형에 따른 화면 이동을 처리합니다.
  static void navigateToScreenByType(BuildContext context, String? type, String targetId) {
    // 루트 네비게이터 사용 (탭 내부 네비게이터가 아닌)
    switch (type) {
      case 'comment':
      case 'reply':
      case 'like':
        // 게시물 화면으로 이동
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => _buildPostDetailScreen(targetId),
            settings: RouteSettings(name: '/post/$targetId'),
          ),
        );
        debugPrint('게시물 화면으로 이동: $targetId (루트 네비게이터 사용)');
        break;
        
      case 'message':
        // 메시지 화면으로 이동
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => _buildChatDetailScreen(targetId),
            settings: RouteSettings(name: '/chat/$targetId'),
          ),
        );
        debugPrint('채팅 화면으로 이동: $targetId (루트 네비게이터 사용)');
        break;
        
      case 'follow':
        // 사용자 프로필 화면으로 이동
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => _buildProfileScreen(targetId),
            settings: RouteSettings(name: '/profile/$targetId'),
          ),
        );
        debugPrint('사용자 프로필 화면으로 이동: $targetId (루트 네비게이터 사용)');
        break;
        
      default:
        // 'open_page' 액션이 있는지 확인 후 처리
        debugPrint('알 수 없는 알림 유형: $type');
        break;
    }
  }
  
  /// 알림에서 특정 페이지로 이동하는 처리를 합니다.
  static void navigateToPageFromAction(BuildContext context, Map<String, dynamic> data) {
    final action = data['action'] as String?;
    
    if (action == null) return;
    
    switch (action) {
      case 'open_url':
        final url = data['url'] as String?;
        if (url != null) {
          debugPrint('URL 열기: $url');
          // URL 열기 로직 구현 (별도 구현 필요)
        }
        break;
      
      case 'open_page':
        final page = data['page'] as String?;
        if (page != null) {
          debugPrint('페이지 열기: $page');
          // 전역 네비게이터 사용
          Navigator.of(context, rootNavigator: true).pushNamed('/$page');
        }
        break;
      
      default:
        debugPrint('알 수 없는 커스텀 알림 액션: $action');
        break;
    }
  }
  
  // 게시물 상세 화면
  static Widget _buildPostDetailScreen(String postId) {
    // 게시물 상세 화면 위젯 반환 (실제 앱에 맞게 구현)
    // 예: return PostDetailScreen(postId: postId);
    // 임시 구현
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('게시물'),
      ),
      child: Center(
        child: Text('게시물 $postId 상세 화면'),
      ),
    );
  }

  // 채팅 상세 화면
  static Widget _buildChatDetailScreen(String chatId) {
    // 채팅 상세 화면 위젯 반환 (실제 앱에 맞게 구현)
    // 예: return ChatDetailScreen(chatId: chatId);
    // 임시 구현
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('채팅'),
      ),
      child: Center(
        child: Text('채팅 $chatId 상세 화면'),
      ),
    );
  }

  // 사용자 프로필 화면
  static Widget _buildProfileScreen(String userId) {
    // 프로필 화면 위젯 반환 (실제 앱에 맞게 구현)
    // 예: return ProfileScreen(userId: userId);
    // 임시 구현
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('프로필'),
      ),
      child: Center(
        child: Text('사용자 $userId 프로필 화면'),
      ),
    );
  }
}