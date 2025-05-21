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

// 백그라운드 메시지 핸들러 (앱이 백그라운드 상태일 때 호출)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 핸들러에서는 SharedPreferences 등 복잡한 작업 자제
  await Firebase.initializeApp();
  
  // 최소한의 로그만 출력 (print 대신 debugPrint 사용)
  debugPrint("백그라운드 메시지 수신: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final logger = Logger();
  
  // 상태바 색상 설정 (다크모드에 맞게 수정)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0A0A1A),  // 다크 배경색으로 변경
      statusBarIconBrightness: Brightness.light,  // 아이콘을 밝게 설정
    ),
  );
  
  try {
    // Firebase Service를 통한 초기화 (App Check 포함)
    await FirebaseService.initializeFirebase();
    logger.i("Firebase initialized successfully with App Check");
    
    // FCM 백그라운드 핸들러 등록 (initializeFirebase 이후 호출)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // 앱 상태 디버깅을 위한 설정
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.e("Flutter Error: ${details.exception}\n${details.stack}");
      
      // 추가: Navigator 락 관련 오류를 확인하고 처리
      if (details.exception.toString().contains('Failed assertion: line 5859 pos 12')) {
        logger.e("Navigator lock error detected! This can happen when multiple navigations occur simultaneously.");
      }
    };
    
  } catch (e, stack) {
    logger.e("Failed to initialize Firebase: $e\n$stack");
    // Firebase 초기화 실패 시 사용자에게 알림
    runApp(
      const ProviderScope(
        child: FirebaseInitErrorApp(),
      ),
    );
    return;
  }
  
  runApp(
    ProviderScope(
      observers: [
        // ProviderObserver 추가하여 상태 변화 디버깅
        // 개발 환경에서만 활성화하는 것이 좋음
        FilteredProviderLogger(),
      ],
      child: const HashtaraApp(), // ConnectSpaceApp에서 HashtaraApp으로 변경
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

// Riverpod 상태 변화를 로깅하기 위한 필터된 로거 클래스
class FilteredProviderLogger extends ProviderObserver {
  final logger = Logger();
  
  // 필터링할 프로바이더 타입 목록
  final Set<String> _filteredProviderTypes = {
    'StreamProvider<bool>',
    'FutureProvider<bool>',
    'StateNotifierProvider<ChannelSubscriptionController, AsyncValue<bool>>',
    'AutoDisposeStreamProvider<bool>', // 좋아요 상태 프로바이더 필터링
  };
  
  // 필터링할 프로바이더 이름 목록
  final Set<String> _filteredProviderNames = {
    'channelSubscription',
    'channelSubscriptionProvider',
    'channelSubscriptionControllerProvider',
    'commentLikeStatus', // 댓글 좋아요 상태 프로바이더 필터링
  };
  
  // 마지막으로 로깅한 시간 저장 (스팸 방지)
  final Map<String, DateTime> _lastLoggedTime = {};
  
  // 프로바이더 필터링 통합 메서드
  bool _shouldFilter(String providerType, String providerName) {
    // 타입으로 필터링
    if (_filteredProviderTypes.contains(providerType)) {
      return true;
    }
    
    // 이름으로 필터링
    for (final name in _filteredProviderNames) {
      if (providerName.contains(name)) {
        return true;
      }
    }
    
    return false; // 필터링 대상 아님
  }
  
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    final providerType = provider.runtimeType.toString();
    final providerName = provider.name ?? providerType;
    
    // 필터링할 프로바이더인지 확인
    if (_shouldFilter(providerType, providerName)) {
      return; // 필터링 대상이면 로깅하지 않음
    }
    
    // 마지막 로깅 시간 확인
    final now = DateTime.now();
    final lastTime = _lastLoggedTime[providerType] ?? DateTime(2000);
    
    // 5초 이내에 동일 프로바이더 타입의 로그가 있으면 생략
    if (now.difference(lastTime).inSeconds < 5) {
      return;
    }
    
    // 시간 업데이트
    _lastLoggedTime[providerType] = now;
    
    // 필터 통과한 프로바이더만 로깅
    logger.d(
      'Provider ${provider.name ?? provider.runtimeType} updated: $newValue',
    );
  }
  
  @override
  void didAddProvider(
    ProviderBase provider,
    Object? value,
    ProviderContainer container,
  ) {
    final providerType = provider.runtimeType.toString();
    final providerName = provider.name ?? providerType;
    
    // 필터링할 프로바이더인지 확인
    if (_shouldFilter(providerType, providerName)) {
      return; // 필터링 대상이면 로깅하지 않음
    }
    
    logger.d(
      'Provider ${provider.name ?? provider.runtimeType} added: $value',
    );
  }
  
  @override
  void didDisposeProvider(
    ProviderBase provider,
    ProviderContainer container,
  ) {
    final providerType = provider.runtimeType.toString();
    final providerName = provider.name ?? providerType;
    
    // 필터링할 프로바이더인지 확인
    if (_shouldFilter(providerType, providerName)) {
      return; // 필터링 대상이면 로깅하지 않음
    }
    
    logger.d(
      'Provider ${provider.name ?? provider.runtimeType} disposed',
    );
  }
}