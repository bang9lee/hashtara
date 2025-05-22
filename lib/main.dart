import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'services/firebase_service.dart';

// 글로벌 NavigatorKey 정의
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("백그라운드 메시지 수신: ${message.messageId}");
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