import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../feed/main_tab_screen.dart';

class SetupProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  
  const SetupProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _navigationInProgress = false; // 중복 네비게이션 방지 플래그 추가
  
  // 필드 오류 상태 추적 변수 추가
  bool _nameError = false;
  bool _usernameError = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('SetupProfileScreen 초기화됨: ${widget.userId}');
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
  
  // 피드 화면으로 이동하는 메서드
  void _navigateToFeed() {
    if (mounted && !_navigationInProgress) {
      setState(() {
        _navigationInProgress = true; // 네비게이션 시작 플래그 설정
      });
      
      debugPrint('피드 화면으로 이동 시작');
      // 즉시 네비게이션 실행 (Future.microtask 사용하지 않음)
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (context) => const MainTabScreen()),
        (route) => false, // 이전 화면들 모두 제거
      );
    }
  }
  
  // 사용자명 유효성 검사 (영문, 숫자, 언더스코어만 허용)
  bool _isValidUsername(String username) {
    // 공백 없이 영문, 숫자, 언더스코어만 허용
    final validUsernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    return validUsernameRegex.hasMatch(username);
  }
  
  Future<void> _saveProfile() async {
    // 필드 오류 상태 초기화
    setState(() {
      _nameError = false;
      _usernameError = false;
      _errorMessage = null;
    });
    
    // 필수 필드 검증
    if (_nameController.text.isEmpty) {
      setState(() {
        _nameError = true;
        _errorMessage = '이름은 필수입니다.';
      });
      return;
    }
    
    if (_usernameController.text.isEmpty) {
      setState(() {
        _usernameError = true;
        _errorMessage = '사용자명은 필수입니다.';
      });
      return;
    }
    
    // 사용자명 형식 검증
    if (!_isValidUsername(_usernameController.text)) {
      setState(() {
        _usernameError = true;
        _errorMessage = '사용자명은 영문, 숫자, 언더스코어(_)만 사용할 수 있습니다.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      debugPrint('프로필 저장 시도: ${widget.userId}');
      
      // 사용자 문서 생성 - profileComplete 필드가 true로 설정됨
      await ref.read(authRepositoryProvider).createUserDocument(
        widget.userId,
        _nameController.text.trim(),
        _usernameController.text.trim(),
        null, // 프로필 이미지는 나중에 수정 가능
      );
      
      // 프로필 문서 생성
      await ref.read(profileRepositoryProvider).createProfileDocument(
        widget.userId,
        _bioController.text.trim(),
      );
      
      // Firestore에 프로필 완료 상태 명시적 업데이트
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'profileComplete': true, // 프로필 설정이 완료되었음을 명시적으로 표시
      });
      
      debugPrint('프로필 저장 성공, 피드로 이동');
      
      // 성공 시 피드 화면으로 이동
      if (mounted) {
        _navigateToFeed();
      }
    } catch (e) {
      debugPrint('프로필 저장 실패: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '프로필 설정에 실패했습니다. 다시 시도해주세요. 오류: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  // 건너뛰기 확인 다이얼로그 표시
  void _showSkipConfirmationDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('프로필 설정 건너뛰기'),
          content: const Text('프로필 설정은 나중에 할 수 있습니다. 지금 건너뛰시겠습니까?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('취소'),
              onPressed: () {
                Navigator.pop(dialogContext);
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(dialogContext);
                _skipProfile();
              },
              child: const Text('건너뛰기'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _skipProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      debugPrint('프로필 건너뛰기: ${widget.userId}');
      
      // 기본 이름과 사용자명 설정
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6, 10);
      final defaultUsername = 'user_$timestamp';
      
      // 1. 사용자 문서 생성
      await ref.read(authRepositoryProvider).createUserDocument(
        widget.userId,
        'User', // 기본 이름
        defaultUsername, // 고유한 사용자명 생성
        null,
      );
      
      // 2. 프로필 문서 생성
      await ref.read(profileRepositoryProvider).createProfileDocument(
        widget.userId,
        '프로필이 아직 설정되지 않았습니다.', // 기본 소개
      );
      
      // 3. 프로필 완료 상태 명시적 업데이트
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'profileComplete': true, // 건너뛰기해도 완료된 것으로 처리
      });
      
      debugPrint('기본 프로필 생성 성공, 피드로 이동');
      
      // 성공 시 피드 화면으로 이동
      if (mounted) {
        _navigateToFeed();
      }
    } catch (e) {
      debugPrint('기본 프로필 생성 실패: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '기본 프로필 설정에 실패했습니다. 오류: $e';
          _isLoading = false;
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
    final circleSize = screenSize.width * 0.25; // 프로필 이미지 원 크기
    
    return PopScope(
      // 뒤로가기 방지
      canPop: false,
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.darkBackground,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: AppColors.primaryPurple,
          middle: Text(
            AppStrings.setupProfile,
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          // 뒤로가기 버튼 제거
          automaticallyImplyLeading: false,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: verticalSpacing),
                
                const Text(
                  AppStrings.profileSetupDesc,
                  style: TextStyle(
                    color: AppColors.textEmphasis, 
                    fontSize: 16.0
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: verticalSpacing * 2),
                
                // 프로필 이미지 선택 (단순화 - 기본 아이콘만 표시)
                Center(
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.separator,
                        width: 2.0,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.person_fill,
                      size: 60,
                      color: AppColors.textEmphasis,
                    ),
                  ),
                ),
                
                SizedBox(height: verticalSpacing * 1.5),
                
                // 이름 (필수)
                Row(
                  children: [
                    const Text(
                      '이름',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textEmphasis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '(필수)',
                      style: TextStyle(
                        fontSize: 13,
                        color: _nameError ? CupertinoColors.systemRed : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: verticalSpacing / 2),
                
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: '이름을 입력하세요',
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _nameError ? CupertinoColors.systemRed : AppColors.separator,
                    ),
                  ),
                  style: const TextStyle(color: AppColors.white),
                  placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                  enabled: !_isLoading,
                  onChanged: (value) {
                    // 입력 시 오류 상태 초기화
                    if (_nameError && value.isNotEmpty) {
                      setState(() {
                        _nameError = false;
                      });
                    }
                  },
                ),
                
                SizedBox(height: verticalSpacing),
                
                // 사용자명 (필수)
                Row(
                  children: [
                    const Text(
                      '사용자명',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textEmphasis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '(필수)',
                      style: TextStyle(
                        fontSize: 13,
                        color: _usernameError ? CupertinoColors.systemRed : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: verticalSpacing / 2),
                
                CupertinoTextField(
                  controller: _usernameController,
                  placeholder: '사용자명을 입력하세요 (예: user123)',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      '@',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _usernameError ? CupertinoColors.systemRed : AppColors.separator,
                    ),
                  ),
                  style: const TextStyle(color: AppColors.white),
                  placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                  enabled: !_isLoading,
                  onChanged: (value) {
                    // 입력 시 오류 상태 초기화
                    if (_usernameError && value.isNotEmpty) {
                      setState(() {
                        _usernameError = false;
                      });
                    }
                  },
                ),
                
                // 사용자명 안내 메시지
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                  child: Text(
                    '영문, 숫자, 언더스코어(_)만 사용 가능합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _usernameError ? CupertinoColors.systemRed : AppColors.textSecondary,
                    ),
                  ),
                ),
                
                SizedBox(height: verticalSpacing),
                
                // 소개 (선택 사항)
                const Text(
                  '소개 (선택)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textEmphasis,
                  ),
                ),
                
                SizedBox(height: verticalSpacing / 2),
                
                CupertinoTextField(
                  controller: _bioController,
                  placeholder: '자신을 소개해보세요',
                  maxLines: 3,
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
                
                // 저장 버튼
                SizedBox(
                  height: buttonHeight,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading
                      ? const CupertinoActivityIndicator(color: AppColors.white)
                      : const Text(
                          AppStrings.saveProfile,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16, 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                  ),
                ),
                
                SizedBox(height: verticalSpacing),
                
                // 건너뛰기 버튼
                if (!_isLoading)
                  Center(
                    child: CupertinoButton(
                      onPressed: _showSkipConfirmationDialog,
                      child: const Text(
                        AppStrings.skip,
                        style: TextStyle(
                          color: AppColors.textEmphasis,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                
                // 에러 메시지
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: verticalSpacing),
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
                
                SizedBox(height: verticalSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}