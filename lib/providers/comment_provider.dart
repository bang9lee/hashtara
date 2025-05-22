import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment_model.dart';
import '../repositories/comment_repository.dart';
import 'feed_provider.dart';
import 'package:rxdart/rxdart.dart';

// 댓글 저장소 프로바이더
final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository();
});

// 특정 게시물의 댓글 목록 프로바이더 - 캐싱 및 성능 최적화
final postCommentsProvider = StreamProvider.family<List<CommentModel>, String>((ref, postId) {
  final repository = ref.watch(commentRepositoryProvider);
  debugPrint('댓글 프로바이더 호출 - postId: $postId');
  
  // 스트림 공유 및 캐싱
  return repository.getCommentsForPost(postId)
    .shareReplay(maxSize: 1); // 마지막 값만 캐싱
});

// 특정 댓글에 대한 답글 프로바이더
final commentRepliesProvider = StreamProvider.family<List<CommentModel>, String>((ref, commentId) {
  final repository = ref.watch(commentRepositoryProvider);
  debugPrint('답글 프로바이더 호출 - commentId: $commentId');
  
  // 스트림 공유 및 캐싱
  return repository.getRepliesForComment(commentId)
    .shareReplay(maxSize: 1); // 마지막 값만 캐싱
});

// 댓글 컨트롤러 프로바이더
final commentControllerProvider = StateNotifierProvider<CommentController, AsyncValue<void>>((ref) {
  final repository = ref.watch(commentRepositoryProvider);
  return CommentController(repository, ref);
});

class CommentController extends StateNotifier<AsyncValue<void>> {
  final CommentRepository _repository;
  final Ref _ref;
  
  CommentController(this._repository, this._ref) : super(const AsyncValue.data(null));
  
  // 댓글 추가
  Future<void> addComment({
    required String postId,
    required String userId,
    required String text,
    String? replyToCommentId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('댓글 컨트롤러: 댓글 추가 시작 - postId: $postId, userId: $userId');
      
      await _repository.addComment(
        postId: postId,
        userId: userId,
        text: text,
        replyToCommentId: replyToCommentId,
      );
      
      debugPrint('댓글 컨트롤러: 댓글 추가 성공');
      
      // 댓글 추가 후 관련 데이터 새로고침
      _invalidateCommentStreams(postId, replyToCommentId);
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('댓글 컨트롤러: 댓글 추가 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 댓글 수정
  Future<void> updateComment({
    required String commentId,
    required String postId,
    required String text,
    String? replyToCommentId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.updateComment(
        commentId: commentId,
        text: text,
      );
      
      // 댓글 수정 후 관련 데이터 새로고침
      _invalidateCommentStreams(postId, replyToCommentId);
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('댓글 수정 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 댓글 삭제
  Future<void> deleteComment({
    required String commentId,
    required String postId,
    bool isReply = false,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.deleteComment(
        commentId: commentId,
        postId: postId,
        isReply: isReply,
      );
      
      // 댓글 삭제 후 관련 데이터 새로고침
      if (isReply) {
        // 답글인 경우 부모 댓글에 대한 스트림도 새로고침
        _ref.invalidate(commentRepliesProvider(commentId));
      } else {
        _invalidateCommentStreams(postId, null);
      }
      
      // 게시물 정보도 새로고침 (commentsCount 업데이트 반영)
      _ref.invalidate(postDetailProvider(postId));
      
      // 🔥 피드 프로바이더도 새로고침 (홈 화면 댓글 수 업데이트)
      _ref.invalidate(feedPostsProvider);
      debugPrint('🔥 댓글 삭제 후 피드 프로바이더 갱신 완료');
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('댓글 삭제 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 관련 스트림 프로바이더 무효화 - 피드 갱신 추가
  void _invalidateCommentStreams(String postId, String? replyToCommentId) {
    debugPrint('댓글 스트림 새로고침 - postId: $postId');
    
    // 게시물의 댓글 목록 새로고침
    _ref.invalidate(postCommentsProvider(postId));
    
    // 답글인 경우 해당 댓글의 답글 목록도 새로고침
    if (replyToCommentId != null) {
      _ref.invalidate(commentRepliesProvider(replyToCommentId));
    }
    
    // 게시물 상세 정보 프로바이더 (댓글 수 표시용)
    _ref.invalidate(postDetailProvider(postId));
    
    // 🔥 피드 프로바이더도 새로고침 (홈 화면 댓글 수 업데이트)
    _ref.invalidate(feedPostsProvider);
    debugPrint('🔥 피드 프로바이더 갱신 완료');
  }
}