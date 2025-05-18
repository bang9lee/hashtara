import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../models/comment_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/comment_provider.dart';
import '../widgets/user_avatar.dart';

class CommentScreen extends ConsumerStatefulWidget {
  final String postId;
  final String postUserId;
  final String? initialText;
  final String? editingCommentId; // 편집 모드로 진입할 경우 댓글 ID

  const CommentScreen({
    Key? key,
    required this.postId,
    required this.postUserId,
    this.initialText,
    this.editingCommentId,
  }) : super(key: key);

  @override
  ConsumerState<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends ConsumerState<CommentScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyToCommentId;
  String? _replyToUsername;
  bool _isSubmitting = false;
  String? _editingCommentId;
  bool _isRefreshing = false; // 새로고침 상태 관리

  @override
  void initState() {
    super.initState();
    
    // 상태 초기화
    _editingCommentId = widget.editingCommentId;
    
    // 초기 댓글이 있으면 설정
    if (widget.initialText != null) {
      _commentController.text = widget.initialText!;
      
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

  // 데이터 새로고침 - 비동기 처리 추가
  Future<void> _refreshData() async {
    if (_isRefreshing) return; // 이미 새로고침 중이면 중복 실행 방지
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      debugPrint('CommentScreen: 데이터 새로고침');
      
      // 프로바이더 무효화
      ref.invalidate(postCommentsProvider(widget.postId));
      
      // 약간의 지연으로 비동기 작업 완료 기다림
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('새로고침 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  // 댓글 제출
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
      debugPrint('댓글 제출 시작: ${_editingCommentId != null ? "수정" : "새로작성"}');
      
      // 댓글 편집 중인 경우
      if (_editingCommentId != null) {
        await ref.read(commentControllerProvider.notifier).updateComment(
          commentId: _editingCommentId!,
          postId: widget.postId,
          text: commentText,
          parentId: _replyToCommentId, // 대댓글 편집 시 부모 ID 고려
        );
        
        // 상태 초기화
        setState(() {
          _editingCommentId = null;
        });
      } 
      // 답글 작성 중인 경우
      else if (_replyToCommentId != null) {
        await ref.read(commentControllerProvider.notifier).addComment(
          postId: widget.postId,
          userId: currentUser.id,
          text: commentText,
          parentId: _replyToCommentId,
        );
        
        // 상태 초기화
        setState(() {
          _replyToCommentId = null;
          _replyToUsername = null;
        });
      } 
      // 일반 댓글 작성
      else {
        await ref.read(commentControllerProvider.notifier).addComment(
          postId: widget.postId,
          userId: currentUser.id,
          text: commentText,
          parentId: null,
        );
      }

      // 성공 시 텍스트 필드 초기화
      _commentController.clear();
      
      // 데이터 새로고침
      await _refreshData();
      
      debugPrint('댓글 제출 완료');
    } catch (e) {
      // 오류 표시 - mounted 체크 추가
      if (mounted) {
        _showErrorDialog('댓글 등록 실패', '댓글을 등록하는 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // 댓글 편집 시작
  void _startEditing(CommentModel comment) {
    setState(() {
      _editingCommentId = comment.id;
      _commentController.text = comment.text;
      _replyToCommentId = comment.parentId;
      _replyToUsername = null;
    });
    
    _commentFocusNode.requestFocus();
  }

  // 답글 작성 시작
  void _startReplying(String commentId, String username) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToUsername = username;
      _editingCommentId = null;
      _commentController.text = '';
    });
    
    _commentFocusNode.requestFocus();
  }

  // 댓글 작성 취소
  void _cancelAction() {
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
      _editingCommentId = null;
      _commentController.clear();
    });
    
    _commentFocusNode.unfocus();
  }

  // Helper method to show error dialogs safely
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
    // 현재 로그인한 사용자
    final currentUserAsync = ref.watch(currentUserProvider);
    
    // 게시물 댓글 목록
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
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
          onPressed: _isRefreshing ? null : _refreshData,
          child: _isRefreshing
            ? const CupertinoActivityIndicator(color: AppColors.white)
            : const Icon(
                CupertinoIcons.refresh,
                color: AppColors.white,
              ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 댓글 목록
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                  debugPrint('댓글 표시: ${comments.length}개');
                  
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        '아직 댓글이 없습니다',
                        style: TextStyle(color: AppColors.textEmphasis),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      
                      return _buildCommentItem(
                        context, 
                        comment,
                        currentUserAsync,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (error, stack) {
                  debugPrint('댓글 로딩 중 오류: $error');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '댓글을 불러오는 중 오류가 발생했습니다: $error',
                          style: const TextStyle(color: AppColors.textEmphasis),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton(
                          onPressed: _refreshData,
                          child: const Text('새로고침'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // 댓글 입력 영역
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.cardBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 답글 작성 중인 경우 안내 표시
                  if (_replyToUsername != null)
                    Row(
                      children: [
                        Text(
                          '$_replyToUsername님에게 답글 작성 중',
                          style: const TextStyle(
                            color: AppColors.primaryPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _cancelAction,
                          child: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  
                  // 편집 중인 경우 안내 표시
                  if (_editingCommentId != null)
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
                          onPressed: _cancelAction,
                          child: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: AppColors.textSecondary,
                            size: 18,
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
                      const SizedBox(width: 8),
                      
                      // 전송 버튼
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 댓글 아이템 위젯
  Widget _buildCommentItem(
    BuildContext context,
    CommentModel comment,
    AsyncValue<dynamic> currentUserAsync,
  ) {
    // 댓글 작성자 정보
    final authorAsync = ref.watch(getUserProfileProvider(comment.userId));
    
    // 대댓글 목록
    final repliesAsync = ref.watch(commentRepliesProvider(comment.id));
    
    // 현재 사용자가 댓글 작성자인지 확인
    final isAuthor = currentUserAsync.valueOrNull?.id == comment.userId;
    final isPostAuthor = widget.postUserId == comment.userId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자 아바타
              authorAsync.when(
                data: (author) => UserAvatar(
                  imageUrl: author?.profileImageUrl,
                  size: 40,
                  onTap: () {
                    // 프로필 페이지로 이동 (구현 필요)
                  },
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
                    
                    // 댓글 메타 정보 (작성 시간, 버튼들)
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
                        
                        // 좋아요 버튼 - 값 확인 후 안전하게 전달
                        if (currentUserAsync.valueOrNull != null)
                          _buildLikeButton(
                            comment, 
                            currentUserAsync.valueOrNull!.id,
                          ),
                        
                        const SizedBox(width: 16),
                        
                        // 답글 버튼
                        GestureDetector(
                          onTap: () {
                            // 사용자 정보 가져오기
                            final username = authorAsync.valueOrNull?.username ?? '사용자';
                            _startReplying(comment.id, username);
                          },
                          child: const Text(
                            '답글',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // 작성자인 경우 더보기 버튼
                        if (isAuthor)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              showCupertinoModalPopup(
                                context: context,
                                builder: (context) => CupertinoActionSheet(
                                  actions: [
                                    CupertinoActionSheetAction(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _startEditing(comment);
                                      },
                                      child: const Text('수정'),
                                    ),
                                    CupertinoActionSheetAction(
                                      isDestructiveAction: true,
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        try {
                                          await ref.read(commentControllerProvider.notifier)
                                              .deleteComment(
                                            commentId: comment.id,
                                            postId: widget.postId,
                                          );
                                          
                                          // 삭제 후 데이터 새로고침
                                          _refreshData();
                                        } catch (e) {
                                          // Use the helper method to display errors safely
                                          if (mounted) {
                                            _showErrorDialog('댓글 삭제 실패', '댓글을 삭제하는 중 오류가 발생했습니다: $e');
                                          }
                                        }
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
                            },
                            child: const Icon(
                              CupertinoIcons.ellipsis,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 대댓글 목록
          repliesAsync.when(
            data: (replies) {
              if (replies.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Padding(
                padding: const EdgeInsets.only(left: 52.0, top: 8.0),
                child: Column(
                  children: replies.map((reply) {
                    return _buildReplyItem(context, reply, currentUserAsync);
                  }).toList(),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(left: 52.0, top: 8.0),
              child: Center(
                child: CupertinoActivityIndicator(),
              ),
            ),
            error: (error, __) {
              debugPrint('대댓글 로딩 오류: $error');
              return const SizedBox.shrink();
            },
          ),
        ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 아바타
          authorAsync.when(
            data: (author) => UserAvatar(
              imageUrl: author?.profileImageUrl,
              size: 32,
              onTap: () {
                // 프로필 페이지로 이동 (구현 필요)
              },
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
                
                // 대댓글 메타 정보 (작성 시간, 버튼들)
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
                    
                    // 좋아요 버튼 - 안전하게 전달
                    if (currentUserAsync.valueOrNull != null)
                      _buildLikeButton(
                        reply, 
                        currentUserAsync.valueOrNull!.id,
                        isReply: true,
                      ),
                    
                    const Spacer(),
                    
                    // 작성자인 경우 더보기 버튼
                    if (isAuthor)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) => CupertinoActionSheet(
                              actions: [
                                CupertinoActionSheetAction(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _startEditing(reply);
                                  },
                                  child: const Text('수정'),
                                ),
                                CupertinoActionSheetAction(
                                  isDestructiveAction: true,
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    try {
                                      await ref.read(commentControllerProvider.notifier)
                                          .deleteComment(
                                        commentId: reply.id,
                                        postId: widget.postId,
                                        parentId: reply.parentId,
                                      );
                                      
                                      // 삭제 후 데이터 새로고침
                                      _refreshData();
                                    } catch (e) {
                                      // Use the helper method to display errors safely
                                      if (mounted) {
                                        _showErrorDialog('댓글 삭제 실패', '댓글을 삭제하는 중 오류가 발생했습니다: $e');
                                      }
                                    }
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
                        },
                        child: const Icon(
                          CupertinoIcons.ellipsis,
                          color: AppColors.textSecondary,
                          size: 18,
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

  // 좋아요 버튼 위젯 - null 안전성 개선
  Widget _buildLikeButton(CommentModel comment, String userId, {bool isReply = false}) {
    // 유효한 파라미터 맵 생성 - null 값 방지
    final params = {'commentId': comment.id, 'userId': userId};
    
    // 좋아요 상태 스트림 
    final likeStatusAsync = ref.watch(commentLikeStatusProvider(params));
    
    return likeStatusAsync.when(
      data: (isLiked) => GestureDetector(
        onTap: () {
          // 로딩 상태에서는 클릭 방지
          ref.read(commentControllerProvider.notifier).toggleLike(
            commentId: comment.id,
            userId: userId,
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