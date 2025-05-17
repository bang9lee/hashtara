import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/feed_provider.dart';
import '../widgets/post_card.dart';
import 'edit_profile_screen.dart';
import '../auth/login_screen.dart';

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
  }

  // 로그아웃 처리 함수
  Future<void> _handleLogout() async {
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
              Navigator.of(dialogContext).pop();
              
              setState(() {
                _isLoggingOut = true;
              });
              
              try {
                await ref.read(authControllerProvider.notifier).signOut();
                
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  CupertinoPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _isLoggingOut = false;
                });
                
                showCupertinoDialog(
                  context: context,
                  builder: (errorContext) => CupertinoAlertDialog(
                    title: const Text('오류'),
                    content: Text('로그아웃 중 오류가 발생했습니다: $e'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('확인'),
                        onPressed: () => Navigator.of(errorContext).pop(),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
  
  // 프로필 편집 화면으로 이동하는 함수
  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => EditProfileScreen(
          userId: widget.userId,
        ),
      ),
    );
    
    // 편집 화면에서 돌아오면 프로필 데이터 새로고침
    if (result == true || result == null) {
      _refreshProfileData();
    }
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
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoggingOut ? null : _handleLogout,
                    child: const Icon(CupertinoIcons.square_arrow_right),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoggingOut ? null : _navigateToEditProfile,
                    child: const Icon(CupertinoIcons.settings),
                  ),
                ],
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
                          children: [
                            // 프로필 이미지
                            userAsync.when(
                              data: (user) => Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.lightGray,
                                  image: user?.profileImageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(user!.profileImageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: user?.profileImageUrl == null
                                    ? const Icon(
                                        CupertinoIcons.person_fill,
                                        size: 40,
                                        color: CupertinoColors.systemGrey,
                                      )
                                    : null,
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
                            const SizedBox(width: 24),
                            
                            // 게시물, 팔로워, 팔로잉 카운트
                            Expanded(
                              child: profileAsync.when(
                                data: (profile) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildCountColumn('게시물', profile?.postCount ?? 0),
                                    _buildCountColumn('팔로워', profile?.followersCount ?? 0),
                                    _buildCountColumn('팔로잉', profile?.followingCount ?? 0),
                                  ],
                                ),
                                loading: () => const CupertinoActivityIndicator(),
                                error: (_, __) => const Text('프로필을 불러올 수 없습니다.'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // 사용자 이름
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
                        
                        // 바이오 (소개)
                        _buildBioSection(profileAsync),
                        
                        const SizedBox(height: 16),
                        
                        // 프로필 액션 버튼
                        if (isCurrentUser)
                          // 프로필 편집 버튼
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              color: AppColors.lightGray,
                              borderRadius: BorderRadius.circular(8.0),
                              onPressed: _navigateToEditProfile,
                              child: const Text(
                                '프로필 편집',
                                style: TextStyle(
                                  color: CupertinoColors.black,
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
                                  color: AppColors.primaryPurple,
                                  borderRadius: BorderRadius.circular(8.0),
                                  onPressed: () {
                                    // 팔로우 기능 구현
                                  },
                                  child: const Text(
                                    '팔로우',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
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
                                  color: AppColors.lightGray,
                                  borderRadius: BorderRadius.circular(8.0),
                                  onPressed: () {
                                    // 메시지 기능 구현
                                  },
                                  child: const Text(
                                    '메시지',
                                    style: TextStyle(
                                      color: CupertinoColors.black,
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
  
  Widget _buildCountColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textEmphasis,
          ),
        ),
      ],
    );
  }
}