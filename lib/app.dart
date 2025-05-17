import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 지역화 패키지만 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants/app_colors.dart';
import 'views/common/splash_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/profile/setup_profile_screen.dart';
import 'views/feed/main_tab_screen.dart';
import 'providers/auth_provider.dart';

// 초기 라우팅 상태를 관리하는 프로바이더
final initialRouteProvider = StateProvider<String>((ref) => 'splash');

class HashtaraApp extends ConsumerWidget {
  const HashtaraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 로그인 상태를 확인하는 프로바이더 사용
    final authState = ref.watch(authStateProvider);
    
    // 디버그 로그 추가
    debugPrint('HashtaraApp 리빌드됨 - AuthState: ${authState.valueOrNull != null ? '로그인됨' : '로그인안됨'}');
    
    // 스플래시 화면 후 authState에 따라 화면 결정
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
        // 리스트에 const 추가 (패키지 import 이후 상수로 사용 가능)
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
            
            // 로그인된 경우 프로필 완료 상태 확인
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, snapshot) {
                // 로딩 중
                if (snapshot.connectionState == ConnectionState.waiting) {
                  debugPrint('문서 로딩 중...');
                  return const SplashScreen();
                }
                
                // 오류 발생 시 로그인 화면으로
                if (snapshot.hasError) {
                  debugPrint('❌ 사용자 문서 로드 오류: ${snapshot.error}');
                  return const SplashToLoginScreen();
                }
                
                // 사용자 문서 확인
                debugPrint('문서 스냅샷: ${snapshot.hasData}, 문서 존재: ${snapshot.data?.exists}');
                
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  
                  // 명시적으로 profileComplete 필드 값을 확인하고 로그 출력
                  final profileComplete = userData?['profileComplete'];
                  debugPrint('🔍 profileComplete 필드 값: $profileComplete (${profileComplete.runtimeType})');
                  
                  final bool isProfileComplete = profileComplete == true;
                  
                  debugPrint('📋 사용자 문서: $userData');
                  debugPrint('🔍 프로필 설정 완료 여부: $isProfileComplete');
                  
                  if (!isProfileComplete) {
                    debugPrint('➡️ 프로필 설정 필요: ${user.uid}, SetupProfileScreen으로 이동');
                    return SetupProfileScreen(userId: user.uid);
                  } else {
                    debugPrint('➡️ 메인 화면으로 이동');
                    return const MainTabScreen();
                  }
                } else {
                  debugPrint('❓ 사용자 문서 없음: ${user.uid}, 프로필 설정 화면으로 이동');
                  return SetupProfileScreen(userId: user.uid);
                }
              },
            );
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
    // 3초 후 로그인 화면으로 전환 (한번만 실행되도록 플래그 사용)
    Future.delayed(const Duration(seconds: 3), () {
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