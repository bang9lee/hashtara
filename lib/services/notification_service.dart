import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 전역 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("백그라운드 메시지: ${message.notification?.title}");
}

// 알림 서비스 프로바이더
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// 간단한 알림 서비스
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // 초기화
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      debugPrint('알림 서비스 초기화 시작');
      
      // 1. 권한 요청
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // 2. 로컬 알림 초기화
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          debugPrint('알림 클릭됨');
        },
      );
      
      // 3. 백그라운드 핸들러 설정
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      
      // 4. 포그라운드 메시지 처리
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('포그라운드 메시지: ${message.notification?.title}');
        _showNotification(message);
      });
      
      // 5. 앱이 백그라운드에서 열릴 때
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('백그라운드에서 앱 열림: ${message.notification?.title}');
      });
      
      // 6. FCM 토큰 가져오기
      final token = await _messaging.getToken();
      debugPrint('FCM 토큰: ${token?.substring(0, 20)}...');
      
      _initialized = true;
      debugPrint('알림 서비스 초기화 완료');
      
    } catch (e) {
      debugPrint('알림 서비스 초기화 실패: $e');
    }
  }
  
  // 로컬 알림 표시
  Future<void> _showNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'hashtara_notifications',
        'Hashtara 알림',
        channelDescription: '해시타라 앱 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        message.notification?.title ?? '새 알림',
        message.notification?.body ?? '새로운 알림이 도착했습니다',
        const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );
    } catch (e) {
      debugPrint('알림 표시 실패: $e');
    }
  }
  
  // FCM 토큰 가져오기
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('토큰 가져오기 실패: $e');
      return null;
    }
  }
  
  // 🔥 새로 추가: FCM 토큰 설정
  Future<void> setupFCMToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        debugPrint('FCM 토큰 설정 완료: ${token.substring(0, 20)}...');
        // 여기서 사용자의 FCM 토큰을 Firestore에 저장할 수 있습니다
      }
    } catch (e) {
      debugPrint('FCM 토큰 설정 실패: $e');
    }
  }
  
  // 🔥 새로 추가: FCM 토큰 삭제
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('FCM 토큰 삭제 완료');
    } catch (e) {
      debugPrint('FCM 토큰 삭제 실패: $e');
    }
  }
  
  // 🔥 새로 추가: 앱 배지 초기화
  Future<void> resetBadgeCount() async {
    try {
      // iOS에서 배지 카운트 초기화
      await _localNotifications.cancelAll();
      debugPrint('앱 배지 초기화 완료');
    } catch (e) {
      debugPrint('앱 배지 초기화 실패: $e');
    }
  }
  
  // 🔥 새로 추가: 모든 알림 읽음 표시
  Future<void> markNotificationsAsRead() async {
    try {
      await resetBadgeCount();
      debugPrint('모든 알림 읽음 처리 완료');
    } catch (e) {
      debugPrint('알림 읽음 처리 실패: $e');
    }
  }
}