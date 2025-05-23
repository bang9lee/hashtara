import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../models/hashtag_channel_model.dart';
import '../widgets/post_card.dart';
import 'hashtag_explore_screen.dart';
import 'create_post_screen.dart';
import 'hashtag_channel_detail_screen.dart';
import 'subscribed_channels_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  // 🔥 추가: 알림 아이콘 애니메이션을 위한 컨트롤러들
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  bool get wantKeepAlive => true; // 상태 유지를 위한 설정

  @override
  void initState() {
    super.initState();
    debugPrint('HomeScreen 초기화됨');
    
    // 🔥 추가: 애니메이션 컨트롤러 초기화
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // 🔥 추가: 펄스 애니메이션 (크기 변화)
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // 🔥 추가: 글로우 애니메이션 (불투명도 변화)
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // 🔥 추가: 무한 반복 애니메이션 시작
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _refreshController.dispose();
    // 🔥 추가: 애니메이션 컨트롤러 해제
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // 새로고침 처리 함수
  Future<void> _onRefresh() async {
    try {
      // 인기 채널 새로고침
      ref.invalidate(popularHashtagChannelsProvider);
      debugPrint('인기 채널 새로고침 요청됨');

      // 피드 게시물 새로고침
      ref.invalidate(feedPostsProvider);
      debugPrint('피드 새로고침 요청됨');

      // 로그인 된 경우 구독 채널도 새로고침
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref.invalidate(userSubscribedChannelsProvider(user.id));
        debugPrint('사용자 채널 새로고침 요청됨: ${user.id}');
      }

      // 딜레이 추가 (실제 API 요청 느낌 주기)
      await Future.delayed(const Duration(milliseconds: 800));
      debugPrint('새로고침 완료');
    } catch (e) {
      debugPrint('새로고침 실패: $e');
    } finally {
      _refreshController.refreshCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentUser = ref.watch(currentUserProvider);

    // 인기 해시태그 채널 (캐싱 적용된 상태)
    final popularChannels = ref.watch(popularHashtagChannelsProvider);

    // 필터링된 피드 게시물 가져오기
    final userId = currentUser.valueOrNull?.id;
    final feedPosts = userId != null
        ? ref.watch(filteredFeedPostsProvider(userId))
        : ref.watch(feedPostsProvider);

    // 사용자가 구독한 해시태그 채널 (조건부 로드)
    final subscribedChannels = currentUser.maybeWhen(
      data: (user) => user != null
          ? ref.watch(userSubscribedChannelsProvider(user.id))
          : null,
      orElse: () => null,
    );

    // 🔥 수정: 안 읽은 알림 개수도 함께 가져오기
    final hasUnreadNotifications = currentUser.maybeWhen(
      data: (user) => user != null
          ? ref.watch(hasUnreadNotificationsProvider(user.id))
          : const AsyncValue.data(false),
      orElse: () => const AsyncValue.data(false),
    );
    
    final unreadCount = currentUser.maybeWhen(
      data: (user) => user != null
          ? ref.watch(unreadNotificationsCountProvider(user.id))
          : const AsyncValue.data(0),
      orElse: () => const AsyncValue.data(0),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color.fromRGBO(124, 95, 255, 0),
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: const Text(
            AppStrings.appName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const HashtagExploreScreen(),
                  ),
                );
              },
              child: const Icon(
                CupertinoIcons.search,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 8),
            // 🔥 수정: 향상된 알림 버튼
            _buildEnhancedNotificationButton(hasUnreadNotifications, unreadCount),
          ],
        ),
      ),
      child: SafeArea(
        child: SmartRefresher(
          controller: _refreshController,
          onRefresh: _onRefresh,
          enablePullDown: true,
          header: const ClassicHeader(
            completeText: '새로고침 완료',
            refreshingText: '로딩 중...',
            releaseText: '놓아서 새로고침',
            idleText: '당겨서 새로고침',
            textStyle: TextStyle(color: AppColors.textEmphasis),
          ),
          child: CustomScrollView(
            slivers: [
              // 상단 시작 영역 - 새 게시물 작성 버튼
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12.0),
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => const CreatePostScreen(),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.add_circled_solid,
                          color: AppColors.primaryPurple,
                          size: 24,
                        ),
                        SizedBox(width: 8.0),
                        Text(
                          '새 게시물 작성하기',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 1. 내 채널 섹션 (로그인된 사용자만 표시)
              if (currentUser.valueOrNull != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '내 채널',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            // 내 구독 채널 화면으로 이동
                            Navigator.of(context)
                                .push(
                              CupertinoPageRoute(
                                builder: (context) =>
                                    const SubscribedChannelsScreen(),
                              ),
                            )
                                .then((_) {
                              // 화면 복귀 시 데이터 새로고침
                              final user =
                                  ref.read(currentUserProvider).valueOrNull;
                              if (user != null) {
                                ref.invalidate(
                                    userSubscribedChannelsProvider(user.id));
                              }
                            });
                          },
                          child: const Text(
                            '더보기',
                            style: TextStyle(color: AppColors.primaryPurple),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 구독 채널 목록
                if (subscribedChannels != null)
                  _buildSubscribedChannelsSection(subscribedChannels),
              ],

              // 2. 인기 해시태그 섹션
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '인기 해시태그',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                            CupertinoPageRoute(
                              builder: (context) =>
                                  const HashtagExploreScreen(),
                            ),
                          )
                              .then((_) {
                            // 화면 복귀 시 데이터 새로고침
                            ref.invalidate(popularHashtagChannelsProvider);
                          });
                        },
                        child: const Text(
                          '더보기',
                          style: TextStyle(color: AppColors.primaryPurple),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 인기 채널 목록 - 로우 형식으로 변경
              _buildPopularChannelsSection(popularChannels),

              // 여백
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),

              // 3. 최신 게시물 섹션
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '최신 게시물',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          // 최신 게시물 더보기 (미구현)
                        },
                        child: const Text(
                          '더보기',
                          style: TextStyle(color: AppColors.primaryPurple),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 피드 게시물 목록
              _buildFeedPostsSection(feedPosts),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 새로 추가: 향상된 알림 버튼
  Widget _buildEnhancedNotificationButton(
    AsyncValue<bool> hasUnreadNotifications,
    AsyncValue<int> unreadCount,
  ) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        // 알림 화면으로 이동
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => const NotificationScreen(),
          ),
        );
      },
      child: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🔥 배경 글로우 효과 (알림이 있을 때만)
            hasUnreadNotifications.when(
              data: (hasUnread) => hasUnread
                  ? AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withAlpha((0.6 * 255 * _glowAnimation.value).round()),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            
            // 🔥 벨 아이콘 (펄스 효과 포함)
            hasUnreadNotifications.when(
              data: (hasUnread) => hasUnread
                  ? AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: const Icon(
                            CupertinoIcons.bell_fill,
                            color: AppColors.white,
                            size: 24,
                          ),
                        );
                      },
                    )
                  : const Icon(
                      CupertinoIcons.bell,
                      color: AppColors.white,
                      size: 24,
                    ),
              loading: () => const Icon(
                CupertinoIcons.bell,
                color: AppColors.white,
                size: 24,
              ),
              error: (_, __) => const Icon(
                CupertinoIcons.bell,
                color: AppColors.white,
                size: 24,
              ),
            ),
            
            // 🔥 알림 개수 배지 (향상된 디자인)
            Positioned(
              top: 0,
              right: 0,
              child: unreadCount.when(
                data: (count) => count > 0
                    ? AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              height: 16,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF6B6B), // 밝은 빨간색
                                    Color(0xFFFF4757), // 진한 빨간색
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF4757).withAlpha((0.5 * 255).round()),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  count > 99 ? '99+' : count.toString(),
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 구독 채널 섹션
  Widget _buildSubscribedChannelsSection(
      AsyncValue<List<HashtagChannelModel>> subscribedChannels) {
    return subscribedChannels.when(
      data: (channels) {
        if (channels.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.number,
                      size: 40,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '아직 구독한 채널이 없습니다.\n관심있는 해시태그를 탐색해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textEmphasis,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: SizedBox(
            height: 140,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _buildChannelCard(channel);
              },
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CupertinoActivityIndicator(),
          ),
        ),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '구독 채널을 불러오는 중 오류가 발생했습니다: $error',
              style: const TextStyle(color: AppColors.textEmphasis),
            ),
          ),
        ),
      ),
    );
  }

  // 인기 채널 섹션
  Widget _buildPopularChannelsSection(
      AsyncValue<List<HashtagChannelModel>> popularChannels) {
    return popularChannels.when(
      data: (channels) {
        if (channels.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '아직 채널이 없습니다',
                  style: TextStyle(color: AppColors.textEmphasis),
                ),
              ),
            ),
          );
        }

        // 로우 형식으로 변경
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0, // 가로 간격
              runSpacing: 12.0, // 세로 간격
              children: channels.map((channel) {
                return _buildHashtagPill(
                  tag: channel.name,
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => HashtagChannelDetailScreen(
                          channelId: channel.id,
                          channelName: channel.name,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CupertinoActivityIndicator(),
          ),
        ),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              '인기 채널을 불러오는 중 오류가 발생했습니다: $error',
              style: const TextStyle(color: AppColors.textEmphasis),
            ),
          ),
        ),
      ),
    );
  }

  // 피드 게시물 섹션
  Widget _buildFeedPostsSection(AsyncValue<List<dynamic>> feedPosts) {
    return feedPosts.when(
      data: (posts) {
        if (posts.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.photo,
                      size: 40,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '아직 게시물이 없습니다.\n첫 게시물을 작성해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textEmphasis,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
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
                  // PostCard 위젯 내부에서 탭 핸들링을 처리하므로 별도의 onTap 콜백은 제거
                ),
              );
            },
            childCount: posts.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CupertinoActivityIndicator(),
          ),
        ),
      ),
      error: (error, stack) {
        debugPrint('피드 로드 에러: $error');
        return SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '게시물을 불러오는 중 오류가 발생했습니다: $error',
                style: const TextStyle(color: AppColors.textEmphasis),
              ),
            ),
          ),
        );
      },
    );
  }

  // 해시태그 핀 위젯 (로우 형식) - 그라데이션 적용
  Widget _buildHashtagPill({required String tag, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          // 단색 대신 그라데이션 적용
          gradient: const LinearGradient(
            colors: [
              Color(0xC8785BFF), // AppColors.primaryPurple 200/255 투명도
              Color(0x64785BFF), // AppColors.primaryPurple 100/255 투명도
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#$tag',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 수평 채널 카드 위젯 - 그라데이션 적용
  Widget _buildChannelCard(HashtagChannelModel channel) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => HashtagChannelDetailScreen(
              channelId: channel.id,
              channelName: channel.name,
            ),
          ),
        );
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12.0),
        decoration: BoxDecoration(
          // 그라데이션 배경 적용
          gradient: const LinearGradient(
            colors: [
              Color(0xC8785BFF), // AppColors.primaryPurple 200/255 투명도
              Color(0x64785BFF), // AppColors.primaryPurple 100/255 투명도
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: AppColors.separator,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: AppColors.primaryPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.number,
                color: AppColors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '#${channel.name}',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${channel.postsCount}개의 게시물',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}