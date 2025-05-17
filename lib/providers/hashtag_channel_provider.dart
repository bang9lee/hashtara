import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hashtag_channel_model.dart';

// 해시태그 채널 저장소 프로바이더
final hashtagChannelRepositoryProvider = Provider<HashtagChannelRepository>((ref) {
  return HashtagChannelRepository();
});

// 인기 해시태그 채널 프로바이더
final popularHashtagChannelsProvider = StreamProvider<List<HashtagChannelModel>>((ref) {
  final repository = ref.watch(hashtagChannelRepositoryProvider);
  return repository.getPopularChannels();
});

// 사용자 구독 해시태그 채널 프로바이더
final userSubscribedChannelsProvider = StreamProvider.family<List<HashtagChannelModel>, String>((ref, userId) {
  final repository = ref.watch(hashtagChannelRepositoryProvider);
  return repository.getUserSubscribedChannels(userId);
});

// 특정 해시태그 채널 프로바이더
final hashtagChannelProvider = StreamProvider.family<HashtagChannelModel?, String>((ref, channelId) {
  final repository = ref.watch(hashtagChannelRepositoryProvider);
  return repository.getChannelById(channelId);
});

// 해시태그 검색 프로바이더
final hashtagSearchProvider = StateNotifierProvider<HashtagSearchNotifier, AsyncValue<List<HashtagChannelModel>>>((ref) {
  final repository = ref.watch(hashtagChannelRepositoryProvider);
  return HashtagSearchNotifier(repository);
});

// 해시태그 검색 노티파이어
class HashtagSearchNotifier extends StateNotifier<AsyncValue<List<HashtagChannelModel>>> {
  final HashtagChannelRepository _repository;
  
  HashtagSearchNotifier(this._repository) : super(const AsyncValue.data([]));
  
  Future<void> searchHashtags(String query) async {
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    
    state = const AsyncValue.loading();
    try {
      final results = await _repository.searchChannels(query);
      state = AsyncValue.data(results);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// 해시태그 채널 관리 프로바이더
final hashtagChannelControllerProvider = StateNotifierProvider<HashtagChannelController, AsyncValue<void>>((ref) {
  final repository = ref.watch(hashtagChannelRepositoryProvider);
  return HashtagChannelController(repository);
});

class HashtagChannelController extends StateNotifier<AsyncValue<void>> {
  final HashtagChannelRepository _repository;
  
  HashtagChannelController(this._repository) : super(const AsyncValue.data(null));
  
  // 채널 구독
  Future<void> subscribeToChannel(String userId, String channelId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.subscribeToChannel(userId, channelId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 채널 구독 취소
  Future<void> unsubscribeFromChannel(String userId, String channelId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.unsubscribeFromChannel(userId, channelId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 채널 생성
  Future<String?> createChannel(HashtagChannelModel channel) async {
    state = const AsyncValue.loading();
    try {
      final channelId = await _repository.createChannel(channel);
      state = const AsyncValue.data(null);
      return channelId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
}

class HashtagChannelRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 인기 해시태그 채널 가져오기
  Stream<List<HashtagChannelModel>> getPopularChannels() {
    return _firestore
        .collection('hashtag_channels')
        .orderBy('followersCount', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => HashtagChannelModel.fromFirestore(doc))
              .toList();
        });
  }
  
  // 사용자 구독 채널 가져오기
  Stream<List<HashtagChannelModel>> getUserSubscribedChannels(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subscribed_channels')
        .snapshots()
        .asyncMap((snapshot) async {
          final List<HashtagChannelModel> channels = [];
          
          for (var doc in snapshot.docs) {
            final channelId = doc.id;
            final channelDoc = await _firestore
                .collection('hashtag_channels')
                .doc(channelId)
                .get();
                
            if (channelDoc.exists) {
              channels.add(HashtagChannelModel.fromFirestore(channelDoc));
            }
          }
          
          return channels;
        });
  }
  
  // 특정 채널 정보 가져오기
  Stream<HashtagChannelModel?> getChannelById(String channelId) {
    return _firestore
        .collection('hashtag_channels')
        .doc(channelId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return HashtagChannelModel.fromFirestore(doc);
          }
          return null;
        });
  }
  
  // 채널 검색
  Future<List<HashtagChannelModel>> searchChannels(String query) async {
    // 해시태그 앞의 # 제거
    final sanitizedQuery = query.startsWith('#') ? query.substring(1) : query;
    
    final snapshot = await _firestore
        .collection('hashtag_channels')
        .where('name', isGreaterThanOrEqualTo: sanitizedQuery)
        .where('name', isLessThanOrEqualTo: '$sanitizedQuery\uf8ff') // 문자열 보간법 사용
        .get();
        
    return snapshot.docs
        .map((doc) => HashtagChannelModel.fromFirestore(doc))
        .toList();
  }
  
  // 채널 구독
  Future<void> subscribeToChannel(String userId, String channelId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final channelRef = _firestore.collection('hashtag_channels').doc(channelId);
    
    // 트랜잭션으로 구독 처리 및 구독자 수 업데이트
    return _firestore.runTransaction((transaction) async {
      // 채널 구독자 컬렉션에 사용자 추가
      transaction.set(
        userRef.collection('subscribed_channels').doc(channelId),
        {'subscribedAt': FieldValue.serverTimestamp()},
      );
      
      // 채널의 구독자 수 증가
      transaction.update(
        channelRef,
        {'followersCount': FieldValue.increment(1)},
      );
    });
  }
  
  // 채널 구독 취소
  Future<void> unsubscribeFromChannel(String userId, String channelId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final channelRef = _firestore.collection('hashtag_channels').doc(channelId);
    
    // 트랜잭션으로 구독 취소 및 구독자 수 업데이트
    return _firestore.runTransaction((transaction) async {
      // 채널 구독자 컬렉션에서 사용자 제거
      transaction.delete(
        userRef.collection('subscribed_channels').doc(channelId),
      );
      
      // 채널의 구독자 수 감소
      transaction.update(
        channelRef,
        {'followersCount': FieldValue.increment(-1)},
      );
    });
  }
  
  // 채널 생성
  Future<String> createChannel(HashtagChannelModel channel) async {
    final docRef = await _firestore
        .collection('hashtag_channels')
        .add(channel.toMap());
        
    return docRef.id;
  }
  
  // 특정 해시태그 채널의 게시물 가져오기
  Stream<List<dynamic>> getChannelPosts(String channelId) {
    return _firestore
        .collection('posts')
        .where('hashtags', arrayContains: '#$channelId') // 문자열 보간법 사용
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data())
              .toList();
        });
  }
}