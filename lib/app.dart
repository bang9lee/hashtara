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

// 초기 라우팅 상태를 관리하는 프로바이더
final initialRouteProvider = StateProvider<String>((ref) => 'splash');

class HashtaraApp extends ConsumerStatefulWidget {
  const HashtaraApp({Key? key}) : super(key: key);

  @override
  ConsumerState<HashtaraApp> createState() => _HashtaraAppState();
}

class _HashtaraAppState extends ConsumerState<HashtaraApp> {
  @override
  void initState() {
    super.initState();
    
    // 앱 시작 시 로컬 저장소에서 회원가입 진행 상태 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedSignupProgress();
    });
  }
  
  // 저장된 회원가입 진행 상태 불러오기
  Future<void> _loadSavedSignupProgress() async {
    try {
      final savedState = await loadSignupProgress();
      if (savedState['userId'] != null) {
        // 저장된 상태가 있으면 메모리에 복원
        ref.read(signupProgressProvider.notifier).state = savedState['progress'];
        debugPrint('저장된 회원가입 상태 복원: ${savedState['progress']}, 사용자: ${savedState['userId']}');
      }
    } catch (e) {
      debugPrint('저장된 회원가입 상태 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 상태를 확인하는 프로바이더 사용
    final authState = ref.watch(authStateProvider);
    
    // 회원가입 진행 상태 확인
    final signupProgress = ref.watch(signupProgressProvider);
    
    // 디버그 로그 추가
    debugPrint('HashtaraApp 리빌드됨 - AuthState: ${authState.valueOrNull != null ? '로그인됨' : '로그인안됨'}, 진행상태: $signupProgress');
    
    // 스플래시 화면 후 authState와 signupProgress에 따라 화면 결정
    return CupertinoApp(
      title: 'Hashtara',
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
      home: authState.when(
        data: (user) {
          if (user == null) {
            debugPrint('사용자 로그인되지 않음, 로그인 화면으로 이동');
            return const SplashToLoginScreen();
          } else {
            debugPrint('✅ 로그인된 사용자 확인: ${user.uid}');
            
            // 유저 정보 명시적으로 로드
            ref.read(currentUserProvider);
            
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
                debugPrint('➡️ 메인 화면으로 이동');
                return const MainTabScreen();
            }
          }
        },
        loading: () {
          debugPrint('인증 상태 로딩 중...');
          return const SplashScreen();
        },
        error: (error, stack) {
          // 에러 로그 추가
          debugPrint('인증 상태 로드 에러: $error');
          return const SplashToLoginScreen();
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

// 스플래시 화면을 보여준 후 로그인 화면으로 자동 전환하는 위젯
class SplashToLoginScreen extends StatefulWidget {
  const SplashToLoginScreen({Key? key}) : super(key: key);

  @override
  State<SplashToLoginScreen> createState() => _SplashToLoginScreenState();
}

class _SplashToLoginScreenState extends State<SplashToLoginScreen> {
  bool _isNavigating = false; // 네비게이션 중복 방지 플래그

  @override
  void initState() {
    super.initState();
    // 2초 후 로그인 화면으로 전환 (한번만 실행되도록 플래그 사용)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isNavigating) {
        _isNavigating = true; // 네비게이션 시작 플래그 설정
        // 다음 프레임에서 네비게이션 실행
        Future.microtask(() {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              CupertinoPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}