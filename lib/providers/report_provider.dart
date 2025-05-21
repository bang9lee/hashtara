import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/report_repository.dart';

// 신고 저장소 프로바이더
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

// 사용자가 신고한 게시물 ID 목록 Provider (Future 기반)
final userReportedPostIdsProvider = FutureProvider.family<List<String>, String>((ref, userId) async {
  debugPrint('userReportedPostIdsProvider 호출됨: $userId');
  final repository = ref.watch(reportRepositoryProvider);
  return await repository.getUserReportedPostIds(userId);
});

// 사용자가 신고한 게시물 ID 목록 Stream Provider (실시간 업데이트)
final userReportedPostIdsStreamProvider = StreamProvider.family<List<String>, String>((ref, userId) {
  debugPrint('userReportedPostIdsStreamProvider 호출됨: $userId');
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getUserReportedPostIdsStream(userId);
});

// 게시물 신고 여부 확인 Provider
final hasUserReportedPostProvider = FutureProvider.family<bool, Map<String, String>>((ref, params) async {
  final userId = params['userId']!;
  final postId = params['postId']!;
  
  debugPrint('hasUserReportedPostProvider 호출됨: $userId -> $postId');
  final repository = ref.watch(reportRepositoryProvider);
  return await repository.hasUserReportedPost(userId, postId);
});

// 신고 Controller
final reportControllerProvider = StateNotifierProvider<ReportController, AsyncValue<void>>((ref) {
  final repository = ref.watch(reportRepositoryProvider);
  return ReportController(repository, ref);
});

class ReportController extends StateNotifier<AsyncValue<void>> {
  final ReportRepository _repository;
  final Ref _ref;
  
  ReportController(this._repository, this._ref) : super(const AsyncValue.data(null));
  
  // 게시물 신고 함수
  Future<void> reportPost({
    required String userId,
    required String postId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('ReportController: 게시물 신고 요청 - $userId, $postId, $reason');
      
      await _repository.reportPost(
        userId: userId,
        postId: postId,
        reason: reason,
      );
      
      // 신고된 게시물 목록 새로고침
      var refreshResult1 = _ref.refresh(userReportedPostIdsProvider(userId));
      var refreshResult2 = _ref.refresh(userReportedPostIdsStreamProvider(userId));
      
      // 린트 경고 방지를 위해 변수를 사용
      debugPrint('피드 새로고침 결과: ${refreshResult1.hashCode}, ${refreshResult2.hashCode}');
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('게시물 신고 실패: $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
  
  // 신고 취소 함수 (테스트용)
  Future<void> cancelReport({
    required String userId,
    required String postId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('ReportController: 신고 취소 요청 - $userId, $postId');
      
      await _repository.cancelReport(
        userId: userId,
        postId: postId,
      );
      
      // 신고된 게시물 목록 새로고침
      var refreshResult1 = _ref.refresh(userReportedPostIdsProvider(userId));
      var refreshResult2 = _ref.refresh(userReportedPostIdsStreamProvider(userId));
      
      // 린트 경고 방지를 위해 변수를 사용
      debugPrint('피드 새로고침 결과: ${refreshResult1.hashCode}, ${refreshResult2.hashCode}');
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('신고 취소 실패: $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}