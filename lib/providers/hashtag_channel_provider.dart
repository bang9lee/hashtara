// hashtag_channel_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hashtag_channel_model.dart';
import '../repositories/hashtag_channel_repository.dart';

// 해시태그 채널 저장소 프로바이더
final hashtagChannelRepositoryProvider = Provider<HashtagChannelRepository>((ref) {
  return HashtagChannelRepository();
});

// 캐싱을 위한 글로벌 맵 - 애플리케이션 전체에서 공유
final _subscriptionCache = <String, bool>{};
// 캐시 키 생성 함수 - 리포지토리와 동일한 방식 사용
String _cacheKey(String userId, String channelId) => '$userId-$channelId';

// 인기 해시태그 채널 프로바이더 (최적화 버전) - 자동 게시물 수 갱신 기능 추가
final popularHashtagChannelsProvider = FutureProvider<List<HashtagChannelModel>>(
  (ref) {
    final repository = ref.watch(hashtagChannelRepositoryProvider);
    debugPrint('popularHashtagChannelsProvider 호출됨');
    
    return repository.getPopularChannelsOnce().then((channels) {
      debugPrint('인기 채널 ${channels.length}개 로드됨');
      return channels;
    });
  },
  name: 'popularHashtagChannels',
);

// 사용자 구독 해시태그 채널 프로바이더
final userSubscribedChannelsProvider = FutureProvider.family<List<HashtagChannelModel>, String>(
  (ref, userId) {
    final repository = ref.watch(hashtagChannelRepositoryProvider);
    return repository.getUserSubscribedChannelsOnce(userId);
  },
  name: 'userSubscribedChannels',
);

// 특정 해시태그 채널 프로바이더 - 자동 게시물 수 업데이트 적용
final hashtagChannelProvider = FutureProvider.family<HashtagChannelModel?, String>(
  (ref, channelId) {
    final repository = ref.watch(hashtagChannelRepositoryProvider);
    return repository.getChannelByIdOnce(channelId);
  },
  name: 'hashtagChannel',
);

// 매우 단순한 방식으로 구독 상태 확인 - String 타입 파라미터로 구현
final channelSubscriptionProvider = FutureProvider.family<bool, String>(
  (ref, combinedKey) async {
    // combinedKey = "userId:channelId" 형식으로 전달받음 - 항상 동일한 참조를 보장
    final parts = combinedKey.split(':');
    if (parts.length != 2) {
      debugPrint('잘못된 구독 키 형식: $combinedKey');
      return false;
    }
    
    final userId = parts[0];
    final channelId = parts[1];
    final cacheKey = _cacheKey(userId, channelId);
    
    // 1. 먼저 캐시 확인 - 로그 최소화
    if (_subscriptionCache.containsKey(cacheKey)) {
      // 로그를 출력하지 않음 - 성능 향상
      return _subscriptionCache[cacheKey]!;
    }
    
    // 2. 캐시에 없는 경우만 저장소 호출
    final repository = ref.watch(hashtagChannelRepositoryProvider);
    debugPrint('구독 상태 조회: $userId, $channelId');
    
    final isSubscribed = await repository.checkSubscriptionStatus(userId, channelId);
    
    // 3. 결과 캐싱 (전역 캐시만 업데이트 - StateProvider 제거)
    _subscriptionCache[cacheKey] = isSubscribed;
    debugPrint('구독 상태 갱신: $userId, $channelId = $isSubscribed');
    
    return isSubscribed;
  },
  name: 'channelSubscription',
);

// 해시태그 검색 프로바이더 - 디바운스 적용
final hashtagSearchProvider = StateNotifierProvider<HashtagSearchNotifier, AsyncValue<List<HashtagChannelModel>>>(
  (ref) {
    final repository = ref.watch(hashtagChannelRepositoryProvider);
    return HashtagSearchNotifier(repository);
  },
  name: 'hashtagSearch',
);

// 해시태그 검색 노티파이어 - 디바운스 추가
class HashtagSearchNotifier extends StateNotifier<AsyncValue<List<HashtagChannelModel>>> {
  final HashtagChannelRepository _repository;
  String _lastQuery = '';
  // 디바운스 타이머 추가
  Future<void>? _debounceTimer;

  HashtagSearchNotifier(this._repository) : super(const AsyncValue.data([]));

  Future<void> searchHashtags(String query) async {
    // 이전 검색어와 동일하면 중복 검색 방지
    if (query == _lastQuery) return;
    
    _lastQuery = query;
    
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    
    // 로딩 상태 설정
    state = const AsyncValue.loading();
    
    // 이전 타이머 취소
    _debounceTimer?.ignore();
    
    // 300ms 디바운스 적용
    _debounceTimer = Future.delayed(const Duration(milliseconds: 300), () async {
      // 쿼리가 변경되었으면 실행 중단
      if (_lastQuery != query) return;
      
      try {
        final results = await _repository.searchChannels(query);
        
        // 현재 쿼리가 여전히 유효한지 확인
        if (_lastQuery == query) {
          state = AsyncValue.data(results);
        }
      } catch (e, stack) {
        // 현재 쿼리가 여전히 유효한지 확인
        if (_lastQuery == query) {
          state = AsyncValue.error(e, stack);
        }
      }
    });
  }
}

// 해시태그 채널 관리 프로바이더
final hashtagChannelControllerProvider = StateNotifierProvider<HashtagChannelController, AsyncValue<void>>(
  (ref) {
    final repository = ref.watch(hashtagChannelRepositoryProvider);
    return HashtagChannelController(repository, ref);
  },
  name: 'hashtagChannelController',
);

class HashtagChannelController extends StateNotifier<AsyncValue<void>> {
  final HashtagChannelRepository _repository;
  final Ref _ref;

  HashtagChannelController(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> subscribeToChannel(String userId, String channelId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.subscribeToChannel(userId, channelId);
      
      // 성공 후 캐시 업데이트
      final cacheKey = _cacheKey(userId, channelId);
      _subscriptionCache[cacheKey] = true;
      
      // 구독 상태 변경 로그만 출력
      debugPrint('구독 상태 변경: $userId, $channelId = true');
      
      // 관련 프로바이더 새로고침 - 사용하지 않는 결과값 무시
      // ignore: unused_result
      _ref.refresh(popularHashtagChannelsProvider);
      // ignore: unused_result
      _ref.refresh(userSubscribedChannelsProvider(userId));
      // ignore: unused_result
      _ref.refresh(hashtagChannelProvider(channelId));
      // ignore: unused_result
      _ref.refresh(channelSubscriptionProvider('$userId:$channelId'));
      
      // 로딩 완료
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('구독 오류: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> unsubscribeFromChannel(String userId, String channelId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.unsubscribeFromChannel(userId, channelId);
      
      // 성공 후 캐시 업데이트
      final cacheKey = _cacheKey(userId, channelId);
      _subscriptionCache[cacheKey] = false;
      
      // 구독 상태 변경 로그만 출력
      debugPrint('구독 상태 변경: $userId, $channelId = false');
      
      // 관련 프로바이더 새로고침 - 사용하지 않는 결과값 무시
      // ignore: unused_result
      _ref.refresh(popularHashtagChannelsProvider);
      // ignore: unused_result
      _ref.refresh(userSubscribedChannelsProvider(userId));
      // ignore: unused_result
      _ref.refresh(hashtagChannelProvider(channelId));
      // ignore: unused_result
      _ref.refresh(channelSubscriptionProvider('$userId:$channelId'));
      
      // 로딩 완료
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('구독 취소 오류: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  // 채널 생성
  Future<String?> createChannel(HashtagChannelModel channel) async {
    state = const AsyncValue.loading();
    try {
      final channelId = await _repository.createChannel(channel);
      state = const AsyncValue.data(null);
      
      // 채널 생성 후 인기 채널 목록 새로고침
      // ignore: unused_result
      _ref.refresh(popularHashtagChannelsProvider);
      
      return channelId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  // 해시태그 채널 게시물 수 업데이트 - 개선된 버전
  Future<void> updateChannelPostsCount(String channelName) async {
    try {
      await _repository.updateHashtagChannelPostsCount(channelName);
      
      // 채널 목록 새로고침
      // ignore: unused_result
      _ref.refresh(popularHashtagChannelsProvider);
      
      // 가능한 경우 특정 채널 새로고침
      // 채널 ID를 모르기 때문에 이름을 통해 간접적으로 갱신
      final channels = await _repository.searchChannels(channelName);
      for (final channel in channels) {
        if (channel.name.toLowerCase() == channelName.toLowerCase()) {
          // ignore: unused_result
          _ref.refresh(hashtagChannelProvider(channel.id));
          break;
        }
      }
    } catch (e) {
      debugPrint('채널 게시물 수 업데이트 실패: $e');
    }
  }
}