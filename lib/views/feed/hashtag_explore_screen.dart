import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
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
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // 기본적으로 인기 해시태그 채널을 로드
      ref.read(hashtagSearchProvider.notifier).searchHashtags('');
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // 해시태그 검색 처리
  void _handleSearch() {
    final query = _searchController.text.trim();
    ref.read(hashtagSearchProvider.notifier).searchHashtags(query);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final popularChannels = ref.watch(popularHashtagChannelsProvider);
    final searchResults = ref.watch(hashtagSearchProvider);
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: Text(
          '해시태그 탐색',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                onSubmitted: (_) => _handleSearch(),
                onChanged: (value) {
                  if (value.isEmpty) {
                    ref.read(hashtagSearchProvider.notifier).searchHashtags('');
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
              child: searchResults.when(
                data: (channels) {
                  if (_searchController.text.isNotEmpty && channels.isEmpty) {
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
                  
                  // 검색 결과가 있으면 표시
                  if (_searchController.text.isNotEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        return _buildChannelListItem(channel, user);
                      },
                    );
                  } else {
                    // 검색어가 없으면 인기 채널 표시
                    return popularChannels.when(
                      data: (popularList) {
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
                              child: popularList.isEmpty
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
                                      itemCount: popularList.length,
                                      itemBuilder: (context, index) {
                                        final channel = popularList[index];
                                        return _buildChannelListItem(channel, user);
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(
                        child: CupertinoActivityIndicator(),
                      ),
                      error: (_, __) => const Center(
                        child: Text(
                          '채널을 불러오는 중 오류가 발생했습니다.',
                          style: TextStyle(color: AppColors.textEmphasis),
                        ),
                      ),
                    );
                  }
                },
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (_, __) => const Center(
                  child: Text(
                    '검색 중 오류가 발생했습니다.',
                    style: TextStyle(color: AppColors.textEmphasis),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 해시태그 채널 목록 아이템 위젯
  Widget _buildChannelListItem(HashtagChannelModel channel, AsyncValue<dynamic> user) {
    return ChannelCard(
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
      onSubscribe: user.whenOrNull(
        data: (userData) => userData != null
            ? () {
                ref.read(hashtagChannelControllerProvider.notifier).subscribeToChannel(
                  userData.id,
                  channel.id,
                );
              }
            : null,
      ),
      onUnsubscribe: user.whenOrNull(
        data: (userData) => userData != null
            ? () {
                ref.read(hashtagChannelControllerProvider.notifier).unsubscribeFromChannel(
                  userData.id,
                  channel.id,
                );
              }
            : null,
      ),
    );
  }
}