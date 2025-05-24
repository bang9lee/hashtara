import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // 🔥 kIsWeb 추가
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

  // 🔥🔥🔥 웹 호환성 강화된 로그아웃 처리
  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    
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
              Navigator.of(dialogContext).pop();
              
              if (mounted) {
                setState(() {
                  _isLoggingOut = true;
                });
              }
              
              debugPrint('🔥🔥🔥 로그아웃 시작 (플랫폼: ${kIsWeb ? '웹' : '모바일'})');
              
              try {
                // 🔥 1단계: 모든 프로바이더 즉시 무효화
                ref.invalidate(currentUserProvider);
                ref.invalidate(authStateProvider);
                ref.invalidate(profileControllerProvider);
                ref.invalidate(feedPostsProvider);
                debugPrint('🔥 프로바이더 무효화 완료');
                
                // 🔥 2단계: 상태 완전 초기화
                ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
                ref.read(forceLogoutProvider.notifier).state = true;
                await clearSignupProgress();
                debugPrint('🔥 상태 초기화 완료');
                
                // 🔥 3단계: Firebase 로그아웃
                try {
                  await ref.read(authControllerProvider.notifier).signOut();
                  debugPrint('🔥 Firebase 로그아웃 성공');
                } catch (e) {
                  debugPrint('🔥 Firebase 로그아웃 에러: $e');
                }
                
                // 🔥 4단계: 추가 프로바이더 정리
                await Future.delayed(const Duration(milliseconds: 200));
                try {
                  ref.invalidate(currentUserProvider);
                  ref.invalidate(authStateProvider);
                  ref.invalidate(profileControllerProvider);
                  debugPrint('🔥 추가 프로바이더 정리 완료');
                } catch (e) {
                  debugPrint('🔥 추가 프로바이더 정리 에러: $e');
                }
                
                // 🔥 5단계: 네비게이션 처리 (웹 호환성 강화)
                await Future.delayed(const Duration(milliseconds: 100));
                
                if (kIsWeb) {
                  // 🌐 웹에서는 더 안전한 네비게이션
                  debugPrint('🌐 웹: 안전한 네비게이션 시작');
                  
                  if (mounted) {
                    // 웹에서는 직접 화면 교체
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      CupertinoPageRoute(
                        builder: (context) => const LoginScreen(),
                        settings: const RouteSettings(name: '/login'),
                      ),
                      (route) => false,
                    );
                    debugPrint('🌐 웹: 로그인 화면 이동 완료');
                  }
                } else {
                  // 📱 모바일에서는 기존 방식
                  if (main_file.navigatorKey.currentState != null) {
                    main_file.navigatorKey.currentState!.pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                    debugPrint('📱 모바일: 로그인 화면 이동 완료');
                  } else if (mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      CupertinoPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                }
                
                debugPrint('🔥🔥🔥 로그아웃 완료');
                
              } catch (e) {
                debugPrint('🔥 로그아웃 처리 실패: $e');
                
                // 실패해도 강제로 처리
                try {
                  ref.read(forceLogoutProvider.notifier).state = true;
                  ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
                  await clearSignupProgress();
                  
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      CupertinoPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (_) {}
              } finally {
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
      _showLoginRequiredDialog();
      return;
    }

    if (currentUser.id == widget.userId) {
      return;
    }

    setState(() {
      _isFollowLoading = true;
    });

    try {
      if (_isFollowing) {
        await ref.read(profileControllerProvider.notifier)
            .unfollowUser(currentUser.id, widget.userId);
      } else {
        await ref.read(profileControllerProvider.notifier)
            .followUser(currentUser.id, widget.userId);
      }

      if (!mounted) return;
      
      setState(() {
        _isFollowing = !_isFollowing;
      });

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
  
  // 메시지 보내기 처리 함수
  void _handleSendMessage() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    if (currentUser.id == widget.userId) {
      return;
    }

    setState(() {
      _isMessageLoading = true;
    });

    try {
      final result = await ref.read(chatControllerProvider.notifier)
          .createOrGetChatRoom(currentUser.id, widget.userId);
      
      if (!mounted) return;
      
      setState(() {
        _isMessageLoading = false;
      });
      
      if (result == null) {
        _showErrorDialog('오류', '채팅방을 생성하는 중 오류가 발생했습니다.');
        return;
      }
      
      final chat = await ref.read(chatDetailProvider(result).future);
      
      if (!mounted) return;
      
      if (chat == null) {
        _showErrorDialog('오류', '채팅방 정보를 불러올 수 없습니다.');
        return;
      }
      
      if (chat.status == ChatStatus.active) {
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
        _showInfoDialog(
          '채팅 요청 대기 중',
          '이미 채팅 요청을 보냈습니다. 상대방의 응답을 기다려주세요.'
        );
      } else if (chat.status == ChatStatus.rejected) {
        _showInfoDialog(
          '채팅 요청 거절됨',
          '상대방이 채팅 요청을 거절했습니다.'
        );
      } else {
        _showSuccessDialog(
          '채팅 요청 전송',
          '채팅 요청을 보냈습니다. 상대방이 수락하면 대화를 시작할 수 있습니다.'
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isMessageLoading = false;
      });
      
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
  
  // 정보 다이얼로그
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
  
  // 성공 다이얼로그
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
  
  // 프로필 편집 화면으로 이동
  void _navigateToEditProfile() async {
    final String routeName = 'profile_edit_${widget.userId}';
    
    bool isAlreadyNavigating = false;
    Navigator.popUntil(context, (route) {
      if (route.settings.name == routeName) {
        isAlreadyNavigating = true;
        return false;
      }
      return true;
    });
    
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
    
    if (!mounted) return;
    
    if (result == true || result == null) {
      _refreshProfileData();
    }
  }
  
  // 해시태그 눌렀을 때 해시태그 채널로 이동
  void _handleHashtagTap(String hashtag) async {
    final tagName = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    
    try {
      final channelRepository = ref.read(hashtagChannelRepositoryProvider);
      final channels = await channelRepository.searchChannels(tagName);
      
      if (!mounted) return;
      
      final matchedChannel = channels.where(
        (channel) => channel.name.toLowerCase() == tagName.toLowerCase()
      ).toList();
      
      if (!mounted) return;
      
      if (matchedChannel.isNotEmpty) {
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
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const HashtagExploreScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
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
              color: AppColors.primaryPurple.withAlpha(26),
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
                        // 프로필 정보
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
                            
                            // 사용자 정보
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 닉네임
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
                                  
                                  // 계정명
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
                        
                        // 바이오
                        _buildBioSection(profileAsync),
                        
                        // 해시태그
                        const SizedBox(height: 12),
                        profileAsync.when(
                          data: (profile) => _buildHashtags(profile?.favoriteHashtags ?? []),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                        
                        // 팔로워 수
                        const SizedBox(height: 12),
                        profileAsync.when(
                          data: (profile) => _buildFollowersText(profile?.followersCount ?? 0),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // 프로필 액션 버튼
                        if (isCurrentUser)
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              color: AppColors.primaryPurple.withAlpha(50),
                              borderRadius: BorderRadius.circular(8.0),
                              onPressed: _navigateToEditProfile,
                              child: const Text(
                                '프로필 편집',
                                style: TextStyle(
                                  color: AppColors.primaryPurple,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  color: _isFollowing 
                                      ? AppColors.primaryPurple.withAlpha(50)
                                      : AppColors.primaryPurple,
                                  borderRadius: BorderRadius.circular(8.0),
                                  onPressed: _isFollowLoading ? null : _handleFollowToggle,
                                  child: _isFollowLoading 
                                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                    : Text(
                                      _isFollowing ? '팔로잉' : '팔로우',
                                      style: TextStyle(
                                        color: _isFollowing 
                                            ? AppColors.primaryPurple
                                            : CupertinoColors.white,
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
                                  color: AppColors.primaryPurple.withAlpha(50),
                                  borderRadius: BorderRadius.circular(8.0),
                                  onPressed: _isMessageLoading ? null : _handleSendMessage,
                                  child: _isMessageLoading
                                    ? const CupertinoActivityIndicator(color: AppColors.primaryPurple)
                                    : const Text(
                                      '메시지',
                                      style: TextStyle(
                                        color: AppColors.primaryPurple,
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
                              onProfileTap: null,
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