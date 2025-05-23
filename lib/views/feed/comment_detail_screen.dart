import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../models/comment_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/comment_provider.dart';
import '../widgets/user_avatar.dart';
import '../../views/profile/profile_screen.dart';

class CommentDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final String commentId;
  final CommentModel comment;
  final String postUserId;

  const CommentDetailScreen({
    Key? key,
    required this.postId,
    required this.commentId,
    required this.comment,
    required this.postUserId,
  }) : super(key: key);

  @override
  ConsumerState<CommentDetailScreen> createState() =>
      _CommentDetailScreenState();
}

class _CommentDetailScreenState extends ConsumerState<CommentDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    
    // 데이터 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  // 데이터 새로고침
  void _refreshData() {
    debugPrint('CommentDetailScreen: 데이터 새로고침');
    ref.invalidate(commentRepliesProvider(widget.commentId));
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  // 답글 제출
  Future<void> _submitReply() async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty || _isSubmitting) {
      return;
    }

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 답글로 작성
      await ref.read(commentControllerProvider.notifier).addComment(
            postId: widget.postId,
            userId: currentUser.id,
            text: replyText,
            replyToCommentId: widget.commentId, // 부모 댓글 ID 지정 (중요!)
          );

      // 성공 시 텍스트 필드 초기화
      _replyController.clear();

      // 데이터 새로고침
      _refreshData();

      debugPrint('답글 제출 완료');
      
      // 토스트 메시지 표시
      if (mounted) {
        _showToast('답글이 등록되었습니다');
      }
    } catch (e) {
      debugPrint('답글 작성 실패: $e');
      if (mounted) {
        _showErrorDialog('답글 등록 실패', '답글을 처리하는 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // 오류 다이얼로그
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

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
  
  // 토스트 메시지 표시
  void _showToast(String message) {
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

  @override
  Widget build(BuildContext context) {
    // 댓글 작성자 정보
    final authorAsync =
        ref.watch(getUserProfileProvider(widget.comment.userId));

    // 현재 로그인한 사용자
    final currentUserAsync = ref.watch(currentUserProvider);
    
    // 답글 목록
    final repliesAsync = ref.watch(commentRepliesProvider(widget.commentId));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color.fromARGB(0, 124, 95, 255),
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: const Text(
          '댓글',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _refreshData,
          child: const Icon(
            CupertinoIcons.refresh,
            color: AppColors.white,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 메인 댓글
            Container(
              padding: const EdgeInsets.all(16.0),
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작성자 아바타
                  authorAsync.when(
                    data: (author) => GestureDetector(
                      onTap: () {
                        // 프로필 화면으로 이동
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) => ProfileScreen(
                              userId: widget.comment.userId,
                            ),
                          ),
                        );
                      },
                      child: UserAvatar(
                        imageUrl: author?.profileImageUrl,
                        size: 40,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 40,
                      height: 40,
                      child: CupertinoActivityIndicator(),
                    ),
                    error: (_, __) => const SizedBox(width: 40, height: 40),
                  ),

                  const SizedBox(width: 12),

                  // 댓글 내용
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 작성자 정보
                        Row(
                          children: [
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
                            const SizedBox(width: 8),

                            // 게시물 작성자 표시
                            if (widget.comment.userId == widget.postUserId)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color.fromRGBO(124, 95, 255, 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '작성자',
                                  style: TextStyle(
                                    color: AppColors.primaryPurple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // 댓글 텍스트
                        Text(
                          widget.comment.text,
                          style: const TextStyle(
                            color: AppColors.textEmphasis,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 댓글 작성 시간
                        Text(
                          _formatTimeAgo(widget.comment.createdAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 작성자인 경우 더보기 버튼
                  currentUserAsync.maybeWhen(
                    data: (currentUser) =>
                        currentUser?.id == widget.comment.userId
                            ? CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _showCommentOptions(context);
                                },
                                child: const Icon(
                                  CupertinoIcons.ellipsis_vertical,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                              )
                            : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // 이전 답글 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text(
                    '이 댓글에 대한 답글',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 답글 수 표시
                  repliesAsync.when(
                    data: (replies) => Text(
                      '${replies.length}',
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // 답글 목록
            Expanded(
              child: repliesAsync.when(
                data: (replies) {
                  if (replies.isEmpty) {
                    return const Center(
                      child: Text(
                        '아직 답글이 없습니다',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: replies.length,
                    itemBuilder: (context, index) {
                      return _buildReplyItem(context, replies[index], currentUserAsync);
                    },
                  );
                },
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (error, _) => Center(
                  child: Text(
                    '답글을 불러오는 중 오류가 발생했습니다: $error',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // 답글 입력 필드
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.cardBackground,
              child: Row(
                children: [
                  // 사용자 아바타
                  currentUserAsync.maybeWhen(
                    data: (user) => user != null
                        ? Container(
                            margin: const EdgeInsets.only(right: 12.0),
                            child: UserAvatar(
                              imageUrl: user.profileImageUrl,
                              size: 36,
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),

                  // 답글 입력 필드
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkBackground,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: CupertinoTextField(
                        controller: _replyController,
                        focusNode: _replyFocusNode,
                        placeholder: '답글 작성...',
                        decoration: const BoxDecoration(
                          color: AppColors.darkBackground,
                          border: null,
                        ),
                        style: const TextStyle(color: AppColors.white),
                        placeholderStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 5,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // 전송 버튼 - 색상 변경
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isSubmitting ? null : _submitReply,
                    child: _isSubmitting
                        ? const CupertinoActivityIndicator()
                        : const Icon(
                            CupertinoIcons.paperplane_fill,
                            // 색상 수정
                            color: AppColors.primaryPurple,
                            size: 28,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 답글 아이템 위젯
  Widget _buildReplyItem(
    BuildContext context,
    CommentModel reply,
    AsyncValue<dynamic> currentUserAsync,
  ) {
    // 답글 작성자 정보
    final authorAsync = ref.watch(getUserProfileProvider(reply.userId));
    
    // 현재 사용자가 답글 작성자인지 확인
    final isAuthor = currentUserAsync.valueOrNull?.id == reply.userId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(38, 38, 62, 0.3),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 아바타
          authorAsync.when(
            data: (author) => UserAvatar(
              imageUrl: author?.profileImageUrl,
              size: 32,
            ),
            loading: () => const SizedBox(
              width: 32,
              height: 32,
              child: CupertinoActivityIndicator(),
            ),
            error: (_, __) => const SizedBox(width: 32, height: 32),
          ),
          const SizedBox(width: 8),
          
          // 답글 내용
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
                      fontSize: 14,
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 80,
                    height: 12,
                    child: CupertinoActivityIndicator(),
                  ),
                  error: (_, __) => const Text(
                    '알 수 없는 사용자',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                
                // 답글 텍스트
                Text(
                  reply.text,
                  style: const TextStyle(
                    color: AppColors.textEmphasis,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                
                // 답글 작성 시간
                Text(
                  _formatTimeAgo(reply.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // 작성자인 경우 더보기 버튼
          if (isAuthor)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                _showReplyOptions(context, reply);
              },
              child: const Icon(
                CupertinoIcons.ellipsis_vertical,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  // 메인 댓글 옵션 메뉴
  void _showCommentOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('댓글 옵션'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            },
            child: const Text('삭제'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }
  
  // 답글 옵션 메뉴
  void _showReplyOptions(BuildContext context, CommentModel reply) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('답글 옵션'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              _showDeleteReplyConfirmation(context, reply);
            },
            child: const Text('삭제'),
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
  void _showDeleteConfirmation(BuildContext context) {
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
              _deleteComment();
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
  
  // 답글 삭제 확인 다이얼로그
  void _showDeleteReplyConfirmation(BuildContext context, CommentModel reply) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('답글 삭제'),
        content: const Text('이 답글을 정말 삭제하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await _deleteReply(reply);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 댓글 삭제
  void _deleteComment() async {
    try {
      await ref.read(commentControllerProvider.notifier).deleteComment(
            commentId: widget.commentId,
            postId: widget.postId,
            isReply: false,
          );

      // 메인 댓글을 삭제한 경우 화면을 닫음
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('댓글 삭제 실패: $e');
      _showErrorDialog('삭제 실패', '댓글을 삭제하는 중 오류가 발생했습니다: $e');
    }
  }
  
  // 답글 삭제
  Future<void> _deleteReply(CommentModel reply) async {
    try {
      await ref.read(commentControllerProvider.notifier).deleteComment(
            commentId: reply.id,
            postId: widget.postId,
            isReply: true,
          );
      
      // 답글 삭제 후 목록 새로고침
      if (mounted) {
        _showToast('답글이 삭제되었습니다');
        _refreshData();
      }
    } catch (e) {
      debugPrint('답글 삭제 실패: $e');
      if (mounted) {
        _showErrorDialog('삭제 실패', '답글을 삭제하는 중 오류가 발생했습니다: $e');
      }
    }
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
}