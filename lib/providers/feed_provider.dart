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

// 좋아요 상태 프로바이더
final postLikeStatusProvider = StreamProvider.family<bool, Map<String, String>>((ref, params) {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getLikeStatus(params['postId']!, params['userId']!);
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
  
  // 게시물 생성
  Future<String?> createPost({
    required String userId,
    String? caption,
    List<File>? imageFiles,
    String? location,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final postId = await _repository.createPost(
        userId,
        caption,
        imageFiles,
        location,
      );
      
      // 피드 새로고침 - unused_result 경고 해결
      var feedRefresh = _ref.refresh(feedPostsProvider);
      var userPostsRefresh = _ref.refresh(userPostsProvider(userId));
      
      // 실제로 값을 사용하여 린트 경고 제거
      debugPrint('프로바이더 새로고침: ${feedRefresh.hashCode}, ${userPostsRefresh.hashCode}');
      
      state = const AsyncValue.data(null);
      return postId;
    } catch (e, stack) {
      debugPrint('게시물 생성 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 좋아요 토글
  Future<void> toggleLike(String postId, String userId) async {
    try {
      await _repository.toggleLike(postId, userId);
    } catch (e) {
      debugPrint('좋아요 토글 실패: $e');
    }
  }
}