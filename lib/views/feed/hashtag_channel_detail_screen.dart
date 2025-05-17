import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
// import '../../../providers/feed_provider.dart'; // 사용하지 않는 import 제거
import '../widgets/post_card.dart';
import '../widgets/channel_header.dart';

class HashtagChannelDetailScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String channelName;
  
  const HashtagChannelDetailScreen({
    Key? key,
    required this.channelId,
    required this.channelName,
  }) : super(key: key);

  @override
  ConsumerState<HashtagChannelDetailScreen> createState() => _HashtagChannelDetailScreenState();
}

class _HashtagChannelDetailScreenState extends ConsumerState<HashtagChannelDetailScreen> {
  bool _isSubscribed = false;
  
  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }
  
  // 채널 구독 상태 확인
  void _checkSubscriptionStatus() async {
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      // 구독 상태 확인 로직 구현
      final subscribedChannels = await ref.read(userSubscribedChannelsProvider(user.id).future);
      if (mounted) {
        setState(() {
          _isSubscribed = subscribedChannels.any((channel) => channel.id == widget.channelId);
        });
      }
    }
  }
  
  // 구독 상태 토글
  void _toggleSubscription() {
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      if (_isSubscribed) {
        ref.read(hashtagChannelControllerProvider.notifier).unsubscribeFromChannel(
          user.id,
          widget.channelId,
        );
      } else {
        ref.read(hashtagChannelControllerProvider.notifier).subscribeToChannel(
          user.id,
          widget.channelId,
        );
      }
      setState(() {
        _isSubscribed = !_isSubscribed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelAsync = ref.watch(hashtagChannelProvider(widget.channelId));
    final currentUser = ref.watch(currentUserProvider);
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: Text(
          '#${widget.channelName}',
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(
            CupertinoIcons.back,
            color: AppColors.white,
          ),
        ),
        trailing: currentUser.whenOrNull(
          data: (user) => user != null
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _toggleSubscription,
                  child: Icon(
                    _isSubscribed
                        ? CupertinoIcons.bell_fill
                        : CupertinoIcons.bell,
                    color: AppColors.white,
                  ),
                )
              : null,
        ),
      ),
      child: SafeArea(
        child: channelAsync.when(
          data: (channel) {
            if (channel == null) {
              return const Center(
                child: Text(
                  '채널을 찾을 수 없습니다.',
                  style: TextStyle(color: AppColors.textEmphasis),
                ),
              );
            }
            
            // 채널 스트림 프로바이더 생성
            final channelPostsStream = ref.watch(
              StreamProvider((ref) {
                final repository = ref.watch(hashtagChannelRepositoryProvider);
                return repository.getChannelPosts(widget.channelId);
              }),
            );
            
            return Column(
              children: [
                // 채널 헤더
                ChannelHeader(
                  channel: channel,
                  isSubscribed: _isSubscribed,
                  onSubscribe: _toggleSubscription,
                ),
                
                // 채널 게시물
                Expanded(
                  child: channelPostsStream.when(
                    data: (posts) {
                      if (posts.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.photo,
                                size: 60,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '이 채널에는 아직 게시물이 없습니다.\n첫 번째 게시물을 작성해보세요!',
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
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: PostCard(
                              post: post,
                              onProfileTap: () {
                                // 프로필 페이지로 이동
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CupertinoActivityIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Text(
                        '게시물을 불러오는 중 오류가 발생했습니다: $error',
                        style: const TextStyle(color: AppColors.textEmphasis),
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
          error: (error, _) => Center(
            child: Text(
              '채널 정보를 불러오는 중 오류가 발생했습니다: $error',
              style: const TextStyle(color: AppColors.textEmphasis),
            ),
          ),
        ),
      ),
    );
  }
}