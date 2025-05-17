import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../profile/setup_profile_screen.dart';

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
  bool _navigationInProgress = false; // 중복 네비게이션 방지 플래그
  
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

    // 비밀번호 검증 (6자 이상)
    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = '비밀번호는 6자 이상이어야 합니다.';
      });
      return;
    }
    
    // 이메일 형식 검증
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
      // 회원가입 실행
      final user = await ref.read(authControllerProvider.notifier).signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      // 회원가입 성공 시 즉시 프로필 설정 화면으로 이동
      if (user != null && mounted) {
        // 네비게이션 중복 방지 플래그 설정
        setState(() {
          _navigationInProgress = true;
        });
        
        debugPrint('회원가입 성공, 프로필 설정 화면으로 즉시 이동: ${user.uid}');
        
        // 화면 스택을 완전히 지우고 프로필 설정 화면으로 강제 이동
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(
            builder: (context) => SetupProfileScreen(
              userId: user.uid,
            ),
          ),
          (route) => false, // 모든 이전 화면 제거
        );
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
          _errorMessage = '회원가입에 실패했습니다: ${e.toString()}';
          _isLoading = false;
          _navigationInProgress = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보 가져오기
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    
    // 디바이스 크기에 따른 패딩 및 크기 계산
    final horizontalPadding = screenSize.width * 0.06; // 화면 너비의 6%
    final buttonHeight = screenSize.height * 0.06; // 화면 높이의 6%
    final verticalSpacing = screenSize.height * 0.02; // 화면 높이의 2%
    final logoSize = screenSize.width * 0.4; // 화면 너비의 40%
    
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
              
              // 로고 추가
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
                    ? const CupertinoActivityIndicator(color: AppColors.white)
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
                      color: CupertinoColors.systemRed.withOpacity(0.1),
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
                      Navigator.pop(context);
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