import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import '../../../constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _starsController;
  late Animation<double> _fadeAnimation;
  
  // 별 애니메이션을 위한 리스트
  final List<StarData> _stars = [];
  final math.Random _random = math.Random();
  
  @override
  void initState() {
    super.initState();
    
    // 메인 페이드 애니메이션 컨트롤러
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    
    // 별 애니메이션 컨트롤러
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    
    // 페이드인/아웃 애니메이션 시퀀스
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30.0,
      ),
    ]).animate(_fadeController);
    
    // 별 생성
    _generateStars();
    
    // 애니메이션 시작
    _fadeController.forward();
    _starsController.repeat(reverse: true);
  }
  
  // 랜덤 별 생성 함수
  void _generateStars() {
    for (int i = 0; i < 50; i++) {
      _stars.add(
        StarData(
          x: _random.nextDouble() * 1.0,
          y: _random.nextDouble() * 1.0,
          size: 1.0 + _random.nextDouble() * 3.0,
          opacity: 0.3 + _random.nextDouble() * 0.7,
          blinkDelay: _random.nextDouble(),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          // 배경 그라데이션
          AnimatedBuilder(
            animation: _starsController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1A4A),
                      const Color(0xFF0A0A1A),
                      Color.fromRGBO(17, 17, 65, 0.7 + 0.3 * _starsController.value),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    transform: GradientRotation(_starsController.value * math.pi / 8),
                  ),
                ),
              );
            },
          ),
          
          // 별 배경 이미지 (페이드 효과)
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/stars_background.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // 반짝이는 별들
          ...List.generate(_stars.length, (index) {
            return AnimatedBuilder(
              animation: _starsController,
              builder: (context, child) {
                final sinValue = math.sin((_starsController.value + _stars[index].blinkDelay) * 2 * math.pi);
                final starOpacity = (_stars[index].opacity * 0.5) + (_stars[index].opacity * 0.5 * sinValue);
                
                return Positioned(
                  left: screenSize.width * _stars[index].x,
                  top: screenSize.height * _stars[index].y,
                  child: Opacity(
                    opacity: starOpacity,
                    child: Container(
                      width: _stars[index].size,
                      height: _stars[index].size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(255, 255, 255, starOpacity * 0.5),
                            blurRadius: _stars[index].size * 2,
                            spreadRadius: _stars[index].size * 0.2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          
          // 로딩 인디케이터
          Center(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: const CupertinoActivityIndicator(
                    radius: 16,
                    color: AppColors.white,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 별 데이터 클래스
class StarData {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double blinkDelay;
  
  StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.blinkDelay,
  });
}

// 색상 클래스
class Colors {
  static const Color white = Color(0xFFFFFFFF);
}