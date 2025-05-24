import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // 🔥 kIsWeb 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../auth/terms_agreement_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _navigationInProgress = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('SignupScreen 초기화됨');
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  // 🔥 웹 안전한 네비게이션 함수
  Future<void> _safeNavigate(Widget destination) async {
    if (!mounted || _navigationInProgress) return;
    
    setState(() {
      _navigationInProgress = true;
    });
    
    try {
      if (kIsWeb) {
        // 🌐 웹에서는 더 안전한 방식으로 네비게이션
        debugPrint('🌐 웹: 안전한 네비게이션 시작');
        
        // 약간의 지연을 두고 실행
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted && context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (context) => destination),
            (route) => false,
          );
        }
      } else {
        // 📱 모바일에서는 기존 방식
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (context) => destination),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('네비게이션 오류: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '화면 이동 중 오류가 발생했습니다.';
          _navigationInProgress = false;
        });
      }
    }
  }
  
  Future<void> _handleSignup() async {
    // 입력 유효성 검사
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = '모든 필드를 입력해주세요.';
      });
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = '비밀번호가 일치하지 않습니다.';
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = '비밀번호는 6자 이상이어야 합니다.';
      });
      return;
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text)) {
      setState(() {
        _errorMessage = '유효한 이메일 주소를 입력해주세요.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      debugPrint('🔥 회원가입 시도: ${_emailController.text}');
      
      // 🔥 웹에서 안전한 회원가입 처리
      final user = await ref.read(authControllerProvider.notifier).signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (user != null && mounted) {
        debugPrint('회원가입 성공, 약관 동의 화면으로 즉시 이동: ${user.uid}');
        
        // 회원가입 상태 설정
        ref.read(signupProgressProvider.notifier).state = SignupProgress.registered;
        
        // 🔥 웹 안전한 네비게이션 사용
        await _safeNavigate(TermsAgreementScreen(userId: user.uid));
        
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = '회원가입 중 오류가 발생했습니다. 다시 시도해주세요.';
            _isLoading = false;
            _navigationInProgress = false;
          });
        }
      }
    } catch (e) {
      debugPrint('회원가입 예외 발생: $e');
      if (mounted) {
        setState(() {
          // 🌐 웹에서 더 사용자 친화적인 오류 메시지
          if (kIsWeb) {
            if (e.toString().contains('email-already-in-use')) {
              _errorMessage = '이미 사용 중인 이메일 주소입니다.';
            } else if (e.toString().contains('weak-password')) {
              _errorMessage = '비밀번호가 너무 약합니다. 더 강한 비밀번호를 사용해주세요.';
            } else if (e.toString().contains('invalid-email')) {
              _errorMessage = '유효하지 않은 이메일 주소입니다.';
            } else {
              _errorMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
            }
          } else {
            _errorMessage = '회원가입에 실패했습니다: ${e.toString()}';
          }
          _isLoading = false;
          _navigationInProgress = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    
    final horizontalPadding = screenSize.width * 0.06;
    final buttonHeight = screenSize.height * 0.06;
    final verticalSpacing = screenSize.height * 0.02;
    final logoSize = screenSize.width * 0.4;
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        middle: Text(
          AppStrings.signup,
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: verticalSpacing),
              
              // 로고
              Center(
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: CupertinoColors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/logo2.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              SizedBox(height: verticalSpacing * 1.5),
              
              // 이메일 입력
              const Text(
                '이메일',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textEmphasis,
                ),
              ),
              SizedBox(height: verticalSpacing / 2),
              
              CupertinoTextField(
                controller: _emailController,
                placeholder: AppStrings.email,
                keyboardType: TextInputType.emailAddress,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 15),
                  child: Icon(
                    CupertinoIcons.mail,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.separator),
                ),
                style: const TextStyle(color: AppColors.white),
                placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                enabled: !_isLoading,
              ),
              
              SizedBox(height: verticalSpacing),
              
              // 비밀번호 입력
              const Text(
                '비밀번호',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textEmphasis,
                ),
              ),
              SizedBox(height: verticalSpacing / 2),
              
              CupertinoTextField(
                controller: _passwordController,
                placeholder: AppStrings.password,
                obscureText: true,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 15),
                  child: Icon(
                    CupertinoIcons.lock,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.separator),
                ),
                style: const TextStyle(color: AppColors.white),
                placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                enabled: !_isLoading,
              ),
              
              SizedBox(height: verticalSpacing),
              
              // 비밀번호 확인 입력
              const Text(
                '비밀번호 확인',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textEmphasis,
                ),
              ),
              SizedBox(height: verticalSpacing / 2),
              
              CupertinoTextField(
                controller: _confirmPasswordController,
                placeholder: '비밀번호 확인',
                obscureText: true,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 15),
                  child: Icon(
                    CupertinoIcons.lock,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.separator),
                ),
                style: const TextStyle(color: AppColors.white),
                placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                enabled: !_isLoading,
              ),
              
              SizedBox(height: verticalSpacing * 2),
              
              // 회원가입 버튼
              SizedBox(
                height: buttonHeight,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _isLoading || _navigationInProgress ? null : _handleSignup,
                  child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoActivityIndicator(color: AppColors.white),
                          SizedBox(width: 8),
                          Text(
                            kIsWeb ? '가입 중...' : '처리 중...',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        AppStrings.signup,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                ),
              ),
              
              SizedBox(height: verticalSpacing),
              
              // 에러 메시지
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed.withAlpha(30),
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
              
              // 로그인 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    AppStrings.alreadyHaveAccount,
                    style: TextStyle(
                      color: AppColors.textEmphasis,
                      fontSize: 14,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 4),
                    onPressed: _navigationInProgress ? null : () {
                      if (kIsWeb) {
                        // 🌐 웹에서 안전한 뒤로가기
                        if (mounted && context.mounted) {
                          Navigator.pop(context);
                        }
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      AppStrings.login,
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: verticalSpacing),
            ],
          ),
        ),
      ),
    );
  }
}