// setup_profile_screen.dart - 수정본

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:hashtara/constants/app_colors.dart';
import 'package:hashtara/providers/auth_provider.dart';
import 'package:hashtara/providers/profile_provider.dart';
import 'package:hashtara/views/feed/main_tab_screen.dart';

// 프로필 설정 상태를 위한 프로바이더
final profileSetupStateProvider = StateNotifierProvider<ProfileSetupNotifier, ProfileSetupState>((ref) {
  return ProfileSetupNotifier();
});

// 프로필 설정 상태 클래스
class ProfileSetupState {
  final bool isCompleting;
  final bool isSkipping;
  final String? errorMessage;

  ProfileSetupState({
    this.isCompleting = false,
    this.isSkipping = false,
    this.errorMessage,
  });

  ProfileSetupState copyWith({
    bool? isCompleting,
    bool? isSkipping,
    String? errorMessage,
  }) {
    return ProfileSetupState(
      isCompleting: isCompleting ?? this.isCompleting,
      isSkipping: isSkipping ?? this.isSkipping,
      errorMessage: errorMessage,
    );
  }
}

// 프로필 설정 상태 노티파이어
class ProfileSetupNotifier extends StateNotifier<ProfileSetupState> {
  ProfileSetupNotifier() : super(ProfileSetupState());

  void startProfileCompletion() {
    state = state.copyWith(isCompleting: true, errorMessage: null);
  }

  void startSkipping() {
    state = state.copyWith(isSkipping: true, errorMessage: null);
  }

  void setError(String message) {
    state = state.copyWith(isCompleting: false, isSkipping: false, errorMessage: message);
  }

  void completeProfileSetup() {
    state = state.copyWith(isCompleting: true, errorMessage: null);
  }

  void skipProfileSetup() {
    state = state.copyWith(isSkipping: true, errorMessage: null);
  }

  void reset() {
    state = ProfileSetupState();
  }
}

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
  
  // 이미지 피커 관련 변수
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  
  bool _nameError = false;
  bool _usernameError = false;
  bool _isSelectingImage = false;
  bool _isNavigating = false; // 네비게이션 중복 방지 플래그

  // 최대 글자 수 제한
  final int _maxNameLength = 13;
  final int _maxUsernameLength = 13;

  @override
  void initState() {
    super.initState();
    debugPrint('SetupProfileScreen 초기화됨: ${widget.userId}');
    
    // Android에서 앱이 백그라운드로 이동했다가 돌아왔을 때 데이터 복구
    if (Platform.isAndroid) {
      _retrieveLostData();
    }
  }
  
  // 이미지 선택 데이터 복구
  Future<void> _retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) {
      return;
    }
    if (response.file != null) {
      setState(() {
        _profileImage = File(response.file!.path);
      });
    } else {
      debugPrint('이미지 데이터 손실 에러: ${response.exception}');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  bool _isValidUsername(String username) {
    final validUsernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    return validUsernameRegex.hasMatch(username);
  }
  
  // 갤러리에서 이미지 선택
  Future<void> _pickImageFromGallery() async {
    setState(() {
      _isSelectingImage = true;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('갤러리 이미지 선택 오류: $e');
      if (mounted) {
        ref.read(profileSetupStateProvider.notifier).setError('이미지 선택 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingImage = false;
        });
      }
    }
  }

  // 카메라로 이미지 촬영
  Future<void> _pickImageFromCamera() async {
    setState(() {
      _isSelectingImage = true;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('카메라 이미지 촬영 오류: $e');
      if (mounted) {
        ref.read(profileSetupStateProvider.notifier).setError('카메라 사용 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingImage = false;
        });
      }
    }
  }

  // 이미지 선택 옵션 표시
  void _showImageSourceActionSheet() {
    if (_isSelectingImage) return;
    
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('프로필 이미지 선택'),
          message: const Text('프로필 이미지를 선택하세요'),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
              child: const Text('갤러리에서 선택'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
              child: const Text('카메라로 촬영'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
        );
      },
    );
  }

  // 프로필 저장 메소드 - 수정된 부분
  Future<void> _saveProfile() async {
    if (_isNavigating) return; // 네비게이션 중복 방지
    
    setState(() {
      _nameError = false;
      _usernameError = false;
    });

    if (_nameController.text.isEmpty) {
      setState(() => _nameError = true);
      ref.read(profileSetupStateProvider.notifier).setError('이름은 필수입니다.');
      return;
    }
    if (_usernameController.text.isEmpty) {
      setState(() => _usernameError = true);
      ref.read(profileSetupStateProvider.notifier).setError('사용자명은 필수입니다.');
      return;
    }
    if (!_isValidUsername(_usernameController.text)) {
      setState(() => _usernameError = true);
      ref.read(profileSetupStateProvider.notifier).setError('사용자명은 영문, 숫자, 언더스코어(_)만 사용할 수 있습니다.');
      return;
    }

    // 상태 관리자 참조를 로컬 변수에 저장
    final profileSetupNotifier = ref.read(profileSetupStateProvider.notifier);
    final authRepository = ref.read(authRepositoryProvider);
    final profileRepository = ref.read(profileRepositoryProvider);
    final authController = ref.read(authControllerProvider.notifier);

    // 진행 상태 설정
    profileSetupNotifier.startProfileCompletion();
    
    // 네비게이션 플래그 설정
    setState(() {
      _isNavigating = true;
    });

    try {
      debugPrint('프로필 저장 시도: ${widget.userId}');
      
      // 이미지 업로드
      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await profileRepository.uploadProfileImage(
          widget.userId,
          _profileImage!,
        );
      }

      // 중요: 모든 데이터 저장 작업을 먼저 수행합니다
      await authRepository.createUserDocument(
        widget.userId,
        _nameController.text.trim(),
        _usernameController.text.trim(),
        profileImageUrl,
      );
          
      // 프로필 문서 생성 (소개 정보만 포함)
      await profileRepository.createProfileDocument(
        widget.userId,
        _bioController.text.trim(),
      );
      
      // 중요 변경: 위젯 마운트 상태와 상관없이 프로필 완료 처리를 먼저 실행
      // 이 작업은 백그라운드에서도 계속 진행되어야 함
      await authController.completeProfileSetup(widget.userId);
      
      // 이 시점에서 위젯이 여전히 마운트 상태인지 확인
      if (!mounted) {
        debugPrint('위젯이 더 이상 마운트되지 않음 - 저장은 완료됨, UI 업데이트 중단');
        return; // UI 업데이트는 중단하지만 프로필 설정은 이미 완료됨
      }
      
      debugPrint('프로필 저장 성공, 피드로 이동');
      
      // UI 상태 업데이트
      profileSetupNotifier.completeProfileSetup();
      
      // 메인 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (context) => const MainTabScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('프로필 저장 실패: $e');
      
      // 위젯이 여전히 유효한지 확인 후 오류 메시지 표시
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
        profileSetupNotifier.setError('프로필 설정에 실패했습니다. 다시 시도해주세요. 오류: $e');
      }
    }
  }

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
              onPressed: () => Navigator.pop(dialogContext)
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

  // 프로필 설정 건너뛰기 - 수정됨
  Future<void> _skipProfile() async {
    if (_isNavigating) return; // 네비게이션 중복 방지
    
    // 상태 관리자 참조를 로컬 변수에 저장
    final profileSetupNotifier = ref.read(profileSetupStateProvider.notifier);
    final authRepository = ref.read(authRepositoryProvider);
    final profileRepository = ref.read(profileRepositoryProvider);
    final authController = ref.read(authControllerProvider.notifier);
    
    setState(() {
      _isNavigating = true;
    });
    
    profileSetupNotifier.startSkipping();
    
    try {
      debugPrint('프로필 건너뛰기: ${widget.userId}');
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6, 10);
      final defaultUsername = 'user_$timestamp';
      
      // 중요: 프로필 데이터 저장 및 완료 처리
      await authRepository.createUserDocument(
        widget.userId, 
        'User', 
        defaultUsername, 
        null
      );
      
      await profileRepository.createProfileDocument(
        widget.userId, 
        '프로필이 아직 설정되지 않았습니다.'
      );
      
      // 중요 변경: 위젯 마운트 상태와 상관없이 프로필 완료 처리를 먼저 실행
      await authController.completeProfileSetup(widget.userId);
      
      // 위젯 유효성 확인은 UI 관련 작업에만 영향을 줌
      if (!mounted) {
        debugPrint('위젯이 더 이상 마운트되지 않음 - 건너뛰기 처리는 완료됨, UI 업데이트 중단');
        return;
      }
      
      debugPrint('기본 프로필 생성 성공, 피드로 이동');
      
      // UI 업데이트
      profileSetupNotifier.skipProfileSetup();
      
      // 메인 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (context) => const MainTabScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('기본 프로필 생성 실패: $e');
      
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
        profileSetupNotifier.setError('기본 프로필 설정에 실패했습니다. 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const buttonHeight = 52.0;
    const circleSize = 120.0;

    final profileSetupState = ref.watch(profileSetupStateProvider);

    // 상태 변경 감지 및 화면 전환 처리 - 수정됨
    ref.listen<ProfileSetupState>(profileSetupStateProvider, (previous, next) {
      if (mounted && (next.isCompleting || next.isSkipping) && next.errorMessage == null && !_isNavigating) {
        setState(() {
          _isNavigating = true;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(builder: (context) => const MainTabScreen()),
              (route) => false,
            );
            ref.read(profileSetupStateProvider.notifier).reset();
          }
        });
      }
    });

    return PopScope(
      canPop: false,
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.darkBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.transparent, // 투명 배경
          border: Border.all(color: Colors.transparent), // 테두리 제거
          middle: const Text(
            '프로필 설정',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                
                // 프로필 이미지 선택 영역
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isSelectingImage ? null : _showImageSourceActionSheet,
                        child: Stack(
                          children: [
                            Container(
                              width: circleSize,
                              height: circleSize,
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.separator, width: 2.0),
                              ),
                              child: _profileImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(circleSize / 2),
                                    child: Image.file(
                                      _profileImage!,
                                      width: circleSize,
                                      height: circleSize,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _isSelectingImage
                                  ? const CupertinoActivityIndicator()
                                  : Center(
                                      child: Image.asset(
                                        'assets/images/hashtag_logo.png', // 앱 로고 이미지
                                        width: 60,
                                        height: 60,
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: 5,
                              bottom: 5,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.camera_fill,
                                  size: 20,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _isSelectingImage ? null : _showImageSourceActionSheet,
                        child: Text(
                          '이미지 선택하기',
                          style: TextStyle(
                            color: _isSelectingImage
                              ? AppColors.textSecondary
                              : AppColors.primaryPurple,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 이름 입력
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '이름',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(필수)',
                          style: TextStyle(
                            fontSize: 14,
                            color: _nameError 
                              ? CupertinoColors.systemRed 
                              : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _nameError 
                            ? CupertinoColors.systemRed 
                            : AppColors.separator,
                        ),
                      ),
                      child: CupertinoTextField(
                        controller: _nameController,
                        placeholder: '이름을 입력하세요',
                        maxLength: _maxNameLength,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                        ),
                        placeholderStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                        enabled: !_isNavigating && !profileSetupState.isCompleting && !profileSetupState.isSkipping,
                        onChanged: (value) {
                          if (_nameError && value.isNotEmpty) {
                            setState(() => _nameError = false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // 사용자명 입력
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '사용자명',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(필수)',
                          style: TextStyle(
                            fontSize: 14,
                            color: _usernameError 
                              ? CupertinoColors.systemRed 
                              : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _usernameError 
                            ? CupertinoColors.systemRed 
                            : AppColors.separator,
                        ),
                      ),
                      child: CupertinoTextField(
                        controller: _usernameController,
                        placeholder: '사용자명을 입력하세요 (예: user123)',
                        maxLength: _maxUsernameLength,
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
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                        ),
                        placeholderStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                        enabled: !_isNavigating && !profileSetupState.isCompleting && !profileSetupState.isSkipping,
                        onChanged: (value) {
                          if (_usernameError && value.isNotEmpty) {
                            setState(() => _usernameError = false);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Text(
                        '영문, 숫자, 언더스코어(_)만 사용 가능합니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _usernameError 
                            ? CupertinoColors.systemRed 
                            : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // 소개 입력
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '소개 (선택)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.separator),
                      ),
                      child: CupertinoTextField(
                        controller: _bioController,
                        placeholder: '자신을 소개해보세요',
                        maxLines: 3,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                        ),
                        placeholderStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.left,
                        expands: false,
                        minLines: 1,
                        enabled: !_isNavigating && !profileSetupState.isCompleting && !profileSetupState.isSkipping,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // 프로필 저장 버튼
                Container(
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    gradient: (_isNavigating || profileSetupState.isCompleting || profileSetupState.isSkipping)
                      ? null
                      : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: (_isNavigating || profileSetupState.isCompleting || profileSetupState.isSkipping)
                      ? null
                      : _saveProfile,
                    child: (profileSetupState.isCompleting || _isNavigating)
                      ? const CupertinoActivityIndicator(color: AppColors.white)
                      : const Text(
                          '프로필 저장',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 건너뛰기 버튼
                if (!_isNavigating && !profileSetupState.isCompleting && !profileSetupState.isSkipping)
                  Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showSkipConfirmationDialog,
                      child: const Text(
                        '건너뛰기',
                        style: TextStyle(
                          color: AppColors.textEmphasis,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                
                // 건너뛰기 로딩 상태 표시
                if (profileSetupState.isSkipping && profileSetupState.errorMessage == null)
                  const Center(
                    child: Column(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(height: 8),
                        Text(
                          '기본 프로필 설정 중...',
                          style: TextStyle(
                            color: AppColors.textEmphasis,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // 에러 메시지 표시
                if (profileSetupState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        profileSetupState.errorMessage!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}