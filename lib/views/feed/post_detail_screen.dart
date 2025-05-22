import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/comment_provider.dart';
import '../widgets/post_card_detailed.dart';
import '../../models/comment_model.dart';
import '../widgets/user_avatar.dart';
import 'comment_detail_screen.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({
    Key? key,
    required this.postId,
  }) : super(key: key);

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  // 댓글 제출
  Future<void> _submitComment(String postId, String userId) async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 일반 댓글 작성
      await ref.read(commentControllerProvider.notifier).addComment(
        postId: postId,
        userId: userId,
        text: commentText,
      );

      // 성공 시 텍스트 필드 초기화
      _commentController.clear();
      
      setState(() {
        _isSubmitting = false;
      });
    } catch (e) {
      // 오류 표시
      if (mounted) {
        _showErrorDialog('댓글 등록 실패', '댓글을 등록하는 중 오류가 발생했습니다: $e');
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 게시물 상세 정보 가져오기
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final currentUserAsync = ref.watch(currentUserProvider);
    
    // 댓글 목록 가져오기
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: Color.fromARGB(0, 124, 95, 255),
        border: Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: Text(
          '게시물',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: SafeArea(
        child: postAsync.when(
          data: (post) {
            if (post == null) {
              return const Center(
                child: Text(
                  '게시물을 찾을 수 없습니다',
                  style: TextStyle(color: AppColors.textEmphasis),
                ),
              );
            }

            return Column(
              children: [
                // 게시물 및 댓글 목록 (스크롤 가능)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 게시물 상세 정보
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: PostCardDetailed(post: post),
                        ),
                        
                        // 댓글 섹션 헤더
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 4.0),
                          child: Row(
                            children: [
                              const Text(
                                '댓글',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              commentsAsync.when(
                                data: (comments) => Text(
                                  '${comments.length}',
                                  style: const TextStyle(
                                    color: AppColors.primaryPurple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        
                        // 댓글 목록
                        commentsAsync.when(
                          data: (comments) {
                            if (comments.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    '아직 댓글이 없습니다. 첫 댓글을 남겨보세요!',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              );
                            }
                            
                            return ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                return _buildCommentItem(context, comments[index], currentUserAsync, post.userId);
                              },
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CupertinoActivityIndicator(),
                            ),
                          ),
                          error: (error, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                '댓글을 불러오는 중 오류가 발생했습니다: $error',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 하단 댓글 입력창
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: AppColors.cardBackground,
                    border: Border(
                      top: BorderSide(color: AppColors.separator),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 사용자 아바타 (로그인된 경우만)
                      currentUserAsync.maybeWhen(
                        data: (user) {
                          return user != null
                              ? Container(
                                  width: 36,
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 12.0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: user.profileImageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              user.profileImageUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: user.profileImageUrl == null
                                        ? AppColors.primaryPurple
                                        : null,
                                  ),
                                  child: user.profileImageUrl == null
                                      ? const Center(
                                          child: Icon(
                                            CupertinoIcons.person_fill,
                                            color: AppColors.white,
                                            size: 20,
                                          ),
                                        )
                                      : null,
                                )
                              : const SizedBox.shrink();
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),

                      // 댓글 입력창
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkBackground,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: CupertinoTextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            placeholder: '댓글 작성...',
                            decoration: const BoxDecoration(
                              color: AppColors.darkBackground,
                              border: null,
                            ),
                            style: const TextStyle(color: AppColors.white),
                            placeholderStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 3,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                          ),
                        ),
                      ),
                      
                      // 전송 버튼
                      const SizedBox(width: 8),
                      currentUserAsync.when(
                        data: (user) => user != null 
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _isSubmitting 
                                ? null 
                                : () => _submitComment(post.id, user.id),
                              child: _isSubmitting
                                  ? const CupertinoActivityIndicator()
                                  : const Icon(
                                      CupertinoIcons.paperplane_fill,
                                      color: AppColors.primaryPurple,
                                      size: 28,
                                    ),
                            )
                          : CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                showCupertinoDialog(
                                  context: context,
                                  builder: (context) => CupertinoAlertDialog(
                                    title: const Text('로그인 필요'),
                                    content: const Text('댓글을 작성하려면 로그인이 필요합니다.'),
                                    actions: [
                                      CupertinoDialogAction(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('확인'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Icon(
                                CupertinoIcons.paperplane_fill,
                                color: AppColors.textSecondary,
                                size: 28,
                              ),
                            ),
                        loading: () => const CupertinoActivityIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CupertinoActivityIndicator(),
          ),
          error: (error, stack) => Center(
            child: Text(
              '오류가 발생했습니다: $error',
              style: const TextStyle(color: AppColors.textEmphasis),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
  
  // 댓글 아이템 위젯 - 클릭 시 댓글 상세 화면으로 이동
  Widget _buildCommentItem(
    BuildContext context,
    CommentModel comment,
    AsyncValue<dynamic> currentUserAsync,
    String postUserId,
  ) {
    // 댓글 작성자 정보
    final authorAsync = ref.watch(getUserProfileProvider(comment.userId));
    
    // 현재 사용자가 댓글 작성자인지 확인
    final isAuthor = currentUserAsync.valueOrNull?.id == comment.userId;
    
    // 댓글에 달린 답글 수 확인
    final repliesAsync = ref.watch(commentRepliesProvider(comment.id));
    
    return GestureDetector(
      onTap: () {
        // 댓글 클릭 시 댓글 상세 화면으로 이동
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => CommentDetailScreen(
              postId: widget.postId,
              commentId: comment.id,
              comment: comment,
              postUserId: postUserId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 아바타
            authorAsync.when(
              data: (author) => UserAvatar(
                imageUrl: author?.profileImageUrl,
                size: 40,
              ),
              loading: () => const SizedBox(
                width: 40,
                height: 40,
                child: CupertinoActivityIndicator(),
              ),
              error: (_, __) => const SizedBox(
                width: 40,
                height: 40,
              ),
            ),
            const SizedBox(width: 12),
            
            // 댓글 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작성자 정보
                  authorAsync.when(
                    data: (author) => Text(
                      author?.username ?? '알 수 없는 사용자',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 100,
                      height: 14,
                      child: CupertinoActivityIndicator(),
                    ),
                    error: (_, __) => const Text(
                      '알 수 없는 사용자',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // 댓글 텍스트
                  Text(
                    comment.text,
                    style: const TextStyle(
                      color: AppColors.textEmphasis,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 작성 시간과 답글 관련 정보
                  Row(
                    children: [
                      Text(
                        _formatTimeAgo(comment.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // 답글 달기 텍스트 및 답글 수 표시
                      const Text(
                        '답글 달기',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      // 답글 수 표시
                      repliesAsync.when(
                        data: (replies) => replies.isNotEmpty 
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                '답글 ${replies.length}개',
                                style: const TextStyle(
                                  color: AppColors.primaryPurple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 작성자인 경우 더보기 버튼
            if (isAuthor)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _showCommentOptions(context, comment);
                },
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // 시간 형식 포맷팅
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
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
  
  // 댓글 옵션 메뉴
  void _showCommentOptions(BuildContext context, CommentModel comment) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('댓글 옵션'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context, comment);
            },
            child: const Text('삭제하기'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }
  
  // 삭제 확인 다이얼로그
  void _showDeleteConfirmation(BuildContext context, CommentModel comment) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 정말 삭제하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(comment);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
  
  // 댓글 삭제
  void _deleteComment(CommentModel comment) async {
    try {
      await ref.read(commentControllerProvider.notifier).deleteComment(
        commentId: comment.id,
        postId: widget.postId,
      );
      
      // 성공 메시지
      if (mounted) {
        _showSuccessNotification('댓글이 삭제되었습니다');
      }
    } catch (e) {
      // 오류 메시지
      if (mounted) {
        _showErrorDialog('댓글 삭제 실패', '댓글을 삭제하는 중 오류가 발생했습니다: $e');
      }
    }
  }
  
  // 성공 알림 표시 (Cupertino 스타일)
  void _showSuccessNotification(String message) {
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

    overlay.insert(entry);

    // 2초 후 토스트 메시지 제거
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }
}