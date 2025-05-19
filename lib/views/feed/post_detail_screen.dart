import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/comment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/post_card_detailed.dart';
import '../widgets/user_avatar.dart';
import '../../views/feed/comment_detail_screen.dart';
import '../../views/profile/profile_screen.dart';

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
  bool _isInitialized = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 화면 로드 시 한 번만 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _refreshData();
        _isInitialized = true;
      }
    });
  }

  // 스트림 프로바이더 갱신 - 성능 개선
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      debugPrint('PostDetailScreen: 데이터 새로고침 시작');
      
      // 기존 프로바이더 무효화
      ref.invalidate(postDetailProvider(widget.postId));
      ref.invalidate(postCommentsProvider(widget.postId));
      
      // 데이터 가져오기 강제 시작
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (mounted) {
        // 강제로 데이터를 가져오기
        // unused_result 경고 수정: 변수에 할당 (결과 사용)
        var _ = ref.refresh(postCommentsProvider(widget.postId));
      }
    } catch (e) {
      debugPrint('데이터 새로고침 오류: $e');
    } finally {
      // 중요: 로딩 상태를 항상 false로 되돌려야 함
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

  // 댓글 제출 처리
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
      debugPrint('댓글 제출 시작: postId=${widget.postId}, text=$commentText');
      
      await ref.read(commentControllerProvider.notifier).addComment(
        postId: widget.postId,
        userId: currentUser.id,
        text: commentText,
        parentId: null,
      );
      
      // 댓글 성공 시 입력 필드 초기화
      _commentController.clear();
      
      debugPrint('댓글 제출 완료');
      
      // 추가 데이터 새로고침 (필요한 경우)
      if (mounted) {
        await _refreshData();
      }
    } catch (e) {
      debugPrint('댓글 등록 실패: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('댓글 등록 실패'),
            content: Text('댓글을 등록하는 중 오류가 발생했습니다: $e'),
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

  @override
  Widget build(BuildContext context) {
    // 게시물 상세 정보 가져오기
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    
    // 게시물의 댓글 가져오기
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    
    // 현재 로그인한 사용자
    final currentUserAsync = ref.watch(currentUserProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: const Text(
          '게시물',
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
                  size: 22,
                ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 게시물 및 댓글 목록 (스크롤 가능)
            Expanded(
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
                  
                  return CustomScrollView(
                    slivers: [
                      // 게시물 상세 내용
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: PostCardDetailed(post: post),
                        ),
                      ),
                      
                      // 구분선
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            height: 1,
                            color: AppColors.separator,
                          ),
                        ),
                      ),
                      
                      // 댓글 섹션 헤더 - 실시간 업데이트 적용
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                post.commentsCount > 0
                                    ? '댓글 ${post.commentsCount}개'
                                    : '첫 댓글을 남겨보세요',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // 새로고침 버튼 추가
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _isRefreshing ? null : _refreshData,
                                child: _isRefreshing
                                    ? const CupertinoActivityIndicator(radius: 8)
                                    : const Icon(
                                        CupertinoIcons.refresh,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // 댓글 목록 (모든 댓글 표시) - 역순으로 변경하지 않음: 최신이 맨 아래에 오도록
                      commentsAsync.when(
                        data: (comments) {
                          // 자세한 로그 대신 간단한 요약 표시
                          debugPrint('댓글 표시: ${comments.length}개');
                          
                          if (comments.isEmpty) {
                            return const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    '아직 댓글이 없습니다',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          
                          // 모든 댓글 표시 (스레드 방식) - 정렬은 변경하지 않음
                          // 부모 댓글만 먼저 필터링
                          final parentComments = comments
                              .where((c) => c.parentId == null)
                              .toList();
                          
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index < parentComments.length) {
                                  final comment = parentComments[index];
                                  // 이 댓글에 대한 대댓글 수 계산
                                  final replyCount = comments.where((c) => c.parentId == comment.id).length;
                                  
                                  return _buildCommentItem(
                                    context, 
                                    comment, 
                                    post.userId,
                                    replyCount,
                                  );
                                }
                                return null;
                              },
                              childCount: parentComments.length,
                            ),
                          );
                        },
                        loading: () => const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CupertinoActivityIndicator(),
                            ),
                          ),
                        ),
                        error: (error, stack) {
                          debugPrint('댓글 로딩 오류: $error');
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      '댓글을 불러오는 중 오류가 발생했습니다',
                                      style: TextStyle(color: AppColors.textEmphasis),
                                    ),
                                    const SizedBox(height: 8),
                                    CupertinoButton(
                                      onPressed: _refreshData,
                                      child: const Text('다시 시도'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '게시물을 불러오는 중 오류가 발생했습니다: $error',
                        style: const TextStyle(color: AppColors.textEmphasis),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        onPressed: _refreshData,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 하단 댓글 입력 영역
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(
                  top: BorderSide(color: AppColors.separator, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // 사용자 아바타 (로그인 된 경우)
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
                  
                  // 댓글 입력 필드
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
          ],
        ),
      ),
    );
  }
  
  // 댓글 아이템 위젯 - 성능 최적화
  Widget _buildCommentItem(
    BuildContext context, 
    dynamic comment, 
    String postUserId,
    int replyCount,
  ) {
    // 작성자 정보 가져오기 - 불필요한 리빌드 최소화를 위해 read 대신 watch 사용
    final authorAsync = ref.watch(getUserProfileProvider(comment.userId));
    
    // 현재 사용자 정보
    final currentUserAsync = ref.watch(currentUserProvider);
    
    return GestureDetector(
      onTap: () {
        // 댓글 상세 화면으로 이동 (대댓글 작성 및 보기 위함)
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
        ).then((_) {
          // 화면 복귀 시 데이터 새로고침
          if (mounted) {
            _refreshData();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        decoration: BoxDecoration(
          // Color.fromRGBO 사용
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
                        userId: comment.userId,
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
            
            const SizedBox(width: 10),
            
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
                          width: 80,
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
                      if (comment.userId == postUserId)
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
                  
                  // 댓글 메타 정보 (작성 시간, 좋아요, 답글 버튼)
                  Row(
                    children: [
                      // 작성 시간
                      Text(
                        _formatTimeAgo(comment.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // 좋아요 버튼 - 상태 값을 사용하도록 수정
                      _CommentLikeButtonFixed(
                        comment: comment,
                        userId: currentUserAsync.valueOrNull?.id ?? '',
                        postId: widget.postId,
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // 대댓글 표시
                      if (replyCount > 0)
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.chat_bubble_2,
                              color: AppColors.textSecondary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              replyCount.toString(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 더보기 버튼
            if (currentUserAsync.valueOrNull?.id == comment.userId)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _showCommentOptions(context, comment);
                },
                child: const Icon(
                  CupertinoIcons.ellipsis_vertical,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // 댓글 옵션 메뉴 (수정/삭제)
  void _showCommentOptions(BuildContext context, dynamic comment) {
    final postData = ref.read(postDetailProvider(widget.postId)).valueOrNull;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('댓글 옵션'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // 댓글 수정 화면으로 이동
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => CommentDetailScreen(
                    postId: widget.postId,
                    commentId: comment.id,
                    comment: comment,
                    postUserId: postData?.userId ?? '',
                    isEditing: true, // 편집 모드로 열기
                  ),
                ),
              ).then((_) {
                // 화면 복귀 시 데이터 새로고침
                if (mounted) {
                  _refreshData();
                }
              });
            },
            child: const Text('수정하기'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showDeleteCommentConfirmation(context, comment.id);
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
  
  // 댓글 삭제 확인 다이얼로그
  void _showDeleteCommentConfirmation(BuildContext context, String commentId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 정말 삭제하시겠습니까? 모든 대댓글도 함께 삭제됩니다.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _performCommentDeletion(commentId);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
  
  // 댓글 삭제 실행
  void _performCommentDeletion(String commentId) {
    debugPrint('댓글 삭제 시작 - commentId: $commentId');
    
    ref.read(commentControllerProvider.notifier).deleteComment(
      commentId: commentId,
      postId: widget.postId,
    ).then((_) {
      debugPrint('댓글 삭제 성공');
      // 화면 새로고침
      if (mounted) {
        _refreshData();
      }
    }).catchError((e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('삭제 실패'),
            content: Text('댓글을 삭제하는 중 오류가 발생했습니다: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    });
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

// 좋아요 버튼 위젯 - 무한 로딩 문제 개선을 위해 StatefulWidget으로 변경
class _CommentLikeButtonFixed extends ConsumerStatefulWidget {
  final dynamic comment;
  final String userId;
  final String postId;
  
  const _CommentLikeButtonFixed({
    required this.comment,
    required this.userId,
    required this.postId,
  });
  
  @override
  ConsumerState<_CommentLikeButtonFixed> createState() => _CommentLikeButtonFixedState();
}

class _CommentLikeButtonFixedState extends ConsumerState<_CommentLikeButtonFixed> {
  bool _isLiked = false;
  bool _isLoading = false;
  int _likesCount = 0;
  
  @override
  void initState() {
    super.initState();
    _likesCount = widget.comment.likesCount;
    
    // 초기 좋아요 상태 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialLikeStatus();
    });
  }
  
  @override
  void didUpdateWidget(_CommentLikeButtonFixed oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 위젯이 업데이트될 때 좋아요 수 갱신
    if (oldWidget.comment.likesCount != widget.comment.likesCount) {
      setState(() {
        _likesCount = widget.comment.likesCount;
      });
    }
  }
  
  // 초기 좋아요 상태 가져오기
  Future<void> _fetchInitialLikeStatus() async {
    if (widget.userId.isEmpty) return;
    
    try {
      // 좋아요 상태 가져오기 (일회성 호출)
      final isLiked = await ref.read(commentRepositoryProvider).getLikeStatusOnce(
        widget.comment.id,
        widget.userId,
      );
      
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (e) {
      debugPrint('초기 좋아요 상태 가져오기 실패: $e');
    }
  }
  
  // 좋아요 토글 처리
  Future<void> _toggleLike() async {
    if (widget.userId.isEmpty || _isLoading) return;
    
    setState(() {
      _isLoading = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    
    try {
      // 토글 이벤트 발생 시 좋아요 토글
      await ref.read(commentControllerProvider.notifier).toggleLike(
        commentId: widget.comment.id,
        userId: widget.userId,
        postId: widget.postId,
      );
    } catch (e) {
      // 오류 발생 시 상태 되돌리기
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLike,
      child: Row(
        children: [
          // 아이콘 표시 (로딩 중이면 로딩 아이콘, 아니면 하트)
          _isLoading
              ? const CupertinoActivityIndicator(radius: 6)
              : Icon(
                  _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: _isLiked ? CupertinoColors.systemRed : AppColors.textSecondary,
                  size: 14,
                ),
          // 좋아요 수 표시
          if (_likesCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              _likesCount.toString(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}