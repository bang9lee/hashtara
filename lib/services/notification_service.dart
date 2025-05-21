import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../repositories/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/feed/notification_helpers.dart'; 

// main.dart에서 정의된 전역 navigatorKey 가져오기
import '../main.dart' show navigatorKey;

// 알림 서비스 프로바이더
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

// 새 알림 여부 상태 프로바이더
final hasUnreadNotificationsProvider = StateProvider<bool>((ref) => false);

// 알림 서비스 클래스
class NotificationService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _notificationRepository = NotificationRepository();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
      
  // Android 알림 채널 ID
  static const String _androidChannelId = 'hashtara_notifications';
  // Android 알림 채널 이름
  static const String _androidChannelName = 'Hashtara 알림';
  // Android 알림 채널 설명
  static const String _androidChannelDescription = '해시타라 앱의 알림 채널입니다.';
  
  // 앱 시작 시 초기화 여부
  bool _isInitialized = false;

  NotificationService(this._ref) {
    _initNotifications();
  }

  // 알림 초기화
  Future<void> _initNotifications() async {
    if (_isInitialized) {
      debugPrint('알림 서비스가 이미 초기화됨');
      return;
    }
    
    try {
      debugPrint('알림 서비스 초기화 시작');
      
      // 1. 권한 요청
      await _requestPermissions();

      // 2. 로컬 알림 설정
      await _setupLocalNotifications();

      // 3. FCM 핸들러 설정
      _setupFCMHandlers();
      
      // 4. 초기 메시지 처리
      await _handleInitialMessage();

      // 5. 현재 사용자가 있으면 FCM 토큰 가져오기 및 저장
      await setupFCMToken();
      
      // 6. 토큰 갱신 이벤트 핸들러
      _setupTokenRefresh();
      
      // 초기화 완료 표시
      _isInitialized = true;
      debugPrint('알림 서비스 초기화 완료');
    } catch (e) {
      debugPrint('알림 서비스 초기화 실패: $e');
    }
  }

  // 권한 요청
  Future<void> _requestPermissions() async {
    try {
      // FCM 권한 요청
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        carPlay: false,
        criticalAlert: true, // 중요 알림 허용
        provisional: false,
      );

      // 로컬 알림 권한 요청 - iOS
      await _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true, // 중요 알림 허용
          );

      // 권한 상태 로그
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM 알림 권한 승인됨');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('FCM 알림 임시 권한 승인됨');
      } else {
        debugPrint('FCM 알림 권한 거부됨: ${settings.authorizationStatus}');
      }
    } catch (e) {
      debugPrint('알림 권한 요청 실패: $e');
      rethrow;
    }
  }

  // 로컬 알림 설정
  Future<void> _setupLocalNotifications() async {
    try {
      // Android 초기화 설정
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 초기화 설정
      final initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
        // 알림 클릭 시 앱 열기 설정 추가
        notificationCategories: [
          DarwinNotificationCategory(
            'message',
            actions: [
              DarwinNotificationAction.plain(
                'OPEN',
                '열기',
                options: {DarwinNotificationActionOption.foreground},
              ),
            ],
            options: {
              DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            },
          )
        ],
      );

      // 초기화 설정 통합
      final initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // 로컬 알림 초기화
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
      );

      // Android 채널 설정
      final androidChannel = AndroidNotificationChannel(
        _androidChannelId, // 채널 ID
        _androidChannelName, // 채널 이름
        description: _androidChannelDescription, // 채널 설명
        importance: Importance.max, // high에서 max로 변경
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        enableLights: true,
        ledColor: const Color(0xFF7C5FFF), // 보라색
        showBadge: true, // 앱 아이콘에 배지 표시
      );

      // Android 채널 생성
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      debugPrint('로컬 알림 설정 완료');
    } catch (e) {
      debugPrint('로컬 알림 설정 실패: $e');
      rethrow;
    }
  }

  // FCM 토큰 가져오기 및 저장 - Public 메소드로 변경
  Future<void> setupFCMToken() async {
    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        debugPrint('사용자 로그인 상태가 아님, FCM 토큰 저장 건너뜀');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM 토큰: ${token.substring(0, 10)}...'); // 보안상 전체 토큰 로그 출력 자제
        await _notificationRepository.saveUserFCMToken(user.id, token);
        
        // iOS에서 APNs 토큰도 가져와 로그로 확인
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('APNs 토큰: ${apnsToken.substring(0, 10)}...');
        } else {
          debugPrint('APNs 토큰을 가져올 수 없음');
        }
      } else {
        debugPrint('FCM 토큰을 가져올 수 없음');
      }
    } catch (e) {
      debugPrint('FCM 토큰 저장 실패: $e');
    }
  }

  // FCM 메시지 핸들러 설정
  void _setupFCMHandlers() {
    // 앱이 포그라운드 상태일 때 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('포그라운드 메시지 수신: ${message.notification?.title}');
      debugPrint('메시지 데이터: ${message.data}');
      
      _handleMessage(message, isAppOpen: true);
      
      // 새 알림 상태 업데이트
      _ref.read(hasUnreadNotificationsProvider.notifier).state = true;
    });

    // 앱이 백그라운드 상태에서 알림 탭 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('백그라운드에서 알림 탭됨: ${message.notification?.title}');
      debugPrint('메시지 데이터: ${message.data}');
      
      // 지연 추가 - 앱이 완전히 로드된 후 실행하기 위해
      Future.delayed(const Duration(milliseconds: 1000), () {
        _navigateToPageFromMessage(message);
      });
    });
  }

  // 토큰 갱신 이벤트 핸들러
  void _setupTokenRefresh() {
    _messaging.onTokenRefresh.listen((String token) async {
      try {
        final user = _ref.read(currentUserProvider).valueOrNull;
        if (user != null) {
          await _notificationRepository.saveUserFCMToken(user.id, token);
          debugPrint('FCM 토큰 갱신됨: ${token.substring(0, 10)}...');
        }
      } catch (e) {
        debugPrint('FCM 토큰 갱신 실패: $e');
      }
    });
  }

  // 앱 시작 시 초기 메시지 처리
  Future<void> _handleInitialMessage() async {
    try {
      // 앱이 종료된 상태에서 알림 탭으로 열린 경우
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

      if (initialMessage != null) {
        debugPrint('초기 메시지 수신: ${initialMessage.notification?.title}');
        debugPrint('초기 메시지 데이터: ${initialMessage.data}');
        
        // 초기 메시지 정보 저장 (앱이 완전히 로드된 후 처리하기 위해)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('initial_message', json.encode({
          'id': initialMessage.messageId,
          'data': initialMessage.data,
        }));
        
        // 앱이 완전히 로드된 후 처리하기 위해 지연
        await Future.delayed(const Duration(seconds: 2));
        _navigateToPageFromMessage(initialMessage);
      } else {
        // 저장된 초기 메시지가 있는지 확인
        final prefs = await SharedPreferences.getInstance();
        final savedMessage = prefs.getString('initial_message');
        
        if (savedMessage != null) {
          debugPrint('저장된 초기 메시지 발견');
          final messageData = json.decode(savedMessage) as Map<String, dynamic>;
          
          // 지연 후 처리
          await Future.delayed(const Duration(seconds: 2));
          _navigateByNotificationType(messageData['data'] as Map<String, dynamic>);
          
          // 처리 후 삭제
          await prefs.remove('initial_message');
        }
      }
    } catch (e) {
      debugPrint('초기 메시지 처리 실패: $e');
    }
  }

  // 메시지 처리
  void _handleMessage(RemoteMessage message, {bool isAppOpen = false}) {
    try {
      // 1. DB에 알림 저장
      _saveNotificationToDatabase(message);

      // 2. 앱이 열려있는 경우 로컬 알림 표시
      if (isAppOpen) {
        _showLocalNotification(message);
      }
    } catch (e) {
      debugPrint('메시지 처리 실패: $e');
    }
  }

  // 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {
        await _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              channelDescription: _androidChannelDescription,
              icon: android?.smallIcon ?? 'ic_launcher',
              color: const Color(0xFF7C5FFF), // 앱 브랜드 색상 (보라색)
              importance: Importance.max, // high에서 max로 변경
              priority: Priority.max, // high에서 max로 변경
              playSound: true,
              enableVibration: true,
              vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
              enableLights: true,
              ledColor: const Color(0xFF7C5FFF),
              ticker: '새로운 알림이 있습니다',
              showWhen: true, // 알림 시간 표시
              visibility: NotificationVisibility.public, // 잠금 화면에서 표시
              fullScreenIntent: true, // 전체 화면 알림 (중요 알림)
              category: AndroidNotificationCategory.message, // 알림 종류 지정
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              sound: 'default',
              badgeNumber: 1,
              interruptionLevel: InterruptionLevel.active, // 알림 우선순위 (즉시 표시)
              categoryIdentifier: 'message',
            ),
          ),
          payload: json.encode(message.data),
        );
        debugPrint('로컬 알림 표시 성공: ${notification.title}');
      }
    } catch (e) {
      debugPrint('로컬 알림 표시 실패: $e');
    }
  }

  // 알림을 데이터베이스에 저장
  Future<void> _saveNotificationToDatabase(RemoteMessage message) async {
    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      final notificationType = _getNotificationType(message.data['type']);
      final notificationId = message.messageId ?? 
                            message.data['id'] ?? 
                            DateTime.now().millisecondsSinceEpoch.toString();

      final notification = NotificationModel(
        id: notificationId,
        userId: user.id,
        title: message.notification?.title ?? message.data['title'] ?? '',
        body: message.notification?.body ?? message.data['body'] ?? '',
        type: notificationType,
        data: message.data,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _notificationRepository.saveNotification(notification);
      debugPrint('알림 DB 저장 성공: $notificationId');
    } catch (e) {
      debugPrint('알림 DB 저장 실패: $e');
    }
  }

  // 알림 타입 변환
  NotificationType _getNotificationType(String? type) {
    switch (type) {
      case 'comment':
        return NotificationType.comment;
      case 'reply':
        return NotificationType.reply;
      case 'like':
        return NotificationType.like;
      case 'follow':
        return NotificationType.follow;
      case 'message':
        return NotificationType.message;
      default:
        return NotificationType.other;
    }
  }

  // 알림 탭 처리
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
        
        // 알림을 읽음 상태로 표시
        if (data['id'] != null) {
          _markNotificationAsRead(data['id'] as String);
        }
        
        // 알림 유형에 따라 화면 이동 (지연 추가)
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateByNotificationType(data);
        });
      } catch (e) {
        debugPrint('알림 페이로드 파싱 실패: $e');
      }
    }
  }

  // 알림을 읽음 상태로 표시
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await _notificationRepository.markNotificationAsRead(notificationId);
      
      // 알림 읽음 상태 변경 후 남아있는 안 읽은 알림 확인
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        final hasUnread = await _notificationRepository.hasUnreadNotifications(user.id);
        _ref.read(hasUnreadNotificationsProvider.notifier).state = hasUnread;
      }
      
      debugPrint('알림을 읽음 상태로 표시: $notificationId');
    } catch (e) {
      debugPrint('알림 읽음 상태 표시 실패: $e');
    }
  }

  // 메시지에서 페이지 네비게이션
  void _navigateToPageFromMessage(RemoteMessage message) {
    try {
      // 알림을 읽음 상태로 표시
      if (message.messageId != null) {
        _markNotificationAsRead(message.messageId!);
      } else if (message.data['id'] != null) {
        _markNotificationAsRead(message.data['id'] as String);
      }
      
      // 페이지 이동
      _navigateByNotificationType(message.data);
    } catch (e) {
      debugPrint('메시지 네비게이션 처리 실패: $e');
    }
  }

  // 알림 유형별 네비게이션 처리
  void _navigateByNotificationType(Map<String, dynamic> data) {
    try {
      // main.dart에서 정의된 전역 navigatorKey 사용
      final context = navigatorKey.currentContext;
      
      if (context == null) {
        debugPrint('유효한 BuildContext를 찾을 수 없음, 네비게이션 지연');
        // 컨텍스트를 찾을 수 없는 경우 정보 저장 후 나중에 처리
        _saveNavigationData(data);
        return;
      }

      final type = data['type'];
      final targetId = data['targetId'] as String?; // 관련된 항목 ID (게시물, 댓글, 메시지 등)

      if (targetId == null) {
        debugPrint('targetId가 없음, 네비게이션 취소');
        return;
      }

      // 각 타입별 네비게이션 처리 실행
      NotificationHelpers.navigateToScreenByType(context, type, targetId);
      
    } catch (e) {
      debugPrint('알림 네비게이션 실패: $e');
    }
  }
  
  // 네비게이션 임시 저장 (앱 시작 시 처리를 위해)
  Future<void> _saveNavigationData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_navigation', json.encode(data));
      debugPrint('네비게이션 데이터 저장됨: ${data['type']}');
    } catch (e) {
      debugPrint('네비게이션 데이터 저장 실패: $e');
    }
  }
  
  // 저장된 네비게이션 처리 (앱 시작 시 호출)
  Future<void> processPendingNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingNav = prefs.getString('pending_navigation');
      
      if (pendingNav != null) {
        final data = json.decode(pendingNav) as Map<String, dynamic>;
        
        // 앱이 완전히 로드된 후 처리하기 위해 지연
        await Future.delayed(const Duration(seconds: 2));
        _navigateByNotificationType(data);
        
        // 처리 후 삭제
        await prefs.remove('pending_navigation');
      }
    } catch (e) {
      debugPrint('저장된 네비게이션 처리 실패: $e');
    }
  }

  // 로그아웃 시 FCM 토큰 삭제
  Future<void> deleteToken() async {
    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        // 현재 기기의 토큰 가져오기
        final token = await _messaging.getToken();
        
        if (token != null) {
          // 특정 토큰만 삭제 (현재 기기)
          await _notificationRepository.deleteUserFCMToken(user.id, specificToken: token);
          debugPrint('FCM 토큰 삭제됨: ${token.substring(0, 10)}...');
        } else {
          // 토큰을 가져올 수 없는 경우 모든 토큰 삭제
          await _notificationRepository.deleteUserFCMToken(user.id);
          debugPrint('모든 FCM 토큰 삭제됨');
        }
      }
    } catch (e) {
      debugPrint('FCM 토큰 삭제 실패: $e');
    }
  }

  // 알림 읽음 상태로 표시
  Future<void> markNotificationsAsRead() async {
    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        await _notificationRepository.markAllNotificationsAsRead(user.id);
        _ref.read(hasUnreadNotificationsProvider.notifier).state = false;
        debugPrint('모든 알림 읽음 표시 성공');
      }
    } catch (e) {
      debugPrint('알림 읽음 표시 실패: $e');
    }
  }
  
  // iOS 앱 배지 수 설정
  Future<void> setIOSBadgeCount(int count) async {
    try {
      // iOS 플랫폼 확인
      final iOSPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
          
      if (iOSPlugin != null) {
        // 배지 수 직접 설정 (iOS에서는 앱 배지 수를 직접 설정하는 기능이 다른 패키지 필요)
        // 현재 버전의 flutter_local_notifications 패키지에서는 지원하지 않음
        // 알림을 통해 배지 수 간접 설정
        await _localNotifications.show(
          0, // 알림 ID
          null, // 제목 (표시 안함)
          null, // 내용 (표시 안함)
          NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: false, // 알림 표시 안함
              presentBadge: true, // 배지만 업데이트
              presentSound: false, // 소리 없음
              badgeNumber: count, // 배지 숫자 설정
            ),
            android: const AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              channelDescription: _androidChannelDescription,
              visibility: NotificationVisibility.secret, // 알림 표시 안함
              importance: Importance.min,
              priority: Priority.min,
              playSound: false,
              enableVibration: false,
            ),
          ),
        );
        debugPrint('iOS 앱 배지 수 설정: $count');
      } else {
        debugPrint('iOS 플러그인을 찾을 수 없음');
      }
    } catch (e) {
      debugPrint('iOS 앱 배지 수 설정 실패: $e');
    }
  }
  
  // 앱 배지 초기화
  Future<void> resetBadgeCount() async {
    try {
      // iOS 배지 초기화
      await setIOSBadgeCount(0);
      
      // Android는 별도로 처리할 필요 없음
      debugPrint('앱 배지 초기화 완료');
    } catch (e) {
      debugPrint('앱 배지 초기화 실패: $e');
    }
  }
}