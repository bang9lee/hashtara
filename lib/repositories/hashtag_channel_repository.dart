import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hashtag_channel_model.dart';

class HashtagChannelRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  // 메모리 내 캐시 맵 추가 - 중복 요청 방지
  final Map<String, bool> _subscriptionCache = {};
  String _getCacheKey(String userId, String channelId) => '$userId-$channelId';

  // 사용자가 채널을 구독했는지 확인하는 메서드 - 스트림 버전
  Stream<bool> isChannelSubscribed(String userId, String channelId) {
    try {
      final cacheKey = _getCacheKey(userId, channelId);
      debugPrint('구독 상태 확인: 사용자=$userId, 채널=$channelId');
      
      // 실시간 구독 상태 모니터링 - includeMetadataChanges 사용
      return firestore
          .collection('users')
          .doc(userId)
          .collection('subscribed_channels')
          .doc(channelId)
          .snapshots(includeMetadataChanges: true)
          .map((doc) {
            final isSubscribed = doc.exists;
            _subscriptionCache[cacheKey] = isSubscribed; // 캐시 업데이트
            debugPrint('구독 상태 확인 결과: ${isSubscribed ? "구독중" : "미구독"} [소스: ${doc.metadata.isFromCache ? "캐시" : "서버"}]');
            return isSubscribed;
          });
    } catch (e) {
      debugPrint('구독 상태 확인 오류: $e');
      return Stream.value(false);
    }
  }
  
  // 즉시 구독 상태 확인 (단일 Future) - 무한 로딩 문제 해결용
  Future<bool> checkSubscriptionStatus(String userId, String channelId) async {
    try {
      final cacheKey = _getCacheKey(userId, channelId);
      
      // 캐시에 있으면 캐시 값 반환
      if (_subscriptionCache.containsKey(cacheKey)) {
        debugPrint('구독 상태 캐시 히트: $cacheKey = ${_subscriptionCache[cacheKey]}');
        return _subscriptionCache[cacheKey]!;
      }
      
      debugPrint('구독 상태 확인 (Firebase 요청): $cacheKey');
      
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('subscribed_channels')
          .doc(channelId)
          .get();
          
      final isSubscribed = doc.exists;
      _subscriptionCache[cacheKey] = isSubscribed; // 캐시 저장
      debugPrint('구독 상태 확인 결과 (단일 요청): ${isSubscribed ? "구독중" : "미구독"}');
      return isSubscribed;
    } catch (e) {
      debugPrint('구독 상태 확인 오류: $e');
      return false;
    }
  }
  
  // 구독 상태 캐시 무효화
  Future<void> invalidateChannelSubscriptionCache(String userId, String channelId) async {
    final cacheKey = _getCacheKey(userId, channelId);
    _subscriptionCache.remove(cacheKey); // 캐시에서 제거
    
    try {
      // 서버에서 직접 데이터 가져와서 캐시 갱신
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('subscribed_channels')
          .doc(channelId)
          .get(const GetOptions(source: Source.server));
          
      _subscriptionCache[cacheKey] = doc.exists; // 새로운 값으로 캐시 갱신
      debugPrint('구독 상태 캐시 갱신 완료: $cacheKey = ${doc.exists}');
    } catch (e) {
      debugPrint('구독 상태 캐시 갱신 실패: $e');
    }
  }
  
  // 채널 구독하기
  Future<void> subscribeToChannel(String userId, String channelId) async {
    final userRef = firestore.collection('users').doc(userId);
    final channelRef = firestore.collection('hashtag_channels').doc(channelId);
    
    try {
      // 중요: 트랜잭션 전에 현재 값 먼저 확인
      final channelDoc = await channelRef.get();
      final int currentFollowersCount = (channelDoc.data()?['followersCount'] as int?) ?? 0;
      
      debugPrint('구독 전 현재 구독자 수: $currentFollowersCount');
      
      // 구독 문서 존재 여부 확인
      final subscriptionDoc = await userRef.collection('subscribed_channels').doc(channelId).get();
      if (subscriptionDoc.exists) {
        debugPrint('이미 구독 중인 채널입니다. 중복 구독 방지');
        return; // 이미 구독 중이면 아무 작업도 하지 않음
      }
      
      // 트랜잭션 내에서 실행하여 정합성 보장
      await firestore.runTransaction((transaction) async {
        // 구독 문서 생성
        transaction.set(
          userRef.collection('subscribed_channels').doc(channelId),
          {'subscribedAt': FieldValue.serverTimestamp()},
        );
        
        // 채널 구독자 수 증가 (안전하게 현재 값에서 1 증가)
        transaction.update(
          channelRef, 
          {'followersCount': currentFollowersCount + 1}
        );
      });
      
      // 캐시 업데이트
      final cacheKey = _getCacheKey(userId, channelId);
      _subscriptionCache[cacheKey] = true;
      
      // 확인을 위해 업데이트된 값 조회
      final updatedDoc = await channelRef.get();
      final int newFollowersCount = (updatedDoc.data()?['followersCount'] as int?) ?? 0;
      
      debugPrint('채널 구독 성공: 사용자=$userId, 채널=$channelId, 구독자=$newFollowersCount');
    } catch (e) {
      debugPrint('채널 구독 오류: $e');
      rethrow;
    }
  }
  
  // 채널 구독 취소
  Future<void> unsubscribeFromChannel(String userId, String channelId) async {
    try {
      final userRef = firestore.collection('users').doc(userId);
      final channelRef = firestore.collection('hashtag_channels').doc(channelId);
      
      // 중요: 트랜잭션 전에 현재 값 먼저 확인
      final channelDoc = await channelRef.get();
      int currentFollowersCount = (channelDoc.data()?['followersCount'] as int?) ?? 0;
      
      debugPrint('구독 취소 전 현재 구독자 수: $currentFollowersCount');
      
      // 구독 문서 존재 여부 확인
      final subscriptionDoc = await userRef.collection('subscribed_channels').doc(channelId).get();
      if (!subscriptionDoc.exists) {
        debugPrint('이미 구독 취소된 채널입니다. 중복 취소 방지');
        return; // 이미 구독 취소되었으면 아무 작업도 하지 않음
      }
      
      // 음수가 되지 않도록 방지
      if (currentFollowersCount <= 0) {
        currentFollowersCount = 0;
        debugPrint('구독자 수가 이미 0 이하입니다. 0으로 설정');
      }
      
      // 트랜잭션으로 변경하여 정합성 보장
      await firestore.runTransaction((transaction) async {
        // 1. 구독 문서 삭제
        transaction.delete(userRef.collection('subscribed_channels').doc(channelId));
        
        // 2. 채널 구독자 수 감소 (음수가 되지 않도록 현재 값에서 계산)
        final newFollowersCount = currentFollowersCount > 0 ? currentFollowersCount - 1 : 0;
        transaction.update(channelRef, {'followersCount': newFollowersCount});
      });
      
      // 캐시 업데이트
      final cacheKey = _getCacheKey(userId, channelId);
      _subscriptionCache[cacheKey] = false;
      
      // 확인을 위해 업데이트된 값 조회
      final updatedDoc = await channelRef.get();
      final int newFollowersCount = (updatedDoc.data()?['followersCount'] as int?) ?? 0;
      
      debugPrint('채널 구독 취소 성공: 사용자=$userId, 채널=$channelId, 구독자=$newFollowersCount');
    } catch (e) {
      debugPrint('구독 취소 오류: $e');
      rethrow; // 오류를 상위로 전파
    }
  }
  
  // 인기 해시태그 채널 가져오기 (단일 요청 Future 버전)
  Future<List<HashtagChannelModel>> getPopularChannelsOnce() async {
    debugPrint('인기 해시태그 채널 단일 요청');
    
    try {
      final snapshot = await firestore
          .collection('hashtag_channels')
          .orderBy('followersCount', descending: true)
          .limit(10)
          .get();
      
      final channels = snapshot.docs
          .map((doc) {
            try {
              return HashtagChannelModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('채널 변환 오류: $e');
              return null;
            }
          })
          .where((channel) => channel != null)
          .whereType<HashtagChannelModel>()
          .toList();
      
      // 각 채널의 postsCount 업데이트 (추가된 부분)
      for (final channel in channels) {
        await _updateChannelPostsCount(channel);
      }
      
      return channels;
    } catch (e) {
      debugPrint('인기 채널 로드 오류: $e');
      return [];
    }
  }
  
  // 사용자 구독 채널 가져오기 (단일 요청 Future 버전)
  Future<List<HashtagChannelModel>> getUserSubscribedChannelsOnce(String userId) async {
    debugPrint('사용자 구독 채널 단일 요청: $userId');
    
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('subscribed_channels')
          .get();
      
      if (snapshot.docs.isEmpty) {
        return [];
      }
      
      final futures = <Future<HashtagChannelModel?>>[];
      
      for (var doc in snapshot.docs) {
        final channelId = doc.id;
        futures.add(_fetchChannelById(channelId));
      }
      
      final results = await Future.wait(futures);
      
      final List<HashtagChannelModel> channels = results
          .where((channel) => channel != null)
          .whereType<HashtagChannelModel>()
          .toList();
      
      // 각 채널의 postsCount 업데이트 (추가된 부분)
      for (final channel in channels) {
        await _updateChannelPostsCount(channel);
      }
      
      return channels;
    } catch (e) {
      debugPrint('사용자 구독 채널 로드 오류: $e');
      return [];
    }
  }
  
  // 채널 정보 가져오기 (단일)
  Future<HashtagChannelModel?> _fetchChannelById(String channelId) async {
    try {
      final doc = await firestore
          .collection('hashtag_channels')
          .doc(channelId)
          .get();
          
      if (doc.exists) {
        final channel = HashtagChannelModel.fromFirestore(doc);
        // 게시물 수 업데이트 (추가된 부분)
        await _updateChannelPostsCount(channel);
        return channel;
      }
      return null;
    } catch (e) {
      debugPrint('채널 정보 가져오기 오류: $e');
      return null;
    }
  }
  
  // 특정 채널 정보 가져오기 (단일 요청 Future 버전)
  Future<HashtagChannelModel?> getChannelByIdOnce(String channelId) async {
    try {
      final doc = await firestore
          .collection('hashtag_channels')
          .doc(channelId)
          .get();
          
      if (doc.exists) {
        final channel = HashtagChannelModel.fromFirestore(doc);
        // 게시물 수 업데이트 (추가된 부분)
        await _updateChannelPostsCount(channel);
        return channel;
      }
      return null;
    } catch (e) {
      debugPrint('채널 정보 조회 오류: $e');
      return null;
    }
  }
  
  // 채널 검색
  Future<List<HashtagChannelModel>> searchChannels(String query) async {
    debugPrint('해시태그 검색: $query');
    
    try {
      final sanitizedQuery = query.startsWith('#') ? query.substring(1) : query;
      
      final snapshot = await firestore
          .collection('hashtag_channels')
          .where('name', isGreaterThanOrEqualTo: sanitizedQuery)
          .where('name', isLessThanOrEqualTo: '$sanitizedQuery\uf8ff')
          .limit(20)
          .get();
      
      final channels = snapshot.docs
          .map((doc) {
            try {
              return HashtagChannelModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('채널 변환 오류: $e');
              return null;
            }
          })
          .where((channel) => channel != null)
          .whereType<HashtagChannelModel>()
          .toList();
      
      // 각 채널의 postsCount 업데이트 (추가된 부분)
      for (final channel in channels) {
        await _updateChannelPostsCount(channel);
      }
      
      return channels;
    } catch (e) {
      debugPrint('채널 검색 오류: $e');
      return [];
    }
  }
  
  // 채널 생성
  Future<String> createChannel(HashtagChannelModel channel) async {
    debugPrint('채널 생성 시도: ${channel.name}');
    
    // 먼저 같은 이름의 채널이 있는지 확인
    final querySnapshot = await firestore
        .collection('hashtag_channels')
        .where('name', isEqualTo: channel.name)
        .get();
    
    // 이미 존재하는 채널이 있으면 해당 채널 ID 반환
    if (querySnapshot.docs.isNotEmpty) {
      final existingChannelId = querySnapshot.docs.first.id;
      debugPrint('이미 존재하는 채널 발견: $existingChannelId');
      
      // 게시물 수 업데이트 (추가된 부분)
      await updateHashtagChannelPostsCount(channel.name);
      
      return existingChannelId;
    }
    
    // 존재하지 않으면 새 채널 생성
    // 게시물 수 계산 (추가된 부분)
    final countSnapshot = await firestore
        .collection('posts')
        .where('hashtags', arrayContains: '#${channel.name}')
        .count()
        .get();
    final postsCount = countSnapshot.count ?? 0;
    
    // 게시물 수 설정
    final channelMap = channel.toMap();
    channelMap['postsCount'] = postsCount;
    
    final docRef = await firestore
        .collection('hashtag_channels')
        .add(channelMap);
    
    debugPrint('새 채널 생성됨: ${docRef.id}, 게시물 수: $postsCount');    
    return docRef.id;
  }
  
  // 해시태그 채널의 게시물 수 업데이트 (개선된 버전)
  Future<void> updateHashtagChannelPostsCount(String channelName) async {
    try {
      // 해당 해시태그를 포함한 게시물 수 계산
      final countSnapshot = await firestore
          .collection('posts')
          .where('hashtags', arrayContains: '#$channelName')
          .count()
          .get();
          
      final count = countSnapshot.count ?? 0;
      debugPrint('채널 "$channelName"의 실제 게시물 수: $count');
      
      // 해당 이름의 채널 문서 찾기
      final querySnapshot = await firestore
          .collection('hashtag_channels')
          .where('name', isEqualTo: channelName)
          .get();
          
      if (querySnapshot.docs.isNotEmpty) {
        final channelId = querySnapshot.docs.first.id;
        final currentCount = querySnapshot.docs.first.data()['postsCount'] ?? 0;
        
        // 현재 값과 다를 경우에만 업데이트
        if (currentCount != count) {
          debugPrint('채널 "$channelName" 게시물 수 업데이트: $currentCount → $count');
          await firestore
              .collection('hashtag_channels')
              .doc(channelId)
              .update({'postsCount': count});
        } else {
          debugPrint('채널 "$channelName" 게시물 수 변경 없음 (현재: $currentCount)');
        }
      } else {
        debugPrint('채널 "$channelName"을 찾을 수 없음');
      }
    } catch (e) {
      debugPrint('채널 게시물 수 업데이트 실패: $e');
    }
  }
  
  // 채널 모델의 게시물 수 업데이트 헬퍼 메서드 (추가된 부분)
  Future<void> _updateChannelPostsCount(HashtagChannelModel channel) async {
    try {
      // 해당 해시태그를 포함한 게시물 수 계산
      final countSnapshot = await firestore
          .collection('posts')
          .where('hashtags', arrayContains: '#${channel.name}')
          .count()
          .get();
          
      final count = countSnapshot.count ?? 0;
      
      // 게시물 수가 다른 경우에만 업데이트
      if (channel.postsCount != count) {
        debugPrint('채널 "${channel.name}" 게시물 수 불일치: ${channel.postsCount} (저장) vs $count (실제)');
        
        // 1. 메모리에서 즉시 업데이트
        channel.updatePostsCount(count);
        
        // 2. 데이터베이스도 업데이트
        await firestore
            .collection('hashtag_channels')
            .doc(channel.id)
            .update({'postsCount': count});
      }
    } catch (e) {
      debugPrint('채널 게시물 수 업데이트 오류: $e');
    }
  }
}