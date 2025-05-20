import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../feed/main_tab_screen.dart';
import 'signup_screen.dart';
import '../auth/terms_agreement_screen.dart';
import '../profile/setup_profile_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;
  bool _navigationInProgress = false; // 중복 네비게이션 방지를 위한 플래그

  // 애니메이션 초기화 여부를 추적하는 플래그 추가
  bool _animationsInitialized = false;

  // 별똥별 애니메이션 컨트롤러들
  late List<AnimationController> _shootingStarControllers;
  late List<Animation<double>> _shootingStarPositions;
  late List<Offset> _shootingStarStarts;
  late List<Offset> _shootingStarEnds;

  // 반짝이는 별 애니메이션 컨트롤러들
  final List<AnimationController> _twinkelingStarControllers = [];
  final List<Animation<double>> _twinkelingStarAnimations = [];
  final List<Offset> _twinkelingStarPositions = [];
  final List<double> _twinkelingStarSizes = [];

  // 페이드인/아웃되는 별 애니메이션 컨트롤러
  final List<AnimationController> _fadingStarControllers = [];
  final List<Animation<double>> _fadingStarAnimations = [];
  final List<Offset> _fadingStarPositions = [];
  final List<double> _fadingStarSizes = [];
  final List<Color> _fadingStarColors = [];

  final _random = math.Random();

  @override
  void initState() {
    super.initState();

    // 기본 애니메이션 컨트롤러 초기화
    _shootingStarControllers = [];
    _shootingStarPositions = [];
    _shootingStarStarts = [];
    _shootingStarEnds = [];

    // initState에서 직접 네비게이션하지 않고 WidgetsBinding.instance.addPostFrameCallback 사용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
      _initializeAnimations();
    });
  }

  void _initializeAnimations() {
    if (_animationsInitialized) return;

    // 1. 별똥별 애니메이션 초기화 (빠르게 지나가는 유성)
    _shootingStarControllers = List.generate(
      3, // 별똥별 개수
      (index) => AnimationController(
        vsync: this,
        duration:
            Duration(milliseconds: 1000 + _random.nextInt(2000)), // 1-3초 랜덤
      ),
    );

    _shootingStarStarts = List.generate(
      _shootingStarControllers.length,
      (index) => Offset(
        _random.nextDouble() * 400, // 시작 X 위치
        _random.nextDouble() * 100, // 시작 Y 위치
      ),
    );

    _shootingStarEnds = List.generate(
      _shootingStarControllers.length,
      (index) => Offset(
        _shootingStarStarts[index].dx +
            100 +
            _random.nextDouble() * 200, // 끝 X 위치
        _shootingStarStarts[index].dy +
            200 +
            _random.nextDouble() * 300, // 끝 Y 위치
      ),
    );

    _shootingStarPositions = List.generate(
      _shootingStarControllers.length,
      (index) => CurvedAnimation(
        parent: _shootingStarControllers[index],
        curve: Curves.easeOutQuad,
      ),
    );

    // 별똥별 애니메이션 시작 (딜레이 적용)
    for (int i = 0; i < _shootingStarControllers.length; i++) {
      Future.delayed(
        Duration(seconds: 2 + i * 3 + _random.nextInt(5)), // 각각 다른 시간에 시작
        () {
          if (mounted) {
            _shootingStarControllers[i].forward().then((_) {
              if (mounted) {
                _shootingStarControllers[i].reset();
                // 애니메이션 반복
                Future.delayed(
                  Duration(seconds: 5 + _random.nextInt(10)),
                  () {
                    if (mounted) {
                      _shootingStarControllers[i].forward();
                    }
                  },
                );
              }
            });
          }
        },
      );
    }

    // 2. 반짝이는 별 애니메이션 초기화 (깜빡이는 별)
    _twinkelingStarControllers.clear();
    _twinkelingStarAnimations.clear();
    _twinkelingStarPositions.clear();
    _twinkelingStarSizes.clear();

    // 반짝이는 별 20개 생성
    for (int i = 0; i < 20; i++) {
      final controller = AnimationController(
        vsync: this,
        duration:
            Duration(milliseconds: 1000 + _random.nextInt(2000)), // 1-3초 랜덤
      );

      _twinkelingStarControllers.add(controller);

      _twinkelingStarAnimations.add(
        Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Curves.easeInOut,
          ),
        ),
      );

      _twinkelingStarPositions.add(
        Offset(
          _random.nextDouble() * 400, // X 위치
          _random.nextDouble() * 800, // Y 위치
        ),
      );

      _twinkelingStarSizes.add(1.0 + _random.nextDouble() * 3.0); // 크기 1-4 사이

      // 애니메이션 시작
      controller.repeat(reverse: true);
    }

    // 3. 페이드인/아웃되는 별 애니메이션 초기화 (등장했다 사라지는 별들)
    _fadingStarControllers.clear();
    _fadingStarAnimations.clear();
    _fadingStarPositions.clear();
    _fadingStarSizes.clear();
    _fadingStarColors.clear();

    // 페이드인/아웃되는 별 50개 생성
    for (int i = 0; i < 50; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(seconds: 3 + _random.nextInt(8)), // 3-10초 랜덤
      );

      final startDelay = _random.nextDouble(); // 시작 딜레이 (0-1)

      // 페이드인/아웃 애니메이션 시퀀스
      _fadingStarAnimations.add(
        TweenSequence<double>([
          // 페이드인
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 0.7)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 30.0,
          ),
          // 유지
          TweenSequenceItem(
            tween: ConstantTween<double>(0.7),
            weight: 40.0,
          ),
          // 페이드아웃
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.7, end: 0.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 30.0,
          ),
        ]).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              startDelay, // 시작 지연
              1.0,
              curve: Curves.linear,
            ),
          ),
        ),
      );

      _fadingStarControllers.add(controller);

      _fadingStarPositions.add(
        Offset(
          _random.nextDouble() * 400, // X 위치
          _random.nextDouble() * 800, // Y 위치
        ),
      );

      _fadingStarSizes
          .add(0.5 + _random.nextDouble() * 2.5); // 크기 0.5-3 사이 (작은 별들)

      // 별 색상 - 약간의 색상 변화 추가
      final hue = 200 + _random.nextInt(60); // 파란색/보라색 계열
      final saturation = 0.7 + _random.nextDouble() * 0.3; // 채도
      final value = 0.8 + _random.nextDouble() * 0.2; // 명도

      _fadingStarColors.add(
          HSVColor.fromAHSV(1.0, hue.toDouble(), saturation, value).toColor());

      // 애니메이션 반복 시작 (각기 다른 딜레이)
      Future.delayed(Duration(milliseconds: _random.nextInt(3000)), () {
        if (mounted) {
          controller.repeat();
        }
      });
    }

    _animationsInitialized = true;
  }

  void _checkLoginStatus() {
    // 이미 로그인되어 있는 상태인지 확인
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      if (user != null && mounted && !_navigationInProgress) {
        // 이미 로그인되어 있으면 피드 화면으로 이동
        debugPrint('로그인 상태 감지: ${user.uid}');
        _navigateToFeed();
      }
    });
  }

  // 네비게이션 중복 방지 함수
  void _navigateTo(Widget screen) {
    if (mounted && !_navigationInProgress) {
      setState(() {
        _navigationInProgress = true; // 네비게이션 시작 플래그 설정
      });

      // 다음 프레임에서 실행하도록 함
      Future.microtask(() {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (context) => screen),
            (route) => false, // 모든 이전 화면 제거
          );
        }
      });
    }
  }

  void _navigateToFeed() {
    _navigateTo(const MainTabScreen());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    // 애니메이션 컨트롤러 정리
    for (var controller in _shootingStarControllers) {
      controller.dispose();
    }
    for (var controller in _twinkelingStarControllers) {
      controller.dispose();
    }
    for (var controller in _fadingStarControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // 이메일/비밀번호 로그인
  Future<void> _handleEmailLogin() async {
    // 입력값 유효성 검사
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = '이메일과 비밀번호를 모두 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );

      // 로그인 성공 처리는 authStateProvider에 의해 자동으로 이루어짐
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '로그인에 실패했습니다: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 회원가입 진행 상태에 따라 적절한 화면으로 이동
  void _navigateBasedOnSignupProgress(String userId, SignupProgress progress) {
    if (!mounted) return;

    switch (progress) {
      case SignupProgress.registered:
        _navigateTo(TermsAgreementScreen(userId: userId));
        break;
      case SignupProgress.termsAgreed:
        _navigateTo(SetupProfileScreen(userId: userId));
        break;
      case SignupProgress.completed:
      case SignupProgress.none:
        _navigateToFeed();
        break;
    }
  }

  // 구글 로그인
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final result =
          await ref.read(authControllerProvider.notifier).signInWithGoogle();

      debugPrint("구글 로그인 성공!");

      if (result?.user != null) {
        // 인증 상태에 따라 적절한 화면으로 이동
        final signupProgress = ref.read(signupProgressProvider);
        _navigateBasedOnSignupProgress(result!.user!.uid, signupProgress);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '구글 로그인에 실패했습니다. 다시 시도해주세요. 오류: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  // 애플 로그인 (구현 필요)
  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isAppleLoading = true;
      _errorMessage = null;
    });

    try {
      // 애플 로그인 구현 필요
      await Future.delayed(const Duration(seconds: 1)); // 임시 지연

      if (mounted) {
        setState(() {
          _errorMessage = '애플 로그인이 아직 구현되지 않았습니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '애플 로그인에 실패했습니다.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  // 구글 로그인 버튼
  Widget _buildGoogleButton() {
    if (_isGoogleLoading) {
      return const CupertinoActivityIndicator();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞게 조정
      children: [
        // 구글 아이콘 - 이미지 사용 (텍스트와 수직 중앙 정렬)
        Padding(
          padding: const EdgeInsets.only(top: 3.0), // 아이콘을 아래로 조정
          child: Image.asset(
            'assets/icons/google_icon.png',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 12.0),
        const Flexible(
          child: Text(
            'Google로 계속하기',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis, // 텍스트가 넘칠 경우 ...으로 표시
          ),
        ),
      ],
    );
  }

  // 애플 로그인 버튼
  Widget _buildAppleButton() {
    if (_isAppleLoading) {
      return const CupertinoActivityIndicator();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞게 조정
      children: [
        // 애플 아이콘 - 이미지 사용 (텍스트와 수직 중앙 정렬)
        Padding(
          padding: const EdgeInsets.only(top: 3.0), // 아이콘을 아래로 조정
          child: Image.asset(
            'assets/icons/apple_icon.png',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 12.0),
        const Flexible(
          child: Text(
            'Apple로 계속하기',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis, // 텍스트가 넘칠 경우 ...으로 표시
          ),
        ),
      ],
    );
  }

  // 별똥별 그리기
  Widget _buildShootingStar(int index) {
    return AnimatedBuilder(
      animation: _shootingStarPositions[index],
      builder: (context, child) {
        final position = Offset.lerp(
          _shootingStarStarts[index],
          _shootingStarEnds[index],
          _shootingStarPositions[index].value,
        )!;

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Transform.rotate(
            angle: math.atan2(
              _shootingStarEnds[index].dy - _shootingStarStarts[index].dy,
              _shootingStarEnds[index].dx - _shootingStarStarts[index].dx,
            ),
            child: Container(
              width: 30,
              height: 2,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white30,
                    Colors.white70,
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white30,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 반짝이는 별 그리기
  Widget _buildTwinklingStar(int index) {
    return AnimatedBuilder(
      animation: _twinkelingStarAnimations[index],
      builder: (context, child) {
        return Positioned(
          left: _twinkelingStarPositions[index].dx,
          top: _twinkelingStarPositions[index].dy,
          child: Opacity(
            opacity: _twinkelingStarAnimations[index].value,
            child: Container(
              width: _twinkelingStarSizes[index],
              height: _twinkelingStarSizes[index],
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white54,
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 페이드인/아웃되는 별 그리기
  Widget _buildFadingStar(int index) {
    return AnimatedBuilder(
      animation: _fadingStarAnimations[index],
      builder: (context, child) {
        final opacity = _fadingStarAnimations[index].value;

        // 별이 보이지 않을 때는 렌더링 생략
        if (opacity <= 0.01) return const SizedBox();

        return Positioned(
          left: _fadingStarPositions[index].dx,
          top: _fadingStarPositions[index].dy,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: _fadingStarSizes[index],
              height: _fadingStarSizes[index],
              decoration: BoxDecoration(
                  color: _fadingStarColors[index],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // withOpacity 대신 withValues() 메서드 사용
                      color: _fadingStarColors[index].withValues(
                          red: _fadingStarColors[index].r,
                          green: _fadingStarColors[index].g,
                          blue: _fadingStarColors[index].b,
                          // alpha 값은 0-255 범위이므로 0.5 * 255 = 127.5 ≈ 128
                          alpha: 128),
                      blurRadius: _fadingStarSizes[index] * 2,
                      spreadRadius: _fadingStarSizes[index] * 0.2,
                    ),
                  ]),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보 가져오기
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // 애니메이션이 초기화되지 않았다면 초기화
    if (!_animationsInitialized) {
      _initializeAnimations();
    }

    // 현재 로그인 상태 감시
    final authState = ref.watch(authStateProvider);

    // 로그인 상태가 변경되면 상태 출력 및 화면 이동
    authState.whenData((user) {
      if (user != null && !_navigationInProgress) {
        debugPrint('로그인 상태 변경됨: ${user.uid}');
        // 비동기 작업으로 네비게이션 실행 (build 메서드 내에서 직접 네비게이션하지 않음)
        Future.microtask(() {
          if (mounted) {
            // microtask 내에서도 mounted 체크
            _navigateToFeed();
          }
        });
      }
    });

    // 디바이스 크기에 따른 패딩 및 크기 계산
    final horizontalPadding = screenSize.width * 0.06; // 화면 너비의 6%
    final buttonHeight = screenSize.height * 0.06; // 화면 높이의 6%
    final logoSize = screenSize.width * 0.45; // 화면 너비의 45%
    final verticalSpacing = screenSize.height * 0.02; // 화면 높이의 2%

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black, // 배경색은 검은색으로 설정
      child: Stack(
        children: [
          // 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/stars_background2.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 페이드인/아웃되는 별들
          if (_fadingStarPositions.isNotEmpty)
            ...List.generate(
              _fadingStarPositions.length,
              (index) => _buildFadingStar(index),
            ),

          // 반짝이는 별들 (리스트가 비어있지 않을 때만 렌더링)
          if (_twinkelingStarPositions.isNotEmpty)
            ...List.generate(
              _twinkelingStarPositions.length,
              (index) => _buildTwinklingStar(index),
            ),

          // 별똥별 효과 (리스트가 비어있지 않을 때만 렌더링)
          if (_shootingStarStarts.isNotEmpty)
            ...List.generate(
              _shootingStarStarts.length,
              (index) => _buildShootingStar(index),
            ),

          // 메인 컨텐츠
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenSize.height -
                        mediaQuery.padding.top -
                        mediaQuery.padding.bottom,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: verticalSpacing * 2),

                      // 요청하신 대로 logo2.png 사용
                      Center(
                        child: Column(
                          children: [
                            // 로고 이미지
                            Container(
                              width: logoSize,
                              height: logoSize,
                              decoration: BoxDecoration(
                                color:
                                    CupertinoColors.transparent, // 투명 배경으로 변경
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Image.asset(
                                'assets/images/logo2.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: verticalSpacing * 2),

                      // 이메일 입력 필드
                      CupertinoTextField(
                        controller: _emailController,
                        placeholder: '이메일',
                        keyboardType: TextInputType.emailAddress,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 15),
                          child: Icon(
                            CupertinoIcons.mail,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground
                              .withAlpha(204), // 배경색 반투명으로 설정
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.separator),
                        ),
                        style: const TextStyle(color: AppColors.white),
                        placeholderStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        enabled: !_isLoading &&
                            !_isGoogleLoading &&
                            !_isAppleLoading,
                      ),

                      SizedBox(height: verticalSpacing),

                      // 비밀번호 입력 필드
                      CupertinoTextField(
                        controller: _passwordController,
                        placeholder: '비밀번호',
                        obscureText: true,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 15),
                          child: Icon(
                            CupertinoIcons.lock,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground
                              .withAlpha(204), // 배경색 반투명으로 설정
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.separator),
                        ),
                        style: const TextStyle(color: AppColors.white),
                        placeholderStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        enabled: !_isLoading &&
                            !_isGoogleLoading &&
                            !_isAppleLoading,
                      ),

                      // 비밀번호 찾기 링크
                      Align(
                        alignment: Alignment.centerRight,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            // 비밀번호 찾기 화면으로 이동
                          },
                          child: const Text(
                            '비밀번호 찾기',
                            style: TextStyle(
                              color: AppColors.primaryPurple,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: verticalSpacing),

                      // 로그인 버튼
                      SizedBox(
                        height: buttonHeight,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed:
                              _isLoading || _isGoogleLoading || _isAppleLoading
                                  ? null
                                  : _handleEmailLogin,
                          color: AppColors.primaryPurple,
                          borderRadius: BorderRadius.circular(12),
                          child: _isLoading
                              ? const CupertinoActivityIndicator(
                                  color: AppColors.white)
                              : const Text(
                                  '로그인하기', // 텍스트 추가
                                  style: TextStyle(
                                    color: AppColors.white, // 텍스트 색상 추가
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: verticalSpacing * 1.5),

                      // 소셜 로그인 구분선
                      const Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 1,
                              child: DecoratedBox(
                                decoration:
                                    BoxDecoration(color: AppColors.separator),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '또는',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 1,
                              child: DecoratedBox(
                                decoration:
                                    BoxDecoration(color: AppColors.separator),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: verticalSpacing * 1.5),

                      // 소셜 로그인 버튼들
                      // 구글 로그인 버튼
                      Container(
                        margin: EdgeInsets.only(bottom: verticalSpacing),
                        height: buttonHeight,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: AppColors.cardBackground
                              .withAlpha(204), // 반투명으로 설정
                          borderRadius: BorderRadius.circular(12),
                          onPressed: (_isLoading || _isAppleLoading)
                              ? null
                              : _handleGoogleSignIn,
                          child: Center(child: _buildGoogleButton()),
                        ),
                      ),

                      // 애플 로그인 버튼
                      Container(
                        margin: EdgeInsets.only(bottom: verticalSpacing),
                        height: buttonHeight,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: AppColors.cardBackground
                              .withAlpha(204), // 반투명으로 설정
                          borderRadius: BorderRadius.circular(12),
                          onPressed: (_isLoading || _isGoogleLoading)
                              ? null
                              : _handleAppleSignIn,
                          child: Center(child: _buildAppleButton()),
                        ),
                      ),

                      SizedBox(height: verticalSpacing),

                      // 회원가입 링크
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '계정이 없으신가요?',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(left: 4),
                            onPressed: () {
                              // 회원가입 화면으로 이동하는 코드 (추가 필요)
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => const SignupScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              '가입하기',
                              style: TextStyle(
                                color: AppColors.primaryPurple,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 에러 메시지
                      if (_errorMessage != null)
                        Padding(
                          padding: EdgeInsets.only(top: verticalSpacing),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemRed.withAlpha(102),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: CupertinoColors.systemRed,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      SizedBox(height: verticalSpacing * 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Flutter에서 사용할 Colors 클래스 추가
class Colors {
  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color white30 = Color(0x4DFFFFFF);
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color white70 = Color(0xB2FFFFFF);
}
