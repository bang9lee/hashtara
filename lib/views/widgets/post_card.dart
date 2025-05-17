import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../models/post_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../profile/profile_screen.dart';

class PostCard extends ConsumerWidget {
  final PostModel post;
  final VoidCallback? onProfileTap;

  const PostCard({
    Key? key,
    required this.post,
    this.onProfileTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 게시물 작성자 정보 가져오기
    final userFuture = ref.watch(getUserProfileProvider(post.userId));
    final currentUserAsync = ref.watch(currentUserProvider);
    
    // 좋아요 상태 가져오기
    final likeStatusAsync = currentUserAsync.when(
      data: (currentUser) => currentUser != null
          ? ref.watch(postLikeStatusProvider({'postId': post.id, 'userId': currentUser.id}))
          : const AsyncValue.data(false),
      loading: () => const AsyncValue.data(false),
      error: (_, __) => const AsyncValue.data(false),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
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
                    onTap: onProfileTap ?? () {
                      // 프로필 화면으로 이동
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ProfileScreen(
                            userId: post.userId,
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
                        Text(
                          user?.name ?? 'Unknown',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
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
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      // 게시물 옵션 메뉴
                      showCupertinoModalPopup(
                        context: context,
                        builder: (context) => CupertinoActionSheet(
                          title: const Text('게시물 옵션'),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.pop(context);
                                // 신고 처리
                              },
                              child: const Text('신고하기'),
                            ),
                            if (currentUserAsync.value?.id == post.userId)
                              CupertinoActionSheetAction(
                                isDestructiveAction: true,
                                onPressed: () {
                                  Navigator.pop(context);
                                  // 삭제 처리
                                },
                                child: const Text('삭제하기'),
                              ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('취소'),
                          ),
                        ),
                      );
                    },
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      color: AppColors.textEmphasis,
                      size: 20,
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

          // 게시물 이미지
          if (post.imageUrls != null && post.imageUrls!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 300,
              child: PageView.builder(
                itemCount: post.imageUrls!.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    post.imageUrls![index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const Center(
                        child: CupertinoActivityIndicator(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 50,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  );
                },
              ),
            ),

          // 게시물 액션 버튼들 (좋아요, 댓글, 공유)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                // 좋아요 버튼
                likeStatusAsync.when(
                  data: (isLiked) => CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      currentUserAsync.whenData((currentUser) {
                        if (currentUser != null) {
                          ref
                              .read(postControllerProvider.notifier)
                              .toggleLike(post.id, currentUser.id);
                        }
                      });
                    },
                    child: Icon(
                      isLiked
                          ? CupertinoIcons.heart_fill
                          : CupertinoIcons.heart,
                      color: isLiked
                          ? CupertinoColors.systemRed
                          : AppColors.textEmphasis,
                      size: 24,
                    ),
                  ),
                  loading: () => const Icon(
                    CupertinoIcons.heart,
                    color: AppColors.textEmphasis,
                    size: 24,
                  ),
                  error: (_, __) => const Icon(
                    CupertinoIcons.heart,
                    color: AppColors.textEmphasis,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 4),
                if (post.likesCount > 0)
                  Text(
                    post.likesCount.toString(),
                    style: const TextStyle(
                      color: AppColors.textEmphasis,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(width: 16),

                // 댓글 버튼
                const Icon(
                  CupertinoIcons.chat_bubble,
                  color: AppColors.textEmphasis,
                  size: 24,
                ),
                const SizedBox(width: 4),
                if (post.commentsCount > 0)
                  Text(
                    post.commentsCount.toString(),
                    style: const TextStyle(
                      color: AppColors.textEmphasis,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(width: 16),

                // 공유 버튼
                const Icon(
                  CupertinoIcons.share,
                  color: AppColors.textEmphasis,
                  size: 24,
                ),
                const Spacer(),

                // 북마크 버튼
                const Icon(
                  CupertinoIcons.bookmark,
                  color: AppColors.textEmphasis,
                  size: 24,
                ),
              ],
            ),
          ),

          // 게시물 내용
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Text(
                post.caption!,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                ),
              ),
            ),

          // 위치 정보
          if (post.location != null && post.location!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.location,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    post.location!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // 해시태그
          if (post.hashtags != null && post.hashtags!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Wrap(
                spacing: 8.0,
                children: post.hashtags!.map((tag) {
                  return Text(
                    tag,
                    style: const TextStyle(
                      color: AppColors.secondaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ),

          // 게시 시간
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              _formatTimestamp(post.createdAt),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
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
}

// UserAvatar 클래스 정의
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    this.size = 40.0,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          shape: BoxShape.circle,
          image: imageUrl != null && imageUrl!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          border: Border.all(
            color: AppColors.separator,
            width: 1.0,
          ),
        ),
        child: imageUrl == null || imageUrl!.isEmpty
            ? Icon(
                CupertinoIcons.person_fill,
                size: size * 0.5,
                color: AppColors.textSecondary,
              )
            : null,
      ),
    );
  }
}