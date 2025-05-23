import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
import '../../../models/chat_model.dart';
import '../widgets/post_card.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../auth/login_screen.dart';
import '../feed/chat_detail_screen.dart';
import '../feed/hashtag_channel_detail_screen.dart';
import '../feed/hashtag_explore_screen.dart';

// main.dart의 navigatorKey 가져오기
import '../../../main.dart' as main_file;

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  
  const ProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isMessageLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshProfileData();
  }
  
  // 프로필 데이터 새로고침 메소드 추가
  void _refreshProfileData() {
    // 사용자 프로필 및 프로필 상세 정보 로드
    ref.read(profileControllerProvider.notifier).loadProfile(widget.userId);
    // 유저 프로필 정보 명시적으로 리프레시 (결과값 활용)
    final _ = ref.refresh(getUserProfileProvider(widget.userId));
    
    // 현재 유저가 해당 프로필 사용자를 팔로우하고 있는지 확인
    _checkIfFollowing();
  }
  
  // 팔로우 상태 확인
  void _checkIfFollowing() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser != null && currentUser.id != widget.userId) {
      try {
        final isFollowing = await ref.read(profileControllerProvider.notifier)
            .checkIfFollowing(currentUser.id, widget.userId);
        if (mounted) {
          setState(() {
            _isFollowing = isFollowing;
          });
        }
      } catch (e) {
        debugPrint('팔로우 상태 확인 오류: $e');
      }
    }
  }
  
  // 프로필 메뉴 표시
  void _showProfileMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEditProfile();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.pencil, size: 20),
                SizedBox(width: 8),
                Text('프로필 편집'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToSettings();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.gear, size: 20),
                SizedBox(width: 8),
                Text('설정'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.square_arrow_right, size: 20),
                SizedBox(width: 8),
                Text('로그아웃'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }
  
  // 설정 화면으로 이동
  void _navigateToSettings() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  // 🔥🔥🔥 강화된 로그아웃 처리 함수 - 즉시 Firebase 로그아웃 + 프로바이더 정리
  Future<void> _handleLogout() async {
    if (_isLoggingOut) return; // 중복 실행 방지
    
    showCupertinoDialog(
      context: context,
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
              Navigator.of(dialogContext).pop(); // 다이얼로그 먼저 닫기
              
              // 🔥 즉시 로딩 상태로 변경 (UI 피드백)
              if (mounted) {
                setState(() {
                  _isLoggingOut = true;
                });
              }
              
              debugPrint('🔥🔥🔥 강화된 로그아웃 시작');
              
              try {
                // 🔥 1단계: 모든 프로바이더 즉시 무효화 (권한 오류 방지)
                ref.invalidate(currentUserProvider);
                ref.invalidate(authStateProvider);
                ref.invalidate(profileControllerProvider);
                ref.invalidate(feedPostsProvider);
                debugPrint('🔥 즉시 프로바이더 무효화 완료');
                
                // 🔥 2단계: 상태 완전 초기화
                ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
                ref.read(forceLogoutProvider.notifier).state = true;
                await clearSignupProgress();
                debugPrint('🔥 상태 완전 초기화 완료');
                
                // 🔥 3단계: Firebase 즉시 로그아웃 (권한 오류 방지를 위해)
                try {
                  await ref.read(authControllerProvider.notifier).signOut();
                  debugPrint('🔥 Firebase 로그아웃 성공');
                } catch (e) {
                  debugPrint('🔥 Firebase 로그아웃 에러: $e');
                  // Firebase 로그아웃 실패해도 계속 진행
                }
                
                // 🔥 4단계: 추가 프로바이더 정리 (지연)
                await Future.delayed(const Duration(milliseconds: 200));
                try {
                  ref.invalidate(currentUserProvider);
                  ref.invalidate(authStateProvider);
                  ref.invalidate(profileControllerProvider);
                  debugPrint('🔥 추가 프로바이더 정리 완료');
                } catch (e) {
                  debugPrint('🔥 추가 프로바이더 정리 에러 (무시): $e');
                }
                
                // 🔥 5단계: 강제 네비게이션 (마지막에)
                await Future.delayed(const Duration(milliseconds: 100));
                if (main_file.navigatorKey.currentState != null) {
                  main_file.navigatorKey.currentState!.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false, // 모든 이전 화면 제거
                  );
                  debugPrint('🔥 강제 로그인 화면 이동 완료');
                } else if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                  debugPrint('🔥 로컬 네비게이터로 로그인 화면 이동 완료');
                }
                
                debugPrint('🔥🔥🔥 강화된 로그아웃 완료');
                
              } catch (e) {
                debugPrint('🔥 로그아웃 처리 실패: $e');
                
                // 실패해도 강제로 처리
                try {
                  ref.read(forceLogoutProvider.notifier).state = true;
                  ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
                  await clearSignupProgress();
                  
                  if (main_file.navigatorKey.currentState != null) {
                    main_file.navigatorKey.currentState!.pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  } else if (mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      CupertinoPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (_) {}
              } finally {
                // 로딩 상태 해제 (mounted 체크)
                if (mounted) {
                  setState(() {
                    _isLoggingOut = false;
                  });
                }
              }
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
  
  // 팔로우/언팔로우 처리 함수
  Future<void> _handleFollowToggle() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      // 로그인되지 않은 경우 로그인 화면으로 이동
      _showLoginRequiredDialog();
      return;
    }

    if (currentUser.id == widget.userId) {
      // 자기 자신은 팔로우할 수 없음
      return;
    }

    setState(() {
      _isFollowLoading = true;
    });

    try {
      if (_isFollowing) {
        // 언팔로우 처리
        await ref.read(profileControllerProvider.notifier)
            .unfollowUser(currentUser.id, widget.userId);
      } else {
        // 팔로우 처리
        await ref.read(profileControllerProvider.notifier)
            .followUser(currentUser.id, widget.userId);
      }

      // mounted 체크 추가
      if (!mounted) return;
      
      // 팔로우 상태 업데이트
      setState(() {
        _isFollowing = !_isFollowing;
      });

      // 프로필 데이터 새로고침 (팔로워 수 업데이트)
      _refreshProfileData();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('오류', '팔로우 처리 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFollowLoading = false;
        });
      }
    }
  }
  
  // 메시지 보내기 처리 함수 (수정된 버전)
  void _handleSendMessage() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      // 로그인되지 않은 경우 로그인 화면으로 이동
      _showLoginRequiredDialog();
      return;
    }

    if (currentUser.id == widget.userId) {
      // 자기 자신에게는 메시지를 보낼 수 없음
      return;
    }

    setState(() {
      _isMessageLoading = true;
    });

    try {
      // 채팅 요청 보내기 (기존 채팅방이 있으면 그 채팅방으로 이동)
      final result = await ref.read(chatControllerProvider.notifier)
          .createOrGetChatRoom(currentUser.id, widget.userId);
      
      // mounted 체크를 추가하여 async gap 문제 해결
      if (!mounted) return;
      
      setState(() {
        _isMessageLoading = false;
      });
      
      if (result == null) {
        _showErrorDialog('오류', '채팅방을 생성하는 중 오류가 발생했습니다.');
        return;
      }
      
      // 채팅방 상태 확인
      final chat = await ref.read(chatDetailProvider(result).future);
      
      if (!mounted) return;
      
      if (chat == null) {
        _showErrorDialog('오류', '채팅방 정보를 불러올 수 없습니다.');
        return;
      }
      
      // 채팅방 상태에 따라 다른 처리
      if (chat.status == ChatStatus.active) {
        // 활성 채팅방이면 채팅 화면으로 이동
        final otherUser = await ref.read(getUserProfileProvider(widget.userId).future);
        
        if (!mounted) return;
        
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: result,
              chatName: otherUser?.name ?? otherUser?.username ?? '대화',
              imageUrl: otherUser?.profileImageUrl,
            ),
          ),
        );
      } else if (chat.status == ChatStatus.pending) {
        // 대기 중인 요청이 있으면 알림
        _showInfoDialog(
          '채팅 요청 대기 중',
          '이미 채팅 요청을 보냈습니다. 상대방의 응답을 기다려주세요.'
        );
      } else if (chat.status == ChatStatus.rejected) {
        // 거절된 요청이 있으면 알림
        _showInfoDialog(
          '채팅 요청 거절됨',
          '상대방이 채팅 요청을 거절했습니다.'
        );
      } else {
        // 새로운 채팅 요청이 전송됨
        _showSuccessDialog(
          '채팅 요청 전송',
          '채팅 요청을 보냈습니다. 상대방이 수락하면 대화를 시작할 수 있습니다.'
        );
      }
    } catch (e) {
      // mounted 체크를 추가하여 async gap 문제 해결
      if (!mounted) return;
      
      setState(() {
        _isMessageLoading = false;
      });
      
      // 에러 메시지 처리
      String errorMessage = e.toString();
      if (errorMessage.contains('이미 채팅 요청을 보냈습니다')) {
        _showInfoDialog('채팅 요청 대기 중', errorMessage);
      } else if (errorMessage.contains('상대방이 채팅 요청을 거절했습니다')) {
        _showInfoDialog('채팅 요청 거절됨', errorMessage);
      } else {
        _showErrorDialog('메시지 오류', '채팅 요청을 보내는 중 오류가 발생했습니다: $e');
      }
    }
  }
  
  // 로그인 필요 다이얼로그
  void _showLoginRequiredDialog() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('로그인 필요'),
        content: const Text('이 기능을 사용하려면 로그인이 필요합니다.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            },
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }
  
  // 오류 다이얼로그
  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
  
  // 정보 다이얼로그 (새로 추가)
  void _showInfoDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
  
  // 성공 다이얼로그 (새로 추가)
  void _showSuccessDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
  
  // 프로필 편집 화면으로 이동하는 함수 (중복 방지 로직 추가)
  void _navigateToEditProfile() async {
    // 중복 이동 방지를 위한 현재 경로 이름 저장
    final String routeName = 'profile_edit_${widget.userId}';
    
    // 이미 편집 화면으로 이동 중인지 확인
    bool isAlreadyNavigating = false;
    Navigator.popUntil(context, (route) {
      if (route.settings.name == routeName) {
        isAlreadyNavigating = true;
        return false; // 중단
      }
      return true; // 계속 진행
    });
    
    // 이미 이동 중이면 중단
    if (isAlreadyNavigating) return;
    
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(
        settings: RouteSettings(name: routeName),
        builder: (context) => EditProfileScreen(
          userId: widget.userId,
        ),
      ),
    );
    
    // mounted 체크 추가
    if (!mounted) return;
    
    // 편집 화면에서 돌아오면 프로필 데이터 새로고침
    if (result == true || result == null) {
      _refreshProfileData();
    }
  }
  
  // 해시태그 눌렀을 때 해시태그 채널로 이동 (로딩 표시 제거)
  void _handleHashtagTap(String hashtag) async {
    // # 기호 제거
    final tagName = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    
    try {
      // 해시태그 채널 검색
      final channelRepository = ref.read(hashtagChannelRepositoryProvider);
      final channels = await channelRepository.searchChannels(tagName);
      
      if (!mounted) return;
      
      // 동일한 이름의 채널이 있으면 바로 이동
      final matchedChannel = channels.where(
        (channel) => channel.name.toLowerCase() == tagName.toLowerCase()
      ).toList();
      
      if (!mounted) return;
      
      if (matchedChannel.isNotEmpty) {
        // 일치하는 채널이 있으면 바로 상세 페이지로 이동
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => HashtagChannelDetailScreen(
              channelId: matchedChannel.first.id,
              channelName: matchedChannel.first.name,
            ),
          ),
        );
      } else {
        // 일치하는 채널이 없으면 검색 화면으로 이동
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const HashtagExploreScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      // 오류 발생 시 검색 화면으로 이동
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => const HashtagExploreScreen(),
        ),
      );
    }
  }
  
  // 해시태그 위젯 생성
  Widget _buildHashtags(List<String>? hashtags) {
    if (hashtags == null || hashtags.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hashtags.take(3).map((tag) {
        return GestureDetector(
          onTap: () => _handleHashtagTap(tag),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withAlpha(26), // withOpacity 대신 withAlpha 사용
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '#$tag',
              style: const TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  // 팔로워 수 표시 위젯
  Widget _buildFollowersText(int count) {
    return Row(
      children: [
        const Icon(
          CupertinoIcons.person_2_fill,
          color: AppColors.textSecondary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '팔로워 $count명',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(getUserProfileProvider(widget.userId));
    final profileAsync = ref.watch(profileControllerProvider);
    final postsAsync = ref.watch(userPostsProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    
    final isCurrentUser = currentUser.whenOrNull(
      data: (user) => user?.id == widget.userId,
    ) ?? false;
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: userAsync.when(
          data: (user) => Text(user?.username ?? '프로필'),
          loading: () => const Text('프로필'),
          error: (_, __) => const Text('프로필'),
        ),
        trailing: isCurrentUser
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoggingOut ? null : _showProfileMenu,
                child: const Icon(
                  CupertinoIcons.ellipsis_vertical,
                  color: AppColors.white,
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: _isLoggingOut
          ? const Center(
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
            )
          : CustomScrollView(
              slivers: [
                // 프로필 헤더
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 프로필 정보 - 프로필 사진과 사용자 정보 가로 배치
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 프로필 이미지
                            userAsync.when(
                              data: (user) => UserAvatar(
                                imageUrl: user?.profileImageUrl,
                                size: 80,
                              ),
                              loading: () => const CupertinoActivityIndicator(),
                              error: (_, __) => Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.lightGray,
                                ),
                                child: const Icon(
                                  CupertinoIcons.person_fill,
                                  size: 40,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // 사용자 정보 (계정명, 닉네임)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 닉네임 (이름) - 먼저 표시
                                  userAsync.when(
                                    data: (user) => Text(
                                      user?.name ?? '',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    loading: () => const SizedBox(),
                                    error: (_, __) => const SizedBox(),
                                  ),
                                  
                                  // 계정명 (username) - 그 다음에 표시
                                  userAsync.when(
                                    data: (user) => Text(
                                      '@${user?.username ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    loading: () => const SizedBox(),
                                    error: (_, __) => const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 바이오 (소개)
                        _buildBioSection(profileAsync),
                        
                        // 좋아하는 해시태그
                        const SizedBox(height: 12),
                        profileAsync.when(
                          data: (profile) => _buildHashtags(profile?.favoriteHashtags ?? []),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                        
                        // 팔로워 수 표시 (해시태그 아래)
                        const SizedBox(height: 12),
                        profileAsync.when(
                          data: (profile) => _buildFollowersText(profile?.followersCount ?? 0),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // 프로필 액션 버튼 (색상 변경)
                        if (isCurrentUser)
                          // 프로필 편집 버튼 - 색상 변경
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              color: AppColors.primaryPurple.withAlpha(50), // 더 밝은 보라색으로 변경
                              borderRadius: BorderRadius.circular(8.0),
                              onPressed: _navigateToEditProfile,
                              child: const Text(
                                '프로필 편집',
                                style: TextStyle(
                                  color: AppColors.primaryPurple, // 보라색 텍스트
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        else
                          // 팔로우/메시지 버튼
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  color: _isFollowing 
                                      ? AppColors.primaryPurple.withAlpha(50) // 팔로잉 상태일 때 연한 보라색
                                      : AppColors.primaryPurple, // 팔로우 상태일 때 진한 보라색
                                  borderRadius: BorderRadius.circular(8.0),
                                  onPressed: _isFollowLoading ? null : _handleFollowToggle,
                                  child: _isFollowLoading 
                                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                    : Text(
                                      _isFollowing ? '팔로잉' : '팔로우',
                                      style: TextStyle(
                                        color: _isFollowing 
                                            ? AppColors.primaryPurple // 팔로잉 상태일 때 보라색 텍스트
                                            : CupertinoColors.white, // 팔로우 상태일 때 흰색 텍스트
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  color: AppColors.primaryPurple.withAlpha(50), // 연한 보라색으로 변경
                                  borderRadius: BorderRadius.circular(8.0),
                                  onPressed: _isMessageLoading ? null : _handleSendMessage,
                                  child: _isMessageLoading
                                    ? const CupertinoActivityIndicator(color: AppColors.primaryPurple)
                                    : const Text(
                                      '메시지',
                                      style: TextStyle(
                                        color: AppColors.primaryPurple, // 보라색 텍스트
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                
                // 게시물 구분선
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      height: 1,
                      child: ColoredBox(
                        color: AppColors.separator,
                      ),
                    ),
                  ),
                ),
                
                // 게시물 목록 헤더
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Text(
                      '게시물',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                // 게시물 목록
                postsAsync.when(
                  data: (posts) {
                    if (posts.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            '게시물이 없습니다.',
                          ),
                        ),
                      );
                    }
                    
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = posts[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: PostCard(
                              post: post,
                              onProfileTap: null, // 자신의 프로필 화면에서는 탭 불필요
                            ),
                          );
                        },
                        childCount: posts.length,
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(
                      child: CupertinoActivityIndicator(),
                    ),
                  ),
                  error: (_, __) => const SliverFillRemaining(
                    child: Center(
                      child: Text('게시물을 불러올 수 없습니다.'),
                    ),
                  ),
                ),
              ],
            ),
        ),
    );
  }
  
  Widget _buildBioSection(AsyncValue<dynamic> profileAsync) {
    return profileAsync.when(
      data: (profile) {
        if (profile?.bio != null && profile.bio!.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              profile.bio!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textEmphasis,
              ),
            ),
          );
        }
        return const SizedBox();
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}