import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
import '../../../models/hashtag_channel_model.dart';
import 'hashtag_channel_detail_screen.dart';
import '../widgets/channel_card.dart';

class SubscribedChannelsScreen extends ConsumerStatefulWidget {
  const SubscribedChannelsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscribedChannelsScreen> createState() => _SubscribedChannelsScreenState();
}

class _SubscribedChannelsScreenState extends ConsumerState<SubscribedChannelsScreen> {
  // 화면 로드 시 자동 새로고침 여부
  bool _initialRefreshDone = false;
  
  @override
  void initState() {
    super.initState();
    // 화면 생성 후 다음 프레임에서 실행 (build 이후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialRefreshDone) {
        _refreshChannels();
        _initialRefreshDone = true;
      }
    });
  }
  
  // 구독 채널 새로고침
  void _refreshChannels() {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser != null) {
      // 이미 로그인된 경우만 새로고침
      ref.invalidate(userSubscribedChannelsProvider(currentUser.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SubscribedChannelsScreen 빌드');
    final currentUser = ref.watch(currentUserProvider);
    
    // 사용자가 구독한 해시태그 채널 - 조건부 로드
    final subscribedChannels = currentUser.maybeWhen(
      data: (user) {
        if (user != null) {
          debugPrint('사용자 ${user.id}의 구독 채널 로드');
          return ref.watch(userSubscribedChannelsProvider(user.id));
        } else {
          debugPrint('로그인된 사용자가 없습니다');
          return const AsyncValue<List<HashtagChannelModel>>.data([]);
        }
      },
      orElse: () {
        debugPrint('currentUserProvider이 데이터가 아님');
        return const AsyncValue<List<HashtagChannelModel>>.data([]);
      },
    );
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: const Text(
          '내 구독 채널',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: AppColors.white),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _refreshChannels,
          child: const Icon(
            CupertinoIcons.refresh,
            color: AppColors.white,
          ),
        ),
      ),
      child: SafeArea(
        child: _buildSubscribedChannelsList(subscribedChannels),
      ),
    );
  }
  
  Widget _buildSubscribedChannelsList(AsyncValue<List<HashtagChannelModel>>? subscribedChannels) {
    // 구독 채널이 null인 경우 (로그인되지 않은 경우) 빈 화면 표시
    if (subscribedChannels == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 60,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              '로그인이 필요합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textEmphasis,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return subscribedChannels.when(
      data: (channels) {
        if (channels.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.number,
                  size: 60,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 16),
                Text(
                  '아직 구독한 채널이 없습니다.\n관심있는 해시태그를 탐색해보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textEmphasis,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        
        return Material( // Material 위젯 추가
          color: Colors.transparent,
          child: RefreshIndicator(
            onRefresh: () async {
              _refreshChannels();
            },
            color: AppColors.primaryPurple,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return ChannelCard(
                  key: ValueKey(channel.id),
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
                      _refreshChannels();
                    });
                  },
                );
              },
            ),
          ),
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
              onPressed: _refreshChannels,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}