import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../repositories/feed_repository.dart';
import '../models/post_model.dart';

// 피드 저장소 프로바이더
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});

// 피드 게시물 스트림 프로바이더
final feedPostsProvider = StreamProvider<List<PostModel>>((ref) {
  debugPrint('feedPostsProvider 초기화됨');
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getFeedPosts();
});

// 사용자 게시물 스트림 프로바이더
final userPostsProvider = StreamProvider.family<List<PostModel>, String>((ref, userId) {
  debugPrint('userPostsProvider 초기화됨: $userId');
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getUserPosts(userId);
});

// 좋아요 상태 프로바이더 (기존 캐싱 방식에서 스트림 방식으로 변경)
// 실시간 좋아요 상태 업데이트를 위한 StreamProvider로 변경
final postLikeStatusProvider = StreamProvider.family<bool, Map<String, String>>((ref, params) {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getLikeStatus(params['postId']!, params['userId']!);
});

// 북마크 상태 프로바이더
final postBookmarkStatusProvider = StreamProvider.family<bool, Map<String, String>>((ref, params) {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getBookmarkStatus(params['postId']!, params['userId']!);
});

// 게시물 상세 프로바이더 - StreamProvider를 사용하여 실시간 업데이트 지원 (에러 처리 개선)
final postDetailProvider = StreamProvider.family<PostModel?, String>((ref, postId) {
  debugPrint('postDetailProvider 호출 - postId: $postId');
  final repository = ref.watch(feedRepositoryProvider);
  
  return repository.getPostByIdStream(postId);
});

// 게시물 관리 프로바이더
final postControllerProvider = StateNotifierProvider<PostController, AsyncValue<void>>((ref) {
  final repository = ref.watch(feedRepositoryProvider);
  return PostController(repository, ref);
});

class PostController extends StateNotifier<AsyncValue<void>> {
  final FeedRepository _repository;
  final Ref _ref; // Ref 추가하여 다른 프로바이더 참조 가능
  
  PostController(this._repository, this._ref) : super(const AsyncValue.data(null));
  
  // 피드 새로고침 헬퍼 메서드 - unused_result 경고 수정
  void _refreshFeed() {
    // unused_result 경고 수정 방법: 반환값 사용하지 않음을 명시적으로 표현
    var _ = _ref.refresh(feedPostsProvider);
    debugPrint('피드 새로고침 요청됨');
  }
  
  // 사용자 게시물 새로고침 헬퍼 메서드 - unused_result 경고 수정
  void _refreshUserPosts(String userId) {
    // unused_result 경고 수정 방법: 반환값 사용하지 않음을 명시적으로 표현
    var _ = _ref.refresh(userPostsProvider(userId));
    debugPrint('사용자 게시물 새로고침 요청: $userId');
  }
  
  // 게시물 상세 새로고침 헬퍼 메서드
  void _refreshPostDetail(String postId) {
    _ref.invalidate(postDetailProvider(postId));
    debugPrint('게시물 상세 새로고침 요청됨: $postId');
  }
  
  // 좋아요 상태 새로고침 헬퍼 메서드 - unused_result 경고 수정
  void _refreshLikeStatus(String postId, String userId) {
    // unused_result 경고 수정 방법: 반환값 사용하지 않음을 명시적으로 표현
    var _ = _ref.refresh(postLikeStatusProvider({'postId': postId, 'userId': userId}));
    debugPrint('좋아요 상태 새로고침 요청됨');
  }
  
  // 북마크 상태 새로고침 헬퍼 메서드 - unused_result 경고 수정
  void _refreshBookmarkStatus(String postId, String userId) {
    // unused_result 경고 수정 방법: 반환값 사용하지 않음을 명시적으로 표현
    var _ = _ref.refresh(postBookmarkStatusProvider({'postId': postId, 'userId': userId}));
    debugPrint('북마크 상태 새로고침 요청됨');
  }
  
  // 게시물 생성
  Future<String?> createPost({
    required String userId,
    String? caption,
    List<File>? imageFiles,
    String? location,
    List<String>? hashtags,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final postId = await _repository.createPost(
        userId,
        caption,
        imageFiles,
        location,
        hashtags,
      );
      
      // 피드 새로고침
      _refreshFeed();
      _refreshUserPosts(userId);
      
      state = const AsyncValue.data(null);
      return postId;
    } catch (e, stack) {
      debugPrint('게시물 생성 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 게시물 업데이트
  Future<void> updatePost({
    required String postId,
    String? caption,
    String? location,
    List<String>? imageUrls,
    List<File>? newImageFiles,
    List<String>? hashtags,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.updatePost(
        postId: postId,
        caption: caption,
        location: location,
        imageUrls: imageUrls,
        newImageFiles: newImageFiles, 
        hashtags: hashtags,
      );
      
      // 피드와 해당 게시물 상세 정보 새로고침
      _refreshFeed();
      _refreshPostDetail(postId);
      
      // 게시물 작성자의 게시물 목록 새로고침
      final post = await _repository.getPostById(postId);
      if (post != null) {
        _refreshUserPosts(post.userId);
      }
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('게시물 업데이트 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 게시물 삭제
  Future<void> deletePost(String postId) async {
    state = const AsyncValue.loading();
    
    try {
      // 게시물 정보 미리 가져오기 (삭제 후에는 접근 불가)
      final post = await _repository.getPostById(postId);
      
      await _repository.deletePost(postId);
      
      // 피드 새로고침
      _refreshFeed();
      
      // 게시물 작성자의 게시물 목록 새로고침
      if (post != null) {
        _refreshUserPosts(post.userId);
      }
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('게시물 삭제 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 좋아요 토글
  Future<void> toggleLike(String postId, String userId) async {
    try {
      debugPrint('PostController: toggleLike 호출됨 - postId: $postId, userId: $userId');
      
      // 백엔드에 좋아요 요청 전송
      await _repository.toggleLike(postId, userId);
      
      // 관련 상태 새로고침
      _refreshLikeStatus(postId, userId);
      
      // 게시물 상세 데이터는 StreamProvider로 자동 갱신되지만, 명시적 새로고침도 요청
      _refreshPostDetail(postId);
      _refreshFeed();
      
      // 게시물 작성자의 게시물 목록도 새로고침
      final post = await _repository.getPostById(postId);
      if (post != null) {
        _refreshUserPosts(post.userId);
      }
    } catch (e) {
      debugPrint('좋아요 토글 실패: $e');
      // 오류 발생 시 UI에 알림
      state = AsyncValue.error(e, StackTrace.current);
      // 잠시 후 상태 초기화
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          state = const AsyncValue.data(null);
        }
      });
      // 에러 재발생
      rethrow;
    }
  }
  
  // 북마크 토글
  Future<void> toggleBookmark(String postId, String userId) async {
    try {
      await _repository.toggleBookmark(postId, userId);
      
      // 북마크 상태 새로고침
      _refreshBookmarkStatus(postId, userId);
    } catch (e) {
      debugPrint('북마크 토글 실패: $e');
    }
  }
}