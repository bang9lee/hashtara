import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

// 글로벌 NavigatorKey 정의
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🔔 백그라운드 메시지 수신: ${message.messageId}");
  debugPrint("🔔 알림 제목: ${message.notification?.title}");
  debugPrint("🔔 알림 내용: ${message.notification?.body}");
  debugPrint("🔔 데이터: ${message.data}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final logger = Logger();
  
  // 상태바 색상 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0A0A1A),
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  try {
    // Firebase 초기화
    await FirebaseService.initializeFirebase();
    logger.i("Firebase initialized successfully");
    
    // FCM 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // FCM 권한 요청 및 토큰 확인
    await _setupFCM();
    
    // 에러 핸들링
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.e("Flutter Error: ${details.exception}\n${details.stack}");
    };
    
  } catch (e, stack) {
    logger.e("Failed to initialize Firebase: $e\n$stack");
    runApp(
      const ProviderScope(
        child: FirebaseInitErrorApp(),
      ),
    );
    return;
  }
  
  runApp(
    const ProviderScope(
      child: HashtaraApp(),
    ),
  );
}

// FCM 설정 및 토큰 확인
Future<void> _setupFCM() async {
  try {
    // FCM 권한 요청
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    debugPrint('🔔 FCM 권한 상태: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // FCM 토큰 가져오기
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('🔥🔥🔥 현재 기기의 FCM 토큰:');
      debugPrint('$token');
      debugPrint('🔥🔥🔥 토큰 끝');
      
      // 포그라운드 메시지 리스너
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📱 포그라운드 메시지 수신:');
        debugPrint('제목: ${message.notification?.title}');
        debugPrint('내용: ${message.notification?.body}');
        debugPrint('데이터: ${message.data}');
        
        // 로컬 알림 표시
        final notificationService = NotificationService();
        notificationService.showLocalNotification(message);
      });
      
      // 백그라운드에서 앱이 열릴 때
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🚀 백그라운드에서 앱 열림:');
        debugPrint('데이터: ${message.data}');
        _handleNotificationTap(message.data);
      });
      
      // 앱이 종료된 상태에서 알림으로 열릴 때
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🚀 종료 상태에서 알림으로 앱 열림');
        _handleNotificationTap(initialMessage.data);
      }
      
    } else {
      debugPrint('❌ FCM 권한이 거부되었습니다');
    }
  } catch (e) {
    debugPrint('❌ FCM 설정 오류: $e');
  }
}

// 알림 탭 핸들러
void _handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final targetId = data['targetId'] as String?;
  
  debugPrint('🎯 알림 탭 처리: type=$type, targetId=$targetId');
  
  if (type == null || targetId == null) return;
  
  // navigatorKey를 사용하여 화면 이동
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      switch (type) {
        case 'comment':
        case 'reply':
        case 'like':
          Navigator.of(context).pushNamed('/post/$targetId');
          break;
        case 'follow':
          Navigator.of(context).pushNamed('/profile/$targetId');
          break;
        case 'message':
          Navigator.of(context).pushNamed('/chat/$targetId');
          break;
      }
    }
  });
}

// Firebase 초기화 에러 화면
class FirebaseInitErrorApp extends StatelessWidget {
  const FirebaseInitErrorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      home: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('오류'),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: CupertinoColors.systemRed,
                  size: 50,
                ),
                SizedBox(height: 16),
                Text(
                  'Firebase 초기화 중 오류가 발생했습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '앱을 다시 시작하거나 인터넷 연결을 확인해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}