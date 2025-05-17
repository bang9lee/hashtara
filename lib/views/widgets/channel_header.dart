import 'package:flutter/cupertino.dart';
import '../../../constants/app_colors.dart';
import '../../../models/hashtag_channel_model.dart';

class ChannelHeader extends StatelessWidget {
  final HashtagChannelModel channel;
  final bool isSubscribed;
  final VoidCallback onSubscribe;

  const ChannelHeader({
    Key? key,
    required this.channel,
    required this.isSubscribed,
    required this.onSubscribe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(
            color: AppColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 채널 아이콘
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.number, // hashtag 대신 number 아이콘 사용
                    color: AppColors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 채널 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${channel.name}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_2_fill,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '구독자 ${_formatCount(channel.followersCount)}명',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          CupertinoIcons.chat_bubble_2_fill,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '게시물 ${_formatCount(channel.postsCount)}개',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (channel.description != null) ...[
            const SizedBox(height: 16),
            Text(
              channel.description!,
              style: const TextStyle(
                color: AppColors.textEmphasis,
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 구독 버튼
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: isSubscribed ? AppColors.cardBackground : AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(12),
              onPressed: onSubscribe,
              child: Text(
                isSubscribed ? '구독중' : '구독하기',
                style: TextStyle(
                  color: isSubscribed ? AppColors.primaryPurple : AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 숫자를 포매팅 (예: 1000 -> 1K)
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}