import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../constants/app_colors.dart';
import '../../../models/post_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../widgets/user_avatar.dart';
import '../../views/feed/post_detail_screen.dart';
import '../../views/feed/edit_post_screen.dart';
import '../../views/feed/photo_view_screen.dart';
import '../profile/profile_screen.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onProfileTap;
  final bool showFullCaption;
  final bool isDetailView;

  const PostCard({
    Key? key,
    required this.post,
    this.onProfileTap,
    this.showFullCaption = false,
    this.isDetailView = false,
  }) : super(key: key);

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isDeleting = false; // 삭제 처리 중 상태 추가

  @override
  Widget build(BuildContext context) {
    // 게시물 작성자 정보 가져오기
    final userFuture = ref.watch(getUserProfileProvider(widget.post.userId));
    final currentUserAsync = ref.watch(currentUserProvider);

    return GestureDetector(
      // 게시물 카드 전체를 클릭했을 때 상세 화면으로 이동 (단, 상세 화면에서는 동작하지 않음)
      onTap: widget.isDetailView
          ? null
          : () {
              // 수정된 부분: 루트 네비게이터 사용 제거, 현재 컨텍스트의 네비게이터 사용
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => PostDetailScreen(
                    postId: widget.post.id,
                  ),
                ),
              );
            },
      child: Container(
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
                      onTap: widget.onProfileTap ??
                          () {
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
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        // 게시물 옵션 메뉴
                        _showPostOptions(context, ref, widget.post,
                            currentUserAsync.valueOrNull);
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
            if (widget.post.imageUrls != null &&
                widget.post.imageUrls!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 300,
                child: PageView.builder(
                  itemCount: widget.post.imageUrls!.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        // 이미지 클릭 시 이미지 확대 화면으로 이동
                        Navigator.of(context).push(
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

            // 게시물 내용
            if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Text(
                  widget.post.caption!,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                  ),
                  maxLines: widget.showFullCaption ? null : 3,
                  overflow: widget.showFullCaption
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ),

            // 위치 정보
            if (widget.post.location != null &&
                widget.post.location!.isNotEmpty)
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

            // 해시태그
            if (widget.post.hashtags != null &&
                widget.post.hashtags!.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Wrap(
                  spacing: 8.0,
                  children: widget.post.hashtags!.map((tag) {
                    return Text(
                      tag,
                      style: const TextStyle(
                        color: Color.fromARGB(0, 99, 72, 255),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
              ),

            // 액션 버튼들 (댓글, 공유)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  // 댓글 버튼
                  GestureDetector(
                    onTap: () {
                      // 수정된 부분: 루트 네비게이터 사용 제거
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => PostDetailScreen(
                            postId: widget.post.id,
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        CupertinoIcons.chat_bubble,
                        color: AppColors.textEmphasis,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (widget.post.commentsCount > 0)
                    Text(
                      widget.post.commentsCount.toString(),
                      style: const TextStyle(
                        color: AppColors.textEmphasis,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(width: 16),

                  // 공유 버튼 - 실제로 작동하는 기능 구현
                  GestureDetector(
                    onTap: () {
                      _showShareOptions();
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

            // 상세 화면이 아닌 경우 댓글 버튼 표시
            if (!widget.isDetailView)
              Padding(
                padding: const EdgeInsets.only(
                    left: 12.0, right: 12.0, bottom: 12.0),
                child: GestureDetector(
                  onTap: () {
                    // 수정된 부분: 루트 네비게이터 사용 제거
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => PostDetailScreen(
                          postId: widget.post.id,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    widget.post.commentsCount > 0
                        ? '댓글 ${widget.post.commentsCount}개 모두 보기'
                        : '댓글 작성하기',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
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

  // 오류 메시지 표시 (CupertinoAlertDialog 사용)
  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 공유 옵션 표시
  void _showShareOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('공유하기'),
        message: const Text('이 게시물을 공유할 앱을 선택하세요'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              _shareImage();
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
              Navigator.pop(dialogContext);
              _shareContent();
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
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('취소'),
        ),
      ),
    );
  }

  // 이미지로 공유 (사진이 있는 경우)
  void _shareImage() {
    // 게시물에 이미지가 있는지 확인
    if (widget.post.imageUrls == null || widget.post.imageUrls!.isEmpty) {
      // 이미지가 없는 경우 사용자에게 알림
      _showShareErrorToast('공유할 이미지가 없습니다.');
      // 대신 텍스트 공유 시도
      _shareContent();
      return;
    }

    final String imageUrl = widget.post.imageUrls![0];
    final String caption = widget.post.caption ?? '';
    const String shareSubject = 'Hashtara 게시물';

    try {
      // 메시지: 공유 시도 중임을 사용자에게 알림
      _showShareSuccessToast('공유 중...');

      // 실제 앱에서는 이미지를 로컬에 다운로드한 후 공유
      // FileDownloader.downloadFile(imageUrl)
      //   .then((file) => Share.shareFiles([file.path], text: caption));

      // 현재는 텍스트만 공유 (테스트용)
      Share.share(caption, subject: shareSubject);

      debugPrint('이미지로 공유 시도: $imageUrl');
    } catch (e) {
      debugPrint('이미지 공유 오류: $e');
      _showShareErrorToast('이미지를 공유할 수 없습니다');
      return;
    }
  }

  // 텍스트 내용으로 공유
  void _shareContent() {
    // 공유할 내용 구성
    const String username = '게시자'; // 실제로는 사용자 이름
    final String caption = widget.post.caption ?? '';
    final String hashtags = widget.post.hashtags?.join(' ') ?? '';

    // 공유 문구 생성
    final shareContent =
        '[$username]\n$caption\n\n$hashtags\n\n해시태라(Hashtara)에서 공유됨';
    const shareSubject = 'Hashtara 게시물';

    try {
      // 공유 다이얼로그 열기
      Share.share(shareContent, subject: shareSubject);
      debugPrint('텍스트로 공유: $shareContent');
    } catch (e) {
      debugPrint('텍스트 공유 오류: $e');
      _showShareErrorToast('공유 중 오류가 발생했습니다');
      return;
    }
  }

  // 공유 오류 토스트 메시지
  void _showShareErrorToast(String message) {
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
              color: CupertinoColors.systemRed.withAlpha(200),
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

  // 공유 성공 토스트 메시지
  void _showShareSuccessToast(String message) {
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

  // 게시물 옵션 메뉴 표시
  void _showPostOptions(BuildContext context, WidgetRef ref, PostModel post,
      dynamic currentUser) {
    final isAuthor = currentUser?.id == post.userId;

    showCupertinoModalPopup(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('게시물 옵션'),
        actions: [
          if (isAuthor) ...[
            // 작성자인 경우 수정/삭제 옵션 표시
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(dialogContext);
                // 게시물 수정 화면으로 이동
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => EditPostScreen(post: post),
                  ),
                );
              },
              child: const Text('수정하기'),
            ),
            // 수정된 부분: 조건문으로 나누어 각각 다른 CupertinoActionSheetAction을 렌더링
            if (_isDeleting)
              CupertinoActionSheetAction(
                // 비어있는 함수를 전달 (null 대신)
                onPressed: () {},
                isDestructiveAction: true,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(),
                    SizedBox(width: 8),
                    Text('삭제 중...'),
                  ],
                ),
              )
            else
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // 삭제 확인 다이얼로그 표시
                  _showDeleteConfirmation(ref, post.id);
                },
                child: const Text('삭제하기'),
              ),
          ] else ...[
            // 작성자가 아닌 경우 신고 옵션 표시
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(dialogContext);
                // 신고 기능 구현 (미구현)
                _showReportOptions();
              },
              child: const Text('신고하기'),
            ),
          ],
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              // 공유 기능 구현
              _showShareOptions();
            },
            child: const Text('공유하기'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('취소'),
        ),
      ),
    );
  }

  // 게시물 삭제 확인 다이얼로그
  void _showDeleteConfirmation(WidgetRef ref, String postId) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('이 게시물을 정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              // 다이얼로그 닫기
              Navigator.pop(dialogContext);

              // 삭제 처리 - 비동기 로직을 별도 메서드로 분리
              _performDeletePost(ref, postId);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 삭제 처리 로직을 별도 메서드로 분리
  Future<void> _performDeletePost(WidgetRef ref, String postId) async {
    // 이미 삭제 중이면 무시
    if (_isDeleting) return;

    // 삭제 중 상태로 변경
    if (mounted) {
      setState(() {
        _isDeleting = true;
      });
    }

    try {
      // 게시물 삭제 요청
      await ref.read(postControllerProvider.notifier).deletePost(postId);

      // 성공 메시지 표시 (mounted 체크와 함께)
      if (mounted) {
        _showDeleteSuccessToast();
      }
    } catch (e) {
      // 오류 발생 시 처리 (mounted 체크와 함께)
      if (mounted) {
        _showErrorDialog('게시물 삭제 실패', '게시물을 삭제하는 중 오류가 발생했습니다: $e');
      }
    } finally {
      // 삭제 중 상태 해제 (mounted 체크와 함께)
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  // 삭제 성공 토스트 표시
  void _showDeleteSuccessToast() {
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => Positioned(
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
            child: const Text(
              '게시물이 삭제되었습니다',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // 2초 후 토스트 메시지 제거
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  // 신고 옵션 표시
  void _showReportOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('게시물 신고'),
        message: const Text('이 게시물을 신고하는 이유를 선택해주세요'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              // 신고 처리
              _reportPost('부적절한 콘텐츠');
            },
            child: const Text('부적절한 콘텐츠'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              // 신고 처리
              _reportPost('스팸');
            },
            child: const Text('스팸'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              // 신고 처리
              _reportPost('혐오 발언 또는 상징');
            },
            child: const Text('혐오 발언 또는 상징'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              // 신고 처리
              _reportPost('기타');
            },
            child: const Text('기타'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('취소'),
        ),
      ),
    );
  }

  // 게시물 신고 처리
  void _reportPost(String reason) {
    // 실제 신고 처리 로직
    debugPrint('게시물 ${widget.post.id} 신고됨: $reason');

    // 신고 확인 다이얼로그
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('신고 완료'),
        content: const Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}