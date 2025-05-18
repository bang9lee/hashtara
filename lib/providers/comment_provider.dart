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

// 특정 게시물의 댓글 목록 프로바이더
final postCommentsProvider = StreamProvider.family<List<CommentModel>, String>((ref, postId) {
  final repository = ref.watch(commentRepositoryProvider);
  debugPrint('댓글 프로바이더 호출 - postId: $postId');
  
  return repository.getCommentsForPost(postId);
});

// 댓글 좋아요 상태 프로바이더 - 캐싱 메커니즘 추가
final commentLikeStatusProvider = StreamProvider.autoDispose.family<bool, Map<String, String>>((ref, params) {
  // 캐싱을 위해 캐시 만료를 방지
  ref.keepAlive();
  
  final repository = ref.watch(commentRepositoryProvider);
  
  // null 체크 추가 - null일 경우 기본값 사용
  final commentId = params['commentId'] ?? '';
  final userId = params['userId'] ?? '';
  
  // 유효성 검사
  if (commentId.isEmpty || userId.isEmpty) {
    debugPrint('경고: 댓글 좋아요 상태 프로바이더에 잘못된 파라미터 전달됨');
    // 빈 값인 경우 기본값 false를 반환하는 스트림
    return Stream.value(false);
  }
  
  // 초기 값과 실시간 업데이트를 결합하는 스트림 생성
  // 공유 및 캐싱을 위해 shareReplay 추가
  return repository.getLikeStatusStream(commentId, userId).shareReplay(maxSize: 1);
});

// 특정 댓글의 대댓글 프로바이더
final commentRepliesProvider = StreamProvider.family<List<CommentModel>, String>((ref, commentId) {
  final repository = ref.watch(commentRepositoryProvider);
  debugPrint('대댓글 프로바이더 호출 - commentId: $commentId');
  
  return repository.getRepliesForComment(commentId);
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
    String? parentId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('댓글 컨트롤러: 댓글 추가 시작 - postId: $postId, userId: $userId');
      
      await _repository.addComment(
        postId: postId,
        userId: userId,
        text: text,
        parentId: parentId,
      );
      
      debugPrint('댓글 컨트롤러: 댓글 추가 성공');
      
      // 댓글 추가 후 관련 데이터 새로고침
      _invalidateCommentStreams(postId, parentId);
      
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
    String? parentId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.updateComment(
        commentId: commentId,
        text: text,
      );
      
      // 댓글 수정 후 관련 데이터 새로고침
      _invalidateCommentStreams(postId, parentId);
      
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
    String? parentId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.deleteComment(
        commentId: commentId,
        postId: postId,
        parentId: parentId,
      );
      
      // 댓글 삭제 후 관련 데이터 새로고침
      _invalidateCommentStreams(postId, parentId);
      
      // 게시물 정보도 새로고침 (commentsCount 업데이트 반영)
      _ref.invalidate(postDetailProvider(postId));
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('댓글 삭제 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 좋아요 토글 - 캐시 무효화 최적화
  Future<void> toggleLike({
    required String commentId,
    required String userId,
  }) async {
    try {
      debugPrint('좋아요 토글 호출됨: $commentId, $userId');
      
      // 토글 실행 전 현재 상태 가져오기
      final currentLikeStatus = await _repository.getLikeStatusOnce(commentId, userId);
      
      // 토글 실행
      await _repository.toggleLike(
        commentId: commentId,
        userId: userId,
      );
      
      // 댓글 목록 새로고침 요청 - 좋아요 카운트 업데이트를 위해
      // 이 부분이 없으면 좋아요 상태는 변경되지만 카운트가 화면에 반영되지 않음
      _ref.invalidate(postCommentsProvider);
      
      // 기존 캐시된 상태를 읽어서 수동으로 반전시키지 않고
      // 프로바이더 자체를 무효화하여 새 값을 가져오도록 함
      final params = {'commentId': commentId, 'userId': userId};
      _ref.invalidate(commentLikeStatusProvider(params));
      
      debugPrint('좋아요 토글 완료: $commentId, 이전 상태: $currentLikeStatus');
    } catch (e) {
      debugPrint('댓글 좋아요 토글 실패: $e');
      rethrow;
    }
  }
  
  // 관련 스트림 프로바이더 무효화
  void _invalidateCommentStreams(String postId, String? parentId) {
    debugPrint('댓글 스트림 새로고침 - postId: $postId');
    
    // 게시물의 댓글 목록 새로고침
    _ref.invalidate(postCommentsProvider(postId));
    
    // 대댓글인 경우 부모 댓글의 대댓글 목록도 새로고침
    if (parentId != null) {
      _ref.invalidate(commentRepliesProvider(parentId));
    }
    
    // 게시물 상세 정보 프로바이더 (댓글 수 표시용)
    _ref.invalidate(postDetailProvider(postId));
  }
}