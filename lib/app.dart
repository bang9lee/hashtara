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

// 🔥 실제 화면 클래스들 import 추가
import 'views/feed/post_detail_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/feed/chat_detail_screen.dart';

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

class _HashtaraAppState extends ConsumerState<HashtaraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 앱 시작 시 간단한 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    // 🔥 강제 로그아웃 플래그 감시 - 개선된 로직
    final forceLogout = ref.watch(forceLogoutProvider);
    final authState = ref.watch(authStateProvider);
    final signupProgress = ref.watch(signupProgressProvider);
    
    // 디버그 로그 추가
    debugPrint('HashtaraApp 리빌드됨 - AuthState: ${authState.runtimeType}, 진행상태: $signupProgress, 강제로그아웃: $forceLogout');
    
    return CupertinoApp(
      title: 'Hashtara',
      navigatorKey: main_file.navigatorKey,
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
        NavigationLogger(),
      ],
      
      // 🔥 수정: home 제거하고 initialRoute 사용
      initialRoute: '/',
      
      // 🔥 수정: routes에서 모든 라우트 정의
      routes: {
        '/': (context) => _buildHome(),
        '/login': (context) => const LoginScreen(),
        '/splash': (context) => const SplashScreen(),
      },
      
      // 🔥 수정: 동적 라우트 처리 - 실제 화면 클래스 사용
      onGenerateRoute: (settings) {
        debugPrint('라우트 생성: ${settings.name}');
        
        final uri = Uri.parse(settings.name ?? '/');
        final pathSegments = uri.pathSegments;
        
        if (pathSegments.isNotEmpty) {
          if (pathSegments[0] == 'post' && pathSegments.length > 1) {
            final postId = pathSegments[1];
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => PostDetailScreen(postId: postId),
            );
          } else if (pathSegments[0] == 'profile' && pathSegments.length > 1) {
            final userId = pathSegments[1];
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => ProfileScreen(userId: userId),
            );
          } else if (pathSegments[0] == 'chat' && pathSegments.length > 1) {
            final chatId = pathSegments[1];
            return CupertinoPageRoute(
              settings: settings,
              builder: (context) => ChatDetailScreen(
                chatId: chatId,
                chatName: '채팅', // 기본값, 실제로는 채팅방 정보에서 가져와야 함
              ),
            );
          }
        }
        
        return null;
      },
    );
  }
  
  // 🔥 홈 화면 빌드 로직 - 강제 로그아웃 우선 처리
  Widget _buildHome() {
    final forceLogout = ref.watch(forceLogoutProvider);
    final authState = ref.watch(authStateProvider);
    final signupProgress = ref.watch(signupProgressProvider);
    
    // 디버그 로그 추가
    debugPrint('HashtaraApp 리빌드됨 - AuthState: ${authState.runtimeType}, 진행상태: $signupProgress, 강제로그아웃: $forceLogout');
    
    // 🔥🔥🔥 강제 로그아웃 최우선 처리 - 다른 모든 로직보다 우선
    if (forceLogout) {
      debugPrint('🔥🔥🔥 강제 로그아웃 상태 감지 → 무조건 로그인 화면');
      
      // 🔥 플래그 리셋을 즉시 실행하되 안전하게 처리
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              debugPrint('🔥 forceLogout 플래그 리셋');
              ref.read(forceLogoutProvider.notifier).state = false;
            }
          });
        }
      });
      
      return const LoginScreen();
    }
    
    // 🔥 기존 로직: authState 처리
    return authState.when(
      data: (user) {
        debugPrint('🔥 AuthState 데이터 수신: user=${user?.uid}');
        
        if (user == null) {
          debugPrint('🔥 사용자 로그인되지 않음, 로그인 화면으로 이동');
          return const LoginScreen();
        } else {
          debugPrint('✅ 로그인된 사용자 확인: ${user.uid}');
          
          final currentUserAsync = ref.watch(currentUserProvider);
          
          return currentUserAsync.when(
            data: (userModel) {
              debugPrint('🔥 CurrentUser 데이터: ${userModel?.id}');
              
              if (userModel == null) {
                debugPrint('🔥 사용자 모델이 null - 회원가입 프로세스 확인');
                
                switch (signupProgress) {
                  case SignupProgress.registered:
                    debugPrint('➡️ 약관 동의 필요: ${user.uid}');
                    return TermsAgreementScreen(userId: user.uid);
                  case SignupProgress.termsAgreed:
                    debugPrint('➡️ 프로필 설정 필요: ${user.uid}');
                    return SetupProfileScreen(userId: user.uid);
                  case SignupProgress.completed:
                    debugPrint('➡️ 완료된 사용자인데 userModel이 null - 메인 화면으로');
                    return const MainTabScreen();
                  case SignupProgress.none:
                    debugPrint('🔥 진행 상태가 없음 - 로그인 화면으로');
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
              return const LoginScreen();
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
        return const LoginScreen();
      },
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