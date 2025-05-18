import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../models/hashtag_channel_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
import 'package:flutter/material.dart';

class ChannelHeader extends ConsumerWidget {
  final HashtagChannelModel channel;
  final bool showSubscribeButton;
  
  const ChannelHeader({
    Key? key,
    required this.channel,
    this.showSubscribeButton = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 채널 정보 표시
          Row(
            children: [
              _buildChannelAvatar(),
              const SizedBox(width: 12),
              Expanded(child: _buildChannelInfo()),
              // 구독 버튼 - 사용자가 로그인한 경우만 표시
              if (showSubscribeButton && currentUser != null)
                _buildSubscribeButton(ref, '${currentUser.id}:${channel.id}'), // 문자열 형태로 키 전달
            ],
          ),
          // 채널 설명
          if (channel.description != null && channel.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              channel.description!,
              style: const TextStyle(color: AppColors.textEmphasis, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildChannelAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primaryPurple,
        shape: BoxShape.circle,
        image: channel.coverImageUrl != null
            ? DecorationImage(
                image: NetworkImage(channel.coverImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: channel.coverImageUrl == null
          ? const Center(
              child: Icon(CupertinoIcons.number, color: AppColors.white, size: 24),
            )
          : null,
    );
  }
  
  Widget _buildChannelInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${channel.name}',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              CupertinoIcons.person_2_fill,
              color: AppColors.textSecondary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '구독자 ${_formatCount(channel.followersCount)}명',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(width: 16),
            const Icon(
              CupertinoIcons.chat_bubble_2_fill,
              color: AppColors.textSecondary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '게시물 ${_formatCount(channel.postsCount)}개',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSubscribeButton(WidgetRef ref, String subscriptionKey) {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return const SizedBox.shrink();
    
    final subscriptionState = ref.watch(channelSubscriptionProvider(subscriptionKey));
    final channelController = ref.watch(hashtagChannelControllerProvider);
    
    final isLoading = subscriptionState.isLoading || channelController.isLoading;
    
    return subscriptionState.when(
      data: (isSubscribed) {
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: isLoading
              ? null
              : () {
                  if (isSubscribed) {
                    ref.read(hashtagChannelControllerProvider.notifier)
                       .unsubscribeFromChannel(userId, channel.id);
                  } else {
                    ref.read(hashtagChannelControllerProvider.notifier)
                       .subscribeToChannel(userId, channel.id);
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSubscribed
                  ? AppColors.cardBackground
                  : AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSubscribed
                    ? AppColors.primaryPurple
                    : Colors.transparent,
              ),
            ),
            child: isLoading
                ? const CupertinoActivityIndicator(radius: 8)
                : Text(
                    isSubscribed ? '구독 중' : '구독하기',
                    style: TextStyle(
                      color: isSubscribed
                          ? AppColors.primaryPurple
                          : AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
      loading: () => const CupertinoActivityIndicator(radius: 10),
      error: (_, __) => const Icon(
        CupertinoIcons.exclamationmark_circle,
        color: CupertinoColors.systemRed,
        size: 20,
      ),
    );
  }
  
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}