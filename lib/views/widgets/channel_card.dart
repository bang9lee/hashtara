import 'package:flutter/cupertino.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // 사용하지 않는 임포트 제거
import '../../../constants/app_colors.dart';
import '../../../models/hashtag_channel_model.dart';

class ChannelCard extends StatelessWidget {
  final HashtagChannelModel channel;
  final VoidCallback onTap;
  final VoidCallback? onSubscribe;
  final VoidCallback? onUnsubscribe;
  final bool isSubscribed;

  const ChannelCard({
    Key? key,
    required this.channel,
    required this.onTap,
    this.onSubscribe,
    this.onUnsubscribe,
    this.isSubscribed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: AppColors.separator,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 채널 커버 이미지
            if (channel.coverImageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  topRight: Radius.circular(12.0),
                ),
                child: SizedBox(
                  height: 120,
                  child: Image.network(
                    channel.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        color: AppColors.primaryPurple,
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.number, // hashtag 대신 number 아이콘 사용
                            color: AppColors.white,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.0),
                    topRight: Radius.circular(12.0),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.number, // hashtag 대신 number 아이콘 사용
                    color: AppColors.white,
                    size: 40,
                  ),
                ),
              ),
              
            // 채널 정보
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#${channel.name}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // 구독 버튼
                      if (onSubscribe != null || onUnsubscribe != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: isSubscribed ? onUnsubscribe : onSubscribe,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 6.0,
                            ),
                            decoration: BoxDecoration(
                              color: isSubscribed
                                  ? AppColors.primaryPurple.withAlpha(50)
                                  : AppColors.primaryPurple,
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Text(
                              isSubscribed ? '구독중' : '구독하기',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (channel.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      channel.description!,
                      style: const TextStyle(
                        color: AppColors.textEmphasis,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
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