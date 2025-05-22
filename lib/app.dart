import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'constants/app_colors.dart';
import 'views/common/splash_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/profile/setup_profile_screen.dart';
import 'views/auth/terms_agreement_screen.dart';
import 'views/feed/main_tab_screen.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart'; 

// main.dart의 navigatorKey 가져오기
import 'main.dart' as main_file;

// 초기 라우팅 상태를 관리하는 프로바이더
final initialRouteProvider = StateProvider<String>((ref) => 'splash');

// 라우트 설정을 위한 헬퍼 클래스
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const termsAgreement = '/terms';
  static const setupProfile = '/setup-profile';
  static const main = '/main';
  
  // 동적 라우트
  static String post(String id) => '/post/$id';
  static String profile(String id) => '/profile/$id';
  static String chat(String id) => '/chat/$id';
}

class HashtaraApp extends ConsumerStatefulWidget {
  const HashtaraApp({Key? key}) : super(key: key);

  @override
  ConsumerState<HashtaraApp> createState() => _HashtaraAppState();
}

class _HashtaraAppState extends ConsumerState<HashtaraApp> {
  @override
  void initState() {
    super.initState();
    
    // 앱 시작 시 간단한 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }
  
  // 간단한 앱 초기화
  Future<void> _initializeApp() async {
    try {
      // 1. 알림 서비스 초기화
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.initialize();
      
      // 2. 저장된 회원가입 상태 불러오기
      final savedState = await loadSignupProgress();
      if (savedState['userId'] != null) {
        ref.read(signupProgressProvider.notifier).state = savedState['progress'];
        debugPrint('저장된 회원가입 상태 복원: ${savedState['progress']}');
      }
    } catch (e) {
      debugPrint('앱 초기화 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 핵심 수정: authStateProvider를 직접 감시하여 즉시 반응
    final authState = ref.watch(authStateProvider);
    final signupProgress = ref.watch(signupProgressProvider);
    
    // 디버그 로그 추가
    debugPrint('HashtaraApp 리빌드됨 - AuthState: ${authState.runtimeType}, 진행상태: $signupProgress');
    
    return CupertinoApp(
      title: 'Hashtara',
      navigatorKey: main_file.navigatorKey, // 글로벌 네비게이터 키 추가
      theme: const CupertinoThemeData(
        primaryColor: AppColors.primaryPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        barBackgroundColor: AppColors.darkBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.primaryPurple,
          textStyle: TextStyle(color: AppColors.white),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        // 네비게이션 디버깅을 위한 observer 추가
        NavigationLogger(),
      ],
      // 명시적 라우트 정의 추가
      onGenerateRoute: (settings) {
        debugPrint('라우트 생성: ${settings.name}');
        
        // 라우트 이름 파싱
        final uri = Uri.parse(settings.name ?? '/');
        final pathSegments = uri.pathSegments;
        
        // 동적 라우트 처리
        if (pathSegments.isNotEmpty) {
          if (pathSegments[0] == 'post' && pathSegments.length > 1) {
            // 게시물 상세 화면 라우트
            final postId = pathSegments[1];
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => PostDetailScreen(postId: postId),
            );
          } else if (pathSegments[0] == 'profile' && pathSegments.length > 1) {
            // 프로필 화면 라우트
            final userId = pathSegments[1];
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => ProfileScreen(userId: userId),
            );
          } else if (pathSegments[0] == 'chat' && pathSegments.length > 1) {
            // 채팅 상세 화면 라우트
            final chatId = pathSegments[1];
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => ChatDetailScreen(chatId: chatId),
            );
          }
        }
        
        // 기본 라우트
        return null;
      },
      // 🔥 핵심 수정: authState를 직접 사용하여 즉시 반응하도록 수정
      home: authState.when(
        data: (user) {
          debugPrint('🔥 AuthState 데이터 수신: user=${user?.uid}');
          
          if (user == null) {
            debugPrint('🔥 사용자 로그인되지 않음, 로그인 화면으로 이동');
            return const LoginScreen(); // 🔥 바로 로그인 화면 반환
          } else {
            debugPrint('✅ 로그인된 사용자 확인: ${user.uid}');
            
            // currentUserProvider 감시 (사용자 문서 존재 여부 확인용)
            final currentUserAsync = ref.watch(currentUserProvider);
            
            return currentUserAsync.when(
              data: (userModel) {
                debugPrint('🔥 CurrentUser 데이터: ${userModel?.id}');
                
                // 사용자 모델이 null이면 회원가입 프로세스 진행
                if (userModel == null) {
                  debugPrint('🔥 사용자 모델이 null - 회원가입 프로세스 확인');
                  
                  // 현재 회원가입 진행 상태에 따라 화면 결정
                  switch (signupProgress) {
                    case SignupProgress.registered:
                      debugPrint('➡️ 약관 동의 필요: ${user.uid}');
                      return TermsAgreementScreen(userId: user.uid);
                    case SignupProgress.termsAgreed:
                      debugPrint('➡️ 프로필 설정 필요: ${user.uid}');
                      return SetupProfileScreen(userId: user.uid);
                    case SignupProgress.completed:
                    case SignupProgress.none:
                      debugPrint('🔥 알 수 없는 상태 - 로그인 화면으로');
                      return const LoginScreen();
                  }
                } else {
                  debugPrint('➡️ 기존 사용자 - 메인 화면으로 이동');
                  return const MainTabScreen();
                }
              },
              loading: () {
                debugPrint('🔥 CurrentUser 로딩 중...');
                return const SplashScreen();
              },
              error: (error, stack) {
                debugPrint('🔥 CurrentUser 에러: $error');
                return const LoginScreen(); // 🔥 에러 시 바로 로그인 화면
              },
            );
          }
        },
        loading: () {
          debugPrint('🔥 AuthState 로딩 중...');
          return const SplashScreen();
        },
        error: (error, stack) {
          debugPrint('🔥 AuthState 에러: $error');
          return const LoginScreen(); // 🔥 에러 시 바로 로그인 화면
        },
      ),
    );
  }
}

// 네비게이션 로그를 남기는 클래스
class NavigationLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navigation: PUSHED ${route.settings.name ?? route.toString()}');
    super.didPush(route, previousRoute);
  }
  
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navigation: POPPED ${route.settings.name ?? route.toString()}');
    super.didPop(route, previousRoute);
  }
  
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navigation: REMOVED ${route.settings.name ?? route.toString()}');
    super.didRemove(route, previousRoute);
  }
  
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint('Navigation: REPLACED ${oldRoute?.settings.name ?? oldRoute.toString()} WITH ${newRoute?.settings.name ?? newRoute.toString()}');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

// 임시 화면 위젯들 (실제 앱에 맞게 구현 필요)
class PostDetailScreen extends StatelessWidget {
  final String postId;
  
  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('게시물 $postId'),
      ),
      child: Center(
        child: Text('게시물 $postId 상세 화면'),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final String userId;
  
  const ProfileScreen({Key? key, required this.userId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('프로필 $userId'),
      ),
      child: Center(
        child: Text('사용자 $userId 프로필 화면'),
      ),
    );
  }
}

class ChatDetailScreen extends StatelessWidget {
  final String chatId;
  
  const ChatDetailScreen({Key? key, required this.chatId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('채팅 $chatId'),
      ),
      child: Center(
        child: Text('채팅 $chatId 상세 화면'),
      ),
    );
  }
}