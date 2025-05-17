import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart'; // feed_provider 추가
import '../../../providers/hashtag_channel_provider.dart';
import '../../../models/hashtag_channel_model.dart';
import '../widgets/channel_card.dart';
import '../widgets/post_card.dart'; // post_card 위젯 추가
import 'hashtag_explore_screen.dart';
import 'create_post_screen.dart';
import 'hashtag_channel_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  
  @override
  void initState() {
    super.initState();
    debugPrint('HomeScreen 초기화됨');
  }
  
  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
  
  // 새로고침 처리 함수
  Future<void> _onRefresh() async {
    try {
      // 인기 채널 새로고침
      final popularChannelsRefresh = await ref.refresh(popularHashtagChannelsProvider.future);
      
      // 피드 게시물 새로고침
      final feedPostsRefresh = await ref.refresh(feedPostsProvider.future);
      
      // 로그인 된 경우 구독 채널도 새로고침
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final userChannelsRefresh = await ref.refresh(userSubscribedChannelsProvider(user.id).future);
        // 경고 제거를 위해 변수 사용
        debugPrint('채널 새로고침 상태 확인: $userChannelsRefresh');
      }
      
      // 경고 제거를 위해 변수 사용
      debugPrint('인기 채널 새로고침 상태 확인: $popularChannelsRefresh');
      debugPrint('피드 새로고침 상태 확인: $feedPostsRefresh');
      
      // 딜레이 추가 (실제 API 요청 느낌 주기)
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('새로고침 완료');
    } catch (e) {
      debugPrint('새로고침 실패: $e');
    } finally {
      _refreshController.refreshCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    // 인기 해시태그 채널
    final popularChannels = ref.watch(popularHashtagChannelsProvider);
    
    // 피드 게시물 추가
    final feedPosts = ref.watch(feedPostsProvider);
    
    // 사용자가 구독한 해시태그 채널
    final subscribedChannels = currentUser.whenOrNull(
      data: (user) => user != null
          ? ref.watch(userSubscribedChannelsProvider(user.id))
          : null,
    );
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: ShaderMask(
          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
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
                Navigator.push(
                  context,
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
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                // 알림 화면으로 이동
              },
              child: const Icon(
                CupertinoIcons.bell,
                color: AppColors.white,
              ),
            ),
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
                      Navigator.push(
                        context,
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
              
              // 피드 게시물 섹션 추가
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              feedPosts.when(
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
                            onProfileTap: () {
                              // 프로필 페이지로 이동
                            },
                          ),
                        );
                      },
                      childCount: posts.length > 3 ? 3 : posts.length, // 최대 3개만 표시
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
              ),
              
              // 구독한 채널 섹션
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
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => const HashtagExploreScreen(),
                              ),
                            );
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
                subscribedChannels != null
                    ? subscribedChannels.when(
                        data: (channels) {
                          if (channels.isEmpty) {
                            return const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        CupertinoIcons.number, // hashtag에서 number로 수정
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
                        error: (_, __) => const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                '구독 채널을 불러오는 중 오류가 발생했습니다.',
                                style: TextStyle(color: AppColors.textEmphasis),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SliverToBoxAdapter(child: SizedBox()),
              ],
              
              // 인기 채널 섹션
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
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const HashtagExploreScreen(),
                            ),
                          );
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
              
              // 인기 채널 목록
              popularChannels.when(
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
                  
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final channel = channels[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ChannelCard(
                            channel: channel,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => HashtagChannelDetailScreen(
                                    channelId: channel.id,
                                    channelName: channel.name,
                                  ),
                                ),
                              );
                            },
                            onSubscribe: currentUser.whenOrNull(
                              data: (user) => user != null
                                  ? () {
                                      ref.read(hashtagChannelControllerProvider.notifier).subscribeToChannel(
                                        user.id,
                                        channel.id,
                                      );
                                    }
                                  : null,
                            ),
                          ),
                        );
                      },
                      childCount: channels.length,
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
                error: (_, __) => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        '인기 채널을 불러오는 중 오류가 발생했습니다.',
                        style: TextStyle(color: AppColors.textEmphasis),
                      ),
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
  
  // 수평 채널 카드 위젯
  Widget _buildChannelCard(HashtagChannelModel channel) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
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
          color: AppColors.cardBackground,
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
                CupertinoIcons.number, // hashtag에서 number로 수정
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