import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../common/custom_text_field.dart';
import '../auth/login_screen.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  
  const EditProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  
  File? _profileImage;
  bool _isLoading = false;
  bool _isLoggingOut = false;
  String? _errorMessage;
  String? _currentProfileImageUrl;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    final userAsync = ref.read(authRepositoryProvider).getUserProfile(widget.userId);
    final profileAsync = ref.read(profileControllerProvider);
    
    userAsync.then((user) {
      if (user != null && mounted) {
        setState(() {
          _nameController.text = user.name ?? '';
          _usernameController.text = user.username ?? '';
          _currentProfileImageUrl = user.profileImageUrl;
        });
      }
    });
    
    profileAsync.whenData((profile) {
      if (profile != null && mounted) {
        setState(() {
          _bioController.text = profile.bio ?? '';
          _locationController.text = profile.location ?? '';
        });
      }
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }
  
  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _usernameController.text.isEmpty) {
      setState(() {
        _errorMessage = '이름과 사용자명은 필수입니다.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 프로필 이미지 업로드
      String? profileImageUrl = _currentProfileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await ref
            .read(profileControllerProvider.notifier)
            .uploadProfileImage(widget.userId, _profileImage!);
      }
      
      // 사용자 프로필 업데이트
      await ref.read(authControllerProvider.notifier).updateUserProfile(
        userId: widget.userId,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        profileImageUrl: profileImageUrl,
      );
      
      // 추가 프로필 정보 업데이트
      await ref.read(profileControllerProvider.notifier).updateProfile(
        userId: widget.userId,
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
      );
      
      // Provider 캐시 갱신 - Lint 경고 수정
      final refresh1 = ref.refresh(getUserProfileProvider(widget.userId));
      final refresh2 = ref.refresh(profileControllerProvider);
      final refresh3 = ref.refresh(currentUserProvider);
      
      // Lint 경고 제거를 위한 사용
      debugPrint('Provider 갱신 완료: ${refresh1.hashCode}, ${refresh2.hashCode}, ${refresh3.hashCode}');
      
      // 성공 시 이전 화면으로 돌아감
      if (mounted) {
        Navigator.pop(context, true); // 결과값 true 전달
      }
    } catch (e) {
      setState(() {
        _errorMessage = '프로필 업데이트에 실패했습니다. 다시 시도해주세요.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 로그아웃 처리 함수
  Future<void> _handleLogout() async {
    // 로그아웃 전 최종 확인을 위한 다이얼로그 표시 - BuildContext 캡처
    final BuildContext currentContext = context;
    
    showCupertinoDialog(
      context: currentContext,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              // 다이얼로그 닫기
              Navigator.of(dialogContext).pop();
              
              // 로그아웃 진행 상태 설정
              setState(() {
                _isLoggingOut = true;
              });
              
              try {
                await ref.read(authControllerProvider.notifier).signOut();
                
                // 로그아웃 성공 시 로그인 화면으로 이동
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false, // 모든 이전 화면 제거
                  );
                }
              } catch (e) {
                // 로그아웃 실패 시 오류 표시
                if (mounted) {
                  setState(() {
                    _isLoggingOut = false;
                  });
                  
                  // 비동기 작업 이후에 새로운 BuildContext 사용
                  if (!mounted) return;
                  showCupertinoDialog(
                    context: context,
                    builder: (errorDialogContext) => CupertinoAlertDialog(
                      title: const Text('오류'),
                      content: Text('로그아웃 중 오류가 발생했습니다: $e'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('확인'),
                          onPressed: () => Navigator.of(errorDialogContext).pop(),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoggingOut) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('로그아웃'),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 16),
              Text(
                '로그아웃 중...',
                style: TextStyle(color: AppColors.textEmphasis),
              ),
            ],
          ),
        ),
      );
    }
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('프로필 편집'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveProfile,
          child: const Text(
            '저장',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 이미지
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lightGray,
                      image: _profileImage != null
                          ? DecorationImage(
                              image: FileImage(_profileImage!),
                              fit: BoxFit.cover,
                            )
                          : _currentProfileImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_currentProfileImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: _profileImage == null && _currentProfileImageUrl == null
                        ? const Icon(
                            CupertinoIcons.person_fill,
                            size: 50,
                            color: CupertinoColors.systemGrey,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _pickImage,
                  child: const Text('프로필 사진 변경'),
                ),
              ),
              const SizedBox(height: 24),
              
              // 이름
              const Text(
                '이름',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textEmphasis,
                ),
              ),
              const SizedBox(height: 4),
              CustomTextField(
                controller: _nameController,
                placeholder: '이름을 입력하세요',
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              
              // 사용자명
              const Text(
                '사용자명',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textEmphasis,
                ),
              ),
              const SizedBox(height: 4),
              CustomTextField(
                controller: _usernameController,
                placeholder: '사용자명을 입력하세요',
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              
              // 소개
              const Text(
                '소개',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textEmphasis,
                ),
              ),
              const SizedBox(height: 4),
              CustomTextField(
                controller: _bioController,
                placeholder: '자신을 소개해보세요',
                maxLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              
              // 위치
              const Text(
                '위치',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textEmphasis,
                ),
              ),
              const SizedBox(height: 4),
              CustomTextField(
                controller: _locationController,
                placeholder: '위치를 입력하세요',
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              
              // 로딩 인디케이터
              if (_isLoading)
                const Center(
                  child: CupertinoActivityIndicator(),
                ),
              
              // 에러 메시지
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // 로그아웃 버튼
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _handleLogout,
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}