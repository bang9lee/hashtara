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
  
  // 해시태그 관련 추가
  final List<String> _favoriteHashtags = [];
  final _hashtagController = TextEditingController();
  
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
          
          // 좋아하는 해시태그 로드
          _favoriteHashtags.clear();
          if (profile.favoriteHashtags != null) {
            _favoriteHashtags.addAll(profile.favoriteHashtags!);
          }
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
    _hashtagController.dispose(); // 해시태그 컨트롤러 해제
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    
    // showCupertinoModalPopup을 사용하여 선택 옵션 표시
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('프로필 사진 선택'),
        message: const Text('사진을 선택하거나 찍으세요'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('카메라로 촬영'),
            onPressed: () async {
              Navigator.pop(context);
              final pickedFile = await picker.pickImage(
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
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('갤러리에서 선택'),
            onPressed: () async {
              Navigator.pop(context);
              final pickedFile = await picker.pickImage(
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
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('취소'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
  
  // 해시태그 추가 함수
  void _addHashtag() {
    final hashtag = _hashtagController.text.trim();
    if (hashtag.isEmpty) return;
    
    // # 기호가 앞에 있으면 제거
    final cleanHashtag = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    
    // 이미 존재하는 해시태그인지 확인
    if (!_favoriteHashtags.contains(cleanHashtag)) {
      // 최대 3개까지만 추가 가능
      if (_favoriteHashtags.length < 3) {
        setState(() {
          _favoriteHashtags.add(cleanHashtag);
          _hashtagController.clear();
        });
      } else {
        // 최대 개수 초과 메시지
        setState(() {
          _errorMessage = '해시태그는 최대 3개까지 추가할 수 있습니다.';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _errorMessage = null;
            });
          }
        });
      }
    } else {
      // 중복 해시태그 메시지
      setState(() {
        _errorMessage = '이미 추가된 해시태그입니다.';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      });
    }
  }
  
  // 해시태그 삭제 함수
  void _removeHashtag(String hashtag) {
    setState(() {
      _favoriteHashtags.remove(hashtag);
    });
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
      
      // 추가 프로필 정보 업데이트 (좋아하는 해시태그 포함)
      await ref.read(profileControllerProvider.notifier).updateProfile(
        userId: widget.userId,
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        favoriteHashtags: _favoriteHashtags,
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
              
              // 좋아하는 해시태그 섹션 추가
              const Text(
                '좋아하는 해시태그 (최대 3개)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textEmphasis,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _hashtagController,
                      placeholder: '해시태그 입력 (예: flutter)',
                      enabled: !_isLoading && _favoriteHashtags.length < 3,
                      // CustomTextField에서 textInputAction과 onSubmitted가 지원되지 않으므로 제거
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: !_isLoading && _favoriteHashtags.length < 3 ? _addHashtag : null,
                    child: const Text(
                      '추가',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 해시태그 목록
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _favoriteHashtags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withAlpha(26), // withOpacity 대신 withAlpha 사용
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$tag',
                          style: const TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeHashtag(tag),
                          child: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: AppColors.primaryPurple,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              // 로딩 인디케이터
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CupertinoActivityIndicator(),
                  ),
                ),
              
              // 에러 메시지
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
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