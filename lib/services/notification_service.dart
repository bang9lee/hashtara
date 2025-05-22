// notification_service.dart - 모든 오류 수정된 최종 버전
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 전역 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🔔 백그라운드 메시지 수신: ${message.notification?.title}");
  
  // 백그라운드에서도 로컬 알림 표시
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const androidDetails = AndroidNotificationDetails(
    'hashtara_notifications',
    'Hashtara 알림',
    channelDescription: '해시타라 앱의 모든 알림',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    enableVibration: true,
    playSound: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.message,
  );
  
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.active,
  );
  
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? '새 알림',
    message.notification?.body ?? '새로운 알림이 도착했습니다',
    const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
  );
}

// 알림 서비스 프로바이더
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // 초기화
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🔔 알림 서비스 이미 초기화됨');
      return;
    }
    
    try {
      debugPrint('🔔 알림 서비스 초기화 시작');
      
      // 1. FCM 권한 요청
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
        carPlay: true,
        announcement: true,
      );
      
      debugPrint('🔔 FCM 권한 상태: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('❌ FCM 권한이 거부되었습니다');
        return;
      }
      
      // 2. 로컬 알림 채널 생성 (Android)
      await _createNotificationChannel();
      
      // 3. 로컬 알림 플러그인 초기화
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );
      
      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // 4. FCM 토큰 가져오기 및 저장
      await _setupFCMToken();
      
      // 5. 메시지 리스너 설정
      _setupMessageListeners();
      
      // 6. 백그라운드 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      
      _initialized = true;
      debugPrint('✅ 알림 서비스 초기화 완료');
      
    } catch (e) {
      debugPrint('❌ 알림 서비스 초기화 실패: $e');
    }
  }
  
  // Android 알림 채널 생성
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'hashtara_notifications',
      'Hashtara 알림',
      description: '해시타라 앱의 모든 알림',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
        
    debugPrint('✅ Android 알림 채널 생성 완료');
  }
  
  // FCM 토큰 설정
  Future<void> _setupFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📱 FCM 토큰 획득: ${token.substring(0, 20)}...');
        await _saveTokenToFirestore(token);
      }
      
      // 토큰 갱신 리스너
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM 토큰 갱신됨');
        _saveTokenToFirestore(newToken);
      });
      
    } catch (e) {
      debugPrint('❌ FCM 토큰 설정 실패: $e');
    }
  }
  
  // 토큰을 Firestore에 저장
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('사용자가 로그인되지 않음 - 토큰 저장 건너뜀');
        return;
      }
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('💾 FCM 토큰 저장 완료');
    } catch (e) {
      debugPrint('❌ FCM 토큰 저장 실패: $e');
    }
  }
  
  // 메시지 리스너 설정
  void _setupMessageListeners() {
    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 포그라운드 메시지 수신: ${message.notification?.title}');
      showLocalNotification(message);
    });
    
    // 백그라운드에서 앱이 열릴 때
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🚀 백그라운드에서 앱 열림: ${message.notification?.title}');
      _handleNotificationTap(message.data);
    });
    
    // 앱이 완전히 종료된 상태에서 알림 탭으로 열릴 때
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('🚀 앱 시작 시 알림: ${message.notification?.title}');
        _handleNotificationTap(message.data);
      }
    });
  }
  
  // 로컬 알림 표시 (public 메서드로 변경)
  Future<void> showLocalNotification(RemoteMessage message) async {
    try {
      // 동적 값을 포함하는 객체는 const 제거
      final androidDetails = AndroidNotificationDetails(
        'hashtara_notifications',
        'Hashtara 알림',
        channelDescription: '해시타라 앱의 모든 알림',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        fullScreenIntent: true,
        autoCancel: true,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        message.notification?.title ?? '새 알림',
        message.notification?.body ?? '새로운 알림이 도착했습니다',
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        payload: message.data.toString(),
      );
      
      debugPrint('✅ 로컬 알림 표시 성공');
      
    } catch (e) {
      debugPrint('❌ 로컬 알림 표시 실패: $e');
    }
  }
  
  // 알림 탭 처리
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 알림 탭됨: ${response.payload}');
    _handleNotificationTap(_parsePayload(response.payload ?? '{}'));
  }
  
  // 알림 데이터 처리
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final targetId = data['targetId'] as String?;
    
    debugPrint('🎯 알림 처리: $type -> $targetId');
    
    // 여기서 적절한 화면으로 네비게이션 처리
    // 실제 구현에서는 Navigator나 Router를 사용
  }
  
  // 페이로드 파싱
  Map<String, dynamic> _parsePayload(String payload) {
    try {
      // 간단한 파싱 - 실제로는 JSON 사용
      return {};
    } catch (e) {
      return {};
    }
  }
  
  // FCM 토큰 가져오기
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('❌ 토큰 가져오기 실패: $e');
      return null;
    }
  }
  
  // FCM 토큰 설정 (기존 코드 호환성)
  Future<void> setupFCMToken() async {
    await _setupFCMToken();
  }
  
  // 토큰 삭제 (로그아웃 시)
  Future<void> deleteToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
        }
      }
      
      await _messaging.deleteToken();
      debugPrint('🗑️ FCM 토큰 삭제 완료');
    } catch (e) {
      debugPrint('❌ FCM 토큰 삭제 실패: $e');
    }
  }
  
  // 배지 카운트 초기화
  Future<void> resetBadgeCount() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('🔄 앱 배지 초기화 완료');
    } catch (e) {
      debugPrint('❌ 앱 배지 초기화 실패: $e');
    }
  }
  
  // 모든 알림 읽음 표시
  Future<void> markNotificationsAsRead() async {
    try {
      await resetBadgeCount();
      debugPrint('✅ 모든 알림 읽음 처리 완료');
    } catch (e) {
      debugPrint('❌ 알림 읽음 처리 실패: $e');
    }
  }
  
  // 테스트 알림 전송
  Future<void> sendTestNotification() async {
    try {
      await _localNotifications.show(
        999,
        '테스트 알림',
        '알림 시스템이 정상 작동합니다!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hashtara_notifications',
            'Hashtara 알림',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      debugPrint('✅ 테스트 알림 전송 완료');
    } catch (e) {
      debugPrint('❌ 테스트 알림 전송 실패: $e');
    }
  }
}