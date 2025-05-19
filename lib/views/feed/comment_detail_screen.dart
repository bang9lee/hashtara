import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../models/comment_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/comment_provider.dart';
import '../widgets/user_avatar.dart';
import '../../views/profile/profile_screen.dart';

class CommentDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final String commentId;
  final CommentModel comment;
  final String postUserId;
  final bool isEditing;

  const CommentDetailScreen({
    Key? key,
    required this.postId,
    required this.commentId,
    required this.comment,
    required this.postUserId,
    this.isEditing = false,
  }) : super(key: key);

  @override
  ConsumerState<CommentDetailScreen> createState() => _CommentDetailScreenState();
}

class _CommentDetailScreenState extends ConsumerState<CommentDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    
    // 편집 모드인 경우 텍스트 필드에 기존 댓글 텍스트 설정
    _isEditing = widget.isEditing;
    if (_isEditing) {
      _commentController.text = widget.comment.text;
      
      // 포커스 설정
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
    
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
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  // 댓글/대댓글 제출
  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _isSubmitting) {
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
      if (_isEditing) {
        // 댓글 수정 모드
        await ref.read(commentControllerProvider.notifier).updateComment(
          commentId: widget.commentId,
          postId: widget.postId,
          text: commentText,
          parentId: widget.comment.parentId,
        );
        
        setState(() {
          _isEditing = false;
        });
      } else {
        // 대댓글 작성 모드
        await ref.read(commentControllerProvider.notifier).addComment(
          postId: widget.postId,
          userId: currentUser.id,
          text: commentText,
          parentId: widget.commentId,
        );
      }

      // 성공 시 텍스트 필드 초기화
      _commentController.clear();
      
      // 데이터 새로고침
      _refreshData();
      
      // 편집 모드였던 경우 성공 후 뒤로 가기
      if (_isEditing) {
        if (mounted) {
          Navigator.pop(context);
        }
      }
      
      debugPrint('댓글 제출 완료');
    } catch (e) {
      debugPrint('댓글 작업 실패: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(_isEditing ? '댓글 수정 실패' : '댓글 등록 실패'),
            content: Text('댓글을 처리하는 중 오류가 발생했습니다: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    // 댓글 작성자 정보
    final authorAsync = ref.watch(getUserProfileProvider(widget.comment.userId));
    
    // 댓글의 대댓글 목록
    final repliesAsync = ref.watch(commentRepliesProvider(widget.commentId));
    
    // 현재 로그인한 사용자
    final currentUserAsync = ref.watch(currentUserProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: Text(
          _isEditing ? '댓글 수정' : '댓글 상세',
          style: const TextStyle(
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
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                  color: const Color.fromRGBO(124, 95, 255, 0.3),
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
                        
                        // 댓글 메타 정보 (작성 시간, 좋아요)
                        Row(
                          children: [
                            Text(
                              _formatTimeAgo(widget.comment.createdAt),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // 좋아요 버튼
                            currentUserAsync.when(
                              data: (currentUser) => currentUser != null
                                  ? _buildLikeButton(widget.comment, currentUser.id)
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
                  currentUserAsync.maybeWhen(
                    data: (currentUser) => currentUser?.id == widget.comment.userId
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
            
            // 대댓글 섹션 레이블
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              alignment: Alignment.centerLeft,
              child: const Text(
                '답글',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // 대댓글 목록
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
                      final reply = replies[index];
                      return _buildReplyItem(context, reply, currentUserAsync);
                    },
                  );
                },
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (error, _) => Center(
                  child: Text(
                    '답글을 불러오는 중 오류가 발생했습니다: $error',
                    style: const TextStyle(color: AppColors.textEmphasis),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            
            // 답글 입력 필드
            if (!_isEditing) // 편집 모드가 아닐 때만 답글 입력 필드 표시
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
                    
                    // 대댓글 입력 필드
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
                          controller: _commentController,
                          focusNode: _commentFocusNode,
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
                    
                    // 전송 버튼
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isSubmitting ? null : _submitComment,
                      child: _isSubmitting
                          ? const CupertinoActivityIndicator()
                          : const Icon(
                              CupertinoIcons.paperplane_fill,
                              color: AppColors.primaryPurple,
                              size: 28,
                            ),
                    ),
                  ],
                ),
              ),
              
            // 댓글 편집 필드 (편집 모드인 경우)
            if (_isEditing)
              Container(
                padding: const EdgeInsets.all(16.0),
                color: AppColors.cardBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 편집 중 안내 표시
                    Row(
                      children: [
                        const Text(
                          '댓글 편집 중',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _commentController.clear();
                            });
                            Navigator.pop(context);
                          },
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 댓글 입력 필드
                    Row(
                      children: [
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
                              maxLines: 5,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        
                        // 완료 버튼
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _isSubmitting ? null : _submitComment,
                          child: _isSubmitting
                              ? const CupertinoActivityIndicator()
                              : const Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: AppColors.primaryPurple,
                                  size: 28,
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

  // 대댓글 아이템 위젯
  Widget _buildReplyItem(
    BuildContext context,
    CommentModel reply,
    AsyncValue<dynamic> currentUserAsync,
  ) {
    // 대댓글 작성자 정보
    final authorAsync = ref.watch(getUserProfileProvider(reply.userId));
    
    // 현재 사용자가 대댓글 작성자인지 확인
    final isAuthor = currentUserAsync.valueOrNull?.id == reply.userId;
    final isPostAuthor = widget.postUserId == reply.userId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        // withOpacity 대신 withValues 사용 (Color.fromRGBO로 대체)
        color: const Color.fromRGBO(38, 38, 62, 0.3),
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
                      userId: reply.userId,
                    ),
                  ),
                );
              },
              child: UserAvatar(
                imageUrl: author?.profileImageUrl,
                size: 32,
              ),
            ),
            loading: () => const SizedBox(
              width: 32,
              height: 32,
              child: CupertinoActivityIndicator(),
            ),
            error: (_, __) => const SizedBox(
              width: 32,
              height: 32,
            ),
          ),
          const SizedBox(width: 8),
          
          // 대댓글 내용
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
                    const SizedBox(width: 8),
                    
                    // 게시물 작성자 표시
                    if (isPostAuthor)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(124, 95, 255, 0.3),
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
                const SizedBox(height: 2),
                
                // 대댓글 텍스트
                Text(
                  reply.text,
                  style: const TextStyle(
                    color: AppColors.textEmphasis,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                
                // 대댓글 메타 정보 (작성 시간, 좋아요)
                Row(
                  children: [
                    Text(
                      _formatTimeAgo(reply.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 좋아요 버튼
                    currentUserAsync.when(
                      data: (currentUser) => currentUser != null
                          ? _buildLikeButton(reply, currentUser.id, isReply: true)
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    
                    const Spacer(),
                    
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 좋아요 버튼 위젯
  Widget _buildLikeButton(CommentModel comment, String userId, {bool isReply = false}) {
  // 좋아요 상태 가져오기
  final likeStatusAsync = ref.watch(
    commentLikeStatusProvider({'commentId': comment.id, 'userId': userId})
  );
  
  return likeStatusAsync.when(
    data: (isLiked) => GestureDetector(
      onTap: () {
        ref.read(commentControllerProvider.notifier).toggleLike(
          commentId: comment.id,
          userId: userId,
          postId: widget.postId, // postId 추가
        );
      },
      child: Row(
        children: [
          Icon(
            isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            color: isLiked ? CupertinoColors.systemRed : AppColors.textSecondary,
            size: isReply ? 12 : 14,
          ),
          if (comment.likesCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              comment.likesCount.toString(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: isReply ? 11 : 12,
              ),
            ),
          ],
        ],
      ),
    ),
    loading: () => const CupertinoActivityIndicator(radius: 6),
    error: (_, __) => Icon(
      CupertinoIcons.heart,
      color: AppColors.textSecondary,
      size: isReply ? 12 : 14,
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isEditing = true;
                _commentController.text = widget.comment.text;
              });
              _commentFocusNode.requestFocus();
            },
            child: const Text('수정'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              _showDeleteConfirmation(
                context, 
                widget.commentId,
                isMainComment: true,
              );
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

  // 대댓글 옵션 메뉴
  void _showReplyOptions(BuildContext context, CommentModel reply) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('답글 옵션'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // 답글 수정 화면으로 이동 (간단하게 구현)
              setState(() {
                _isEditing = true;
                _commentController.text = reply.text;
              });
              _commentFocusNode.requestFocus();
            },
            child: const Text('수정'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              _showDeleteConfirmation(
                context, 
                reply.id,
                isMainComment: false,
                parentId: reply.parentId,
              );
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
  void _showDeleteConfirmation(
    BuildContext context, 
    String commentId, 
    {required bool isMainComment, String? parentId}
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(isMainComment ? '댓글 삭제' : '답글 삭제'),
        content: Text(
          isMainComment 
              ? '이 댓글을 정말 삭제하시겠습니까? 모든 대댓글도 함께 삭제됩니다.'
              : '이 답글을 정말 삭제하시겠습니까?'
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(commentId, parentId);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 댓글/대댓글 삭제
  void _deleteComment(String commentId, String? parentId) async {
    try {
      await ref.read(commentControllerProvider.notifier).deleteComment(
        commentId: commentId,
        postId: widget.postId,
        parentId: parentId,
      );
      
      _refreshData();
      
      // 메인 댓글을 삭제한 경우 화면을 닫음
      if (commentId == widget.commentId && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('댓글 삭제 실패: $e');
      _showErrorDialog('삭제 실패', '댓글을 삭제하는 중 오류가 발생했습니다: $e');
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