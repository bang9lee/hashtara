import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../models/hashtag_channel_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/hashtag_channel_provider.dart' as provider;
import 'hashtag_channel_detail_screen.dart';
import '../../models/user_model.dart';

// 네비게이션 락 상태 관리 프로바이더
final exploreScreenNavLockProvider = StateProvider<bool>((ref) => false);

// 구독 버튼 로딩 상태 관리 프로바이더
final subscriptionLoadingProvider = StateProvider.family<bool, String>((ref, channelId) => false);

class HashtagExploreScreen extends ConsumerStatefulWidget {
  const HashtagExploreScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HashtagExploreScreen> createState() => _HashtagExploreScreenState();
}

class _HashtagExploreScreenState extends ConsumerState<HashtagExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isNavigating = false; // 네비게이션 중복 방지 변수
  
  @override
  void initState() {
    super.initState();
    // 기본 검색어 초기화
    _performSearch('');
    
    // 화면 진입 시 네비게이션 락 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isNavigating = false;
      });
      ref.read(exploreScreenNavLockProvider.notifier).state = false;
      ref.read(channelDetailNavLockProvider.notifier).state = false;
    });
  }
  
  // 인기 채널 새로고침 및 게시물 수 업데이트
  void _refreshPopularChannels() {
    ref.invalidate(provider.popularHashtagChannelsProvider);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // 해시태그 검색 처리 최적화
  void _performSearch([String? query]) {
    final searchText = query ?? _searchController.text.trim();
    setState(() => _isSearching = searchText.isNotEmpty);
    ref.read(provider.hashtagSearchProvider.notifier).searchHashtags(searchText);
  }

  // 채널 탐색 시 안전한 네비게이션 처리
  void _navigateToChannelDetail(HashtagChannelModel channel) {
    // 이미 네비게이션 중이면 무시
    if (_isNavigating) {
      debugPrint('이미 네비게이션 진행 중 - 중복 방지');
      return;
    }

    // 네비게이션 락 설정
    setState(() {
      _isNavigating = true;
    });
    ref.read(exploreScreenNavLockProvider.notifier).state = true;

    try {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => HashtagChannelDetailScreen(
            channelId: channel.id,
            channelName: channel.name,
          ),
        ),
      ).then((_) {
        // 화면 복귀 시 데이터 새로고침 및 네비게이션 락 해제
        if (!_isSearching) {
          _refreshPopularChannels();
        }
        
        // 네비게이션 잠금 해제
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
          ref.read(exploreScreenNavLockProvider.notifier).state = false;
        }
      });
    } catch (e) {
      debugPrint('채널 상세 페이지 네비게이션 오류: $e');
      // 오류 발생 시에도 잠금 해제
      setState(() {
        _isNavigating = false;
      });
      ref.read(exploreScreenNavLockProvider.notifier).state = false;
    }
  }

  // 구독 버튼 클릭 핸들러 - 토글 기능 강화
  Future<void> _handleSubscription(String channelId) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      // 로그인 안 된 경우 처리
      _showLoginRequiredDialog();
      return;
    }

    // 중복 클릭 방지를 위한 로딩 상태 설정
    ref.read(subscriptionLoadingProvider(channelId).notifier).state = true;

    try {
      // 구독 상태에 따라 다른 메서드 호출
      final subKey = '${user.uid}:$channelId';
      final isSubscribed = ref.read(provider.channelSubscriptionProvider(subKey)).valueOrNull ?? false;
      
      final channelController = ref.read(provider.hashtagChannelControllerProvider.notifier);
      
      if (isSubscribed) {
        // 이미 구독 중이면 구독 해제
        debugPrint('채널 $channelId 구독 해제 시도');
        await channelController.unsubscribeFromChannel(user.uid, channelId);
        debugPrint('채널 $channelId 구독 해제 완료');
      } else {
        // 구독 중이 아니면 구독 추가
        debugPrint('채널 $channelId 구독 시도');
        await channelController.subscribeToChannel(user.uid, channelId);
        debugPrint('채널 $channelId 구독 완료');
      }
      
      // 구독 상태 캐시 무효화 (최신 상태 반영)
      ref.invalidate(provider.channelSubscriptionProvider(subKey));
    } catch (e) {
      debugPrint('구독 처리 오류: $e');
    } finally {
      // 로딩 상태 해제
      if (mounted) {
        ref.read(subscriptionLoadingProvider(channelId).notifier).state = false;
      }
    }
  }

  // 로그인 필요 다이얼로그
  void _showLoginRequiredDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('로그인 필요'),
        content: const Text('채널을 구독하려면 로그인이 필요합니다.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 검색 결과 상태 읽기
    final searchResults = ref.watch(provider.hashtagSearchProvider);
    
    // 인기 채널은 검색 중이 아닐 때만 로드
    final popularChannels = _isSearching 
        ? const AsyncValue<List<HashtagChannelModel>>.data([]) 
        : ref.watch(provider.popularHashtagChannelsProvider);
    
    // 네비게이션 락 상태 확인
    final isNavLocked = ref.watch(exploreScreenNavLockProvider) || _isNavigating;
    
    // 현재 사용자 정보
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: const Text(
          '해시태그 탐색',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 로딩 상태를 명확하게 표시
        trailing: _buildLoadingIndicator(popularChannels, searchResults, isNavLocked),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 검색 바
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                backgroundColor: AppColors.cardBackground,
                style: const TextStyle(color: AppColors.white),
                placeholder: '해시태그 검색 (예: #운동, #헬스)',
                placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                onSubmitted: (_) => _performSearch(),
                onChanged: (value) {
                  if (value.isEmpty) {
                    _performSearch('');
                  }
                },
                prefixIcon: const Icon(
                  CupertinoIcons.search,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: AppColors.textSecondary,
                ),
                enabled: !isNavLocked, // 네비게이션 중에는 검색 비활성화
              ),
            ),
            
            // 검색 결과 또는 인기 채널
            Expanded(
              child: _isSearching 
                ? _buildSearchResults(searchResults, isNavLocked, currentUser) 
                : _buildPopularChannels(popularChannels, isNavLocked, currentUser),
            ),
          ],
        ),
      ),
    );
  }
  
  // 로딩 상태 표시 위젯
  Widget? _buildLoadingIndicator(
    AsyncValue<List<HashtagChannelModel>> popularChannels,
    AsyncValue<List<HashtagChannelModel>> searchResults,
    bool isNavLocked) {
    
    // 현재 표시 중인 데이터에 따라 로딩 상태 확인
    final isCurrentlyLoading = _isSearching 
        ? searchResults.isLoading 
        : popularChannels.isLoading;
    
    if (isCurrentlyLoading || isNavLocked) {
      return const CupertinoActivityIndicator(
        radius: 10,
        color: AppColors.white,
      );
    } else {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _refreshPopularChannels,
        child: const Icon(
          CupertinoIcons.refresh,
          color: AppColors.white,
        ),
      );
    }
  }
  
  // 검색 결과 UI
  Widget _buildSearchResults(
    AsyncValue<List<HashtagChannelModel>> results, 
    bool isNavLocked,
    UserModel? currentUser
  ) {
    return results.when(
      data: (channels) {
        if (channels.isEmpty) {
          return const Center(
            child: Text(
              '검색 결과가 없습니다.\n새로운 해시태그 채널을 만들어보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textEmphasis,
                fontSize: 16,
              ),
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return _buildChannelListItem(channel, isNavLocked, currentUser);
          },
        );
      },
      loading: () => const Center(
        child: CupertinoActivityIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: AppColors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '검색 중 오류가 발생했습니다: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textEmphasis),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: isNavLocked ? null : () => _performSearch(_searchController.text),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
  
  // 인기 채널 UI
  Widget _buildPopularChannels(
    AsyncValue<List<HashtagChannelModel>> popularChannels, 
    bool isNavLocked,
    UserModel? currentUser
  ) {
    return popularChannels.when(
      data: (channels) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
              child: Text(
                '인기 해시태그 채널',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: channels.isEmpty
                ? const Center(
                    child: Text(
                      '아직 해시태그 채널이 없습니다.\n첫 번째 채널을 만들어보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textEmphasis,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      return _buildChannelListItem(channel, isNavLocked, currentUser);
                    },
                  ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CupertinoActivityIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: AppColors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '채널을 불러오는 중 오류가 발생했습니다: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textEmphasis),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: isNavLocked ? null : _refreshPopularChannels,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
  
  // 해시태그 채널 목록 아이템 위젯 - 구독 버튼 추가
  Widget _buildChannelListItem(
    HashtagChannelModel channel, 
    bool isNavLocked,
    UserModel? currentUser
  ) {
    return GestureDetector(
      onTap: isNavLocked 
        ? null 
        : () => _navigateToChannelDetail(channel),
      child: Opacity(
        opacity: isNavLocked ? 0.7 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: AppColors.separator, width: 0.5),
          ),
          child: Row(
            children: [
              // 채널 아이콘
              Container(
                width: 40.0,
                height: 40.0,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.number,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 채널 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${channel.name}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_2_fill,
                          color: AppColors.textSecondary,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '구독자 ${_formatCount(channel.followersCount)}명',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chat_bubble_2_fill,
                          color: AppColors.textSecondary,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '게시물 ${_formatCount(channel.postsCount)}개',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 구독 버튼 추가
              if (currentUser != null)
                _buildSubscribeButton(currentUser.id, channel.id, isNavLocked),
            ],
          ),
        ),
      ),
    );
  }
  
  // 구독 버튼 위젯 - 토글 기능 강화
  Widget _buildSubscribeButton(String userId, String channelId, bool isNavLocked) {
    // 구독 상태 조회를 위한 키
    final subKey = '$userId:$channelId';
    final subscriptionState = ref.watch(provider.channelSubscriptionProvider(subKey));
    final isLoading = ref.watch(subscriptionLoadingProvider(channelId));
    
    // 로딩 중이면 인디케이터 표시
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: CupertinoActivityIndicator(radius: 10),
      );
    }
    
    return subscriptionState.when(
      data: (isSubscribed) {
        return CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: isNavLocked ? null : () => _handleSubscription(channelId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSubscribed ? AppColors.cardBackground : AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSubscribed ? AppColors.primaryPurple : const Color(0x00000000), // 투명색
                width: 1,
              ),
            ),
            child: Text(
              isSubscribed ? '구독 중' : '구독하기',
              style: TextStyle(
                color: isSubscribed ? AppColors.primaryPurple : AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: CupertinoActivityIndicator(radius: 10),
      ),
      error: (_, __) => CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 0,
        onPressed: isNavLocked ? null : () => _handleSubscription(channelId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            '구독하기',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}