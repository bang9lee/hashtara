import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../models/post_model.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
import '../widgets/user_avatar.dart';
import '../../views/profile/profile_screen.dart';
import '../../views/feed/hashtag_channel_detail_screen.dart';
import '../../views/feed/hashtag_explore_screen.dart';
import '../feed/photo_view_screen.dart';


class PostCardDetailed extends ConsumerStatefulWidget {
  final PostModel post;

  const PostCardDetailed({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  ConsumerState<PostCardDetailed> createState() => _PostCardDetailedState();
}

class _PostCardDetailedState extends ConsumerState<PostCardDetailed> {
  @override
  Widget build(BuildContext context) {
    // 게시물 작성자 정보 가져오기
    final userFuture = ref.watch(getUserProfileProvider(widget.post.userId));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 게시물 헤더 (작성자 정보)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: userFuture.when(
              data: (user) => Row(
                children: [
                  UserAvatar(
                    imageUrl: user?.profileImageUrl,
                    onTap: () {
                      // 프로필 화면으로 이동
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ProfileScreen(
                            userId: widget.post.userId,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user?.name ?? 'Unknown',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            // 시간 표시 - 이름 옆으로 이동
                            Text(
                              _formatTimestamp(widget.post.createdAt),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (user?.username != null)
                          Text(
                            '@${user!.username}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const Center(
                child: CupertinoActivityIndicator(),
              ),
              error: (_, __) => const Text(
                '사용자 정보를 불러올 수 없습니다.',
                style: TextStyle(color: AppColors.textEmphasis),
              ),
            ),
          ),

          // 게시물 내용 먼저 표시 (요청대로 내용/사진 순서 변경)
          if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Text(
                widget.post.caption!,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                ),
              ),
            ),

          // 내용 다음에 이미지 표시
          if (widget.post.imageUrls != null &&
              widget.post.imageUrls!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: SizedBox(
                width: double.infinity,
                height: 300,
                child: PageView.builder(
                  itemCount: widget.post.imageUrls!.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        // 이미지 클릭 시 이미지 확대 화면으로 이동
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => PhotoViewScreen(
                              imageUrl: widget.post.imageUrls![index],
                              initialIndex: index,
                              imageUrls: widget.post.imageUrls!,
                            ),
                          ),
                        );
                      },
                      child: Image.network(
                        widget.post.imageUrls![index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return const Center(
                            child: CupertinoActivityIndicator(),
                          );
                        },
                        errorBuilder: (context, url, error) => const Center(
                          child: Icon(
                            CupertinoIcons.photo,
                            size: 50,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 위치 정보
          if (widget.post.location != null && widget.post.location!.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.location,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.post.location!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // 해시태그 - 클릭 가능하게 수정
          if (widget.post.hashtags != null && widget.post.hashtags!.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Wrap(
                spacing: 8.0,
                children: widget.post.hashtags!.map((tag) {
                  return GestureDetector(
                    onTap: () => _handleHashtagTap(tag),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: AppColors.secondaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // 액션 버튼들 (공유)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              children: [
                // 공유 버튼
                GestureDetector(
                  onTap: () {
                    _showShareOptions(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      CupertinoIcons.share,
                      color: AppColors.textEmphasis,
                      size: 24,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 해시태그 눌렀을 때 해시태그 채널로 이동
  void _handleHashtagTap(String hashtag) async {
    // # 기호 제거
    final tagName = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    
    try {
      // 해시태그 채널 검색
      final channelRepository = ref.read(hashtagChannelRepositoryProvider);
      final channels = await channelRepository.searchChannels(tagName);
      
      if (!mounted) return;
      
      // 동일한 이름의 채널이 있으면 바로 이동
      final matchedChannel = channels.where(
        (channel) => channel.name.toLowerCase() == tagName.toLowerCase()
      ).toList();
      
      if (!mounted) return;
      
      if (matchedChannel.isNotEmpty) {
        // 일치하는 채널이 있으면 바로 상세 페이지로 이동
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => HashtagChannelDetailScreen(
              channelId: matchedChannel.first.id,
              channelName: matchedChannel.first.name,
            ),
          ),
        );
      } else {
        // 일치하는 채널이 없으면 검색 화면으로 이동
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const HashtagExploreScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      // 오류 발생 시 검색 화면으로 이동
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => const HashtagExploreScreen(),
        ),
      );
    }
  }

  // 게시 시간 포맷팅
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}년 전';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}개월 전';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  // 공유 옵션 표시
  void _showShareOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('공유하기'),
        message: const Text('이 게시물을 공유할 앱을 선택하세요'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _shareImage(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: CupertinoColors.systemBlue),
                SizedBox(width: 8),
                Text('이미지로 공유'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _shareContent(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_text,
                    color: CupertinoColors.systemBlue),
                SizedBox(width: 8),
                Text('텍스트로 공유'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }

  // 이미지로 공유 (사진이 있는 경우)
  void _shareImage(BuildContext context) {
    // 구현은 PostCard와 동일
    _showShareSuccessToast(context, '이미지 공유 준비 중...');
  }

  // 텍스트 내용으로 공유
  void _shareContent(BuildContext context) {
    // 구현은 PostCard와 동일
    _showShareSuccessToast(context, '텍스트 공유 준비 중...');
  }

  // 공유 성공 토스트 메시지
  void _showShareSuccessToast(BuildContext context, String message) {
    // 토스트 메시지 표시
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;

    final toast = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.black.withAlpha(179),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(toast);

    // 2초 후 토스트 메시지 제거
    Future.delayed(const Duration(seconds: 2), () {
      toast.remove();
    });
  }
}