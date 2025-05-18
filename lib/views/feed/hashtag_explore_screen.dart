import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/hashtag_channel_provider.dart';
import '../../../models/hashtag_channel_model.dart';
import 'hashtag_channel_detail_screen.dart';
import '../widgets/channel_card.dart';

class HashtagExploreScreen extends ConsumerStatefulWidget {
  const HashtagExploreScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HashtagExploreScreen> createState() => _HashtagExploreScreenState();
}

class _HashtagExploreScreenState extends ConsumerState<HashtagExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    // 기본 검색어 초기화
    _performSearch('');
    
    // 인기 채널의 게시물 수 업데이트 (추가된 부분)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPopularChannels();
    });
  }
  
  // 인기 채널 새로고침 및 게시물 수 업데이트 (추가된 부분)
  void _refreshPopularChannels() {
    ref.invalidate(popularHashtagChannelsProvider);
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
    ref.read(hashtagSearchProvider.notifier).searchHashtags(searchText);
  }

  @override
  Widget build(BuildContext context) {
    // 검색 결과 상태 읽기
    final searchResults = ref.watch(hashtagSearchProvider);
    
    // 인기 채널은 검색 중이 아닐 때만 로드 (Future로 변경)
    final popularChannels = _isSearching 
        ? const AsyncValue<List<HashtagChannelModel>>.data([]) 
        : ref.watch(popularHashtagChannelsProvider);
    
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
        trailing: _buildLoadingIndicator(popularChannels, searchResults),
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
              ),
            ),
            
            // 검색 결과 또는 인기 채널
            Expanded(
              child: _isSearching ? _buildSearchResults(searchResults) : _buildPopularChannels(popularChannels),
            ),
          ],
        ),
      ),
    );
  }
  
  // 로딩 상태 표시 위젯
  Widget? _buildLoadingIndicator(
    AsyncValue<List<HashtagChannelModel>> popularChannels,
    AsyncValue<List<HashtagChannelModel>> searchResults) {
    
    // 현재 표시 중인 데이터에 따라 로딩 상태 확인
    final isCurrentlyLoading = _isSearching 
        ? searchResults.isLoading 
        : popularChannels.isLoading;
    
    if (isCurrentlyLoading) {
      return const CupertinoActivityIndicator(
        radius: 10,
        color: AppColors.white,
      );
    } else {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _refreshPopularChannels, // 새로고침 버튼 추가 (수정된 부분)
        child: const Icon(
          CupertinoIcons.refresh,
          color: AppColors.white,
        ),
      );
    }
  }
  
  // 검색 결과 UI
  Widget _buildSearchResults(AsyncValue<List<HashtagChannelModel>> results) {
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
            return _buildChannelListItem(channel);
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
              onPressed: () => _performSearch(_searchController.text),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
  
  // 인기 채널 UI - Future 버전으로 변경
  Widget _buildPopularChannels(AsyncValue<List<HashtagChannelModel>> popularChannels) {
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
                : Material( // Material 위젯 추가
                    color: Colors.transparent,
                    child: RefreshIndicator(
                      onRefresh: () async {
                        _refreshPopularChannels();
                      },
                      color: AppColors.primaryPurple,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final channel = channels[index];
                          return _buildChannelListItem(channel);
                        },
                      ),
                    ),
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
              onPressed: _refreshPopularChannels,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
  
  // 해시태그 채널 목록 아이템 위젯
  Widget _buildChannelListItem(HashtagChannelModel channel) {
    // 메모이제이션으로 개선된 ChannelCard 사용
    final key = ValueKey(channel.id); // 고유 키 사용으로 재사용성 향상
    return ChannelCard(
      key: key,
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
        ).then((_) {
          // 화면 복귀 시 데이터 새로고침 (수정된 부분)
          if (!_isSearching) {
            _refreshPopularChannels();
          }
        });
      },
      isCompact: true,
    );
  }
}