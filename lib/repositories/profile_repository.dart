import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // 🔥 kIsWeb, debugPrint, Uint8List 포함
import 'package:logger/logger.dart';
import 'dart:io';
import '../models/profile_model.dart';
import '../models/user_model.dart';
import '../services/notification_handler.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();
  
  // 프로필 정보 가져오기
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      debugPrint('프로필 정보 조회: $userId');
      final doc = await _firestore.collection('profiles').doc(userId).get();
      
      if (doc.exists) {
        debugPrint('프로필 조회 성공: $userId');
        return ProfileModel.fromFirestore(doc.data() ?? {}, doc.id);
      }
      
      debugPrint('프로필이 존재하지 않음: $userId');
      return null;
    } catch (e) {
      debugPrint('프로필 조회 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 정보 가져오기 (ID로)
  Future<UserModel?> getUserById(String userId) async {
    try {
      debugPrint('사용자 정보 조회: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        debugPrint('사용자 정보 조회 성공: $userId');
        return UserModel.fromFirestore(doc);
      }
      
      debugPrint('사용자가 존재하지 않음: $userId');
      return null;
    } catch (e) {
      debugPrint('사용자 정보 조회 실패: $e');
      return null;
    }
  }
  
  // 프로필 문서 생성 메서드
  Future<void> createProfileDocument(String userId, String? bio) async {
    try {
      debugPrint('프로필 문서 생성 시도: $userId');
      final profileDoc = await _firestore.collection('profiles').doc(userId).get();
      
      if (profileDoc.exists) {
        await _firestore.collection('profiles').doc(userId).update({
          'bio': bio,
        });
        debugPrint('기존 프로필 문서 업데이트: $userId');
      } else {
        final newProfile = ProfileModel(
          userId: userId,
          bio: bio,
          postCount: 0,
          followersCount: 0,
          followingCount: 0,
        );
        
        await _firestore
            .collection('profiles')
            .doc(userId)
            .set(newProfile.toFirestore());
        debugPrint('새 프로필 문서 생성 완료: $userId');
      }
    } catch (e) {
      _logger.e("프로필 문서 생성/업데이트 오류: $e");
      debugPrint('프로필 문서 생성 실패: $e');
      rethrow;
    }
  }
  
  // 프로필 업데이트
  Future<void> updateProfile(ProfileModel profile) async {
    try {
      debugPrint('프로필 업데이트 시도: ${profile.userId}');
      await _firestore
          .collection('profiles')
          .doc(profile.userId)
          .update(profile.toFirestore());
      debugPrint('프로필 업데이트 성공');
    } catch (e) {
      try {
        debugPrint('프로필 문서가 없어 새로 생성: ${profile.userId}');
        await _firestore
            .collection('profiles')
            .doc(profile.userId)
            .set(profile.toFirestore());
        debugPrint('프로필 문서 생성 성공');
      } catch (innerError) {
        debugPrint('프로필 업데이트/생성 실패: $innerError');
        rethrow;
      }
    }
  }
  
  // 🔥 웹 호환성 강화된 프로필 이미지 업로드
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      debugPrint('🔥 프로필 이미지 업로드 시도 (플랫폼: ${kIsWeb ? '웹' : '모바일'}): $userId');
      
      // Storage 참조 생성
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      
      // 🔥 웹과 모바일에서 다른 방식으로 업로드
      late TaskSnapshot snapshot;
      
      if (kIsWeb) {
        // 🌐 웹: Uint8List 사용
        debugPrint('🌐 웹: Uint8List로 이미지 업로드');
        
        final Uint8List bytes = await imageFile.readAsBytes();
        debugPrint('🌐 웹: 이미지 바이트 읽기 완료 (크기: ${bytes.length} 바이트)');
        
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'no-cache, no-store, must-revalidate', // 🔥 캐시 비활성화
          customMetadata: {
            'userId': userId,
            'uploadTime': DateTime.now().toIso8601String(),
            'platform': 'web',
          },
        );
        
        final uploadTask = ref.putData(bytes, metadata);
        snapshot = await uploadTask;
        
      } else {
        // 📱 모바일: File 객체 사용
        debugPrint('📱 모바일: File 객체로 이미지 업로드');
        debugPrint('📱 이미지 파일 정보: 경로=${imageFile.path}, 크기=${await imageFile.length()} 바이트');
        
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=3600',
          customMetadata: {
            'userId': userId,
            'uploadTime': DateTime.now().toIso8601String(),
            'platform': 'mobile',
          },
        );
        
        final uploadTask = ref.putFile(imageFile, metadata);
        snapshot = await uploadTask;
      }
      
      // URL 가져오기
      final imageUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ 프로필 이미지 업로드 성공: $imageUrl');
      
      // 🔥 사용자 문서 업데이트 (재시도 로직 포함)
      await _updateUserProfileImage(userId, imageUrl);
      
      return imageUrl;
      
    } catch (e) {
      debugPrint('❌ 프로필 이미지 업로드 중 오류 발생: $e');
      _logger.e('프로필 이미지 업로드 실패: $e');
      
      if (e is FirebaseException) {
        debugPrint('Firebase 오류 코드: ${e.code}, 메시지: ${e.message}');
      }
      
      rethrow;
    }
  }
  
  // 🔥 사용자 프로필 이미지 URL 업데이트 (분리된 메서드)
  Future<void> _updateUserProfileImage(String userId, String imageUrl) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        debugPrint('사용자 문서 프로필 이미지 URL 업데이트 시도 (${retryCount + 1}/$maxRetries)');
        
        await _firestore.collection('users').doc(userId).update({
          'profileImageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('✅ 사용자 문서 프로필 이미지 URL 업데이트 성공');
        return;
        
      } catch (e) {
        retryCount++;
        debugPrint('❌ 사용자 문서 업데이트 실패 ($retryCount/$maxRetries): $e');
        
        if (retryCount < maxRetries) {
          final waitTime = Duration(milliseconds: 500 * (1 << (retryCount - 1)));
          debugPrint('${waitTime.inMilliseconds}ms 후 재시도...');
          await Future.delayed(waitTime);
        } else {
          debugPrint('❌ 사용자 문서 업데이트 최대 재시도 횟수 초과');
          throw Exception('사용자 문서 업데이트 실패: $e');
        }
      }
    }
  }
  
  // 사용자의 게시물 수 가져오기
  Future<int> getUserPostsCount(String userId) async {
    try {
      debugPrint('사용자 게시물 수 조회: $userId');
      
      final snapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      
      final count = snapshot.count;
      debugPrint('사용자 게시물 수: $count');
      
      return count ?? 0;
    } catch (e) {
      debugPrint('게시물 수 조회 실패: $e');
      return 0;
    }
  }
  
  // 팔로우 확인
  Future<bool> checkIfFollowing(String followerId, String followingId) async {
    try {
      debugPrint('팔로우 상태 확인: $followerId -> $followingId');
      
      final doc = await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .get();
      
      final isFollowing = doc.exists;
      debugPrint('팔로우 상태: ${isFollowing ? "팔로우 중" : "팔로우하지 않음"}');
      
      return isFollowing;
    } catch (e) {
      debugPrint('팔로우 상태 확인 오류: $e');
      return false;
    }
  }
  
  // 사용자 팔로우
  Future<void> followUser(String followerId, String followingId) async {
    try {
      debugPrint('사용자 팔로우 시도: $followerId -> $followingId');
      
      final isAlreadyFollowing = await checkIfFollowing(followerId, followingId);
      if (isAlreadyFollowing) {
        debugPrint('이미 팔로우 중인 사용자입니다');
        return;
      }
      
      // 1. 팔로잉 관계 생성
      await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .set({
            'userId': followingId,
            'createdAt': FieldValue.serverTimestamp(),
          });
      debugPrint('팔로잉 관계 생성 성공');
      
      // 2. 팔로워 관계 생성
      await _firestore
          .collection('users')
          .doc(followingId)
          .collection('followers')
          .doc(followerId)
          .set({
            'userId': followerId,
            'createdAt': FieldValue.serverTimestamp(),
          });
      debugPrint('팔로워 관계 생성 성공');
      
      // 3. 팔로잉 카운트 업데이트
      try {
        final followerProfileRef = _firestore.collection('profiles').doc(followerId);
        final followerProfileDoc = await followerProfileRef.get();
        
        if (followerProfileDoc.exists) {
          final currentFollowingCount = followerProfileDoc.data()?['followingCount'] ?? 0;
          await followerProfileRef.update({'followingCount': currentFollowingCount + 1});
          debugPrint('팔로잉 카운트 업데이트 성공');
        }
      } catch (e) {
        debugPrint('팔로잉 카운트 업데이트 실패 (계속 진행): $e');
      }
      
      // 4. 팔로워 카운트 업데이트
      try {
        final followingProfileRef = _firestore.collection('profiles').doc(followingId);
        final followingProfileDoc = await followingProfileRef.get();
        
        if (followingProfileDoc.exists) {
          final currentFollowersCount = followingProfileDoc.data()?['followersCount'] ?? 0;
          await followingProfileRef.update({'followersCount': currentFollowersCount + 1});
          debugPrint('팔로워 카운트 업데이트 성공');
        }
      } catch (e) {
        debugPrint('팔로워 카운트 업데이트 실패 (계속 진행): $e');
      }
      
      // 5. 알림 생성
      try {
        final followerDoc = await _firestore.collection('users').doc(followerId).get();
        if (followerDoc.exists) {
          final followerData = followerDoc.data();
          final followerUsername = followerData?['username'] ?? '사용자';
          
          final notificationHandler = NotificationHandler();
          await notificationHandler.createFollowNotification(
            followerId: followerId,
            followingId: followingId,
            followerUsername: followerUsername,
          );
          debugPrint('팔로우 알림 생성 성공');
        }
      } catch (e) {
        debugPrint('팔로우 알림 생성 실패 (계속 진행): $e');
      }
      
      debugPrint('사용자 팔로우 성공: $followerId -> $followingId');
    } catch (e) {
      debugPrint('사용자 팔로우 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 언팔로우
  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      debugPrint('사용자 언팔로우 시도: $followerId -> $followingId');
      
      final isFollowing = await checkIfFollowing(followerId, followingId);
      if (!isFollowing) {
        debugPrint('팔로우 중이 아닌 사용자입니다');
        return;
      }
      
      // 1. 팔로잉 관계 삭제
      await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .delete();
      debugPrint('팔로잉 관계 삭제 성공');
      
      // 2. 팔로워 관계 삭제
      await _firestore
          .collection('users')
          .doc(followingId)
          .collection('followers')
          .doc(followerId)
          .delete();
      debugPrint('팔로워 관계 삭제 성공');
      
      // 3. 팔로잉 카운트 업데이트
      try {
        final followerProfileRef = _firestore.collection('profiles').doc(followerId);
        final followerProfileDoc = await followerProfileRef.get();
        
        if (followerProfileDoc.exists) {
          final currentFollowingCount = followerProfileDoc.data()?['followingCount'] ?? 0;
          final newCount = currentFollowingCount > 0 ? currentFollowingCount - 1 : 0;
          await followerProfileRef.update({'followingCount': newCount});
          debugPrint('팔로잉 카운트 업데이트 성공');
        }
      } catch (e) {
        debugPrint('팔로잉 카운트 업데이트 실패 (계속 진행): $e');
      }
      
      // 4. 팔로워 카운트 업데이트
      try {
        final followingProfileRef = _firestore.collection('profiles').doc(followingId);
        final followingProfileDoc = await followingProfileRef.get();
        
        if (followingProfileDoc.exists) {
          final currentFollowersCount = followingProfileDoc.data()?['followersCount'] ?? 0;
          final newCount = currentFollowersCount > 0 ? currentFollowersCount - 1 : 0;
          await followingProfileRef.update({'followersCount': newCount});
          debugPrint('팔로워 카운트 업데이트 성공');
        }
      } catch (e) {
        debugPrint('팔로워 카운트 업데이트 실패 (계속 진행): $e');
      }
      
      debugPrint('사용자 언팔로우 성공: $followerId -> $followingId');
    } catch (e) {
      debugPrint('사용자 언팔로우 실패: $e');
      rethrow;
    }
  }
  
  // 팔로워 목록 가져오기
  Future<List<UserModel>> getFollowers(String userId) async {
    try {
      debugPrint('팔로워 목록 조회: $userId');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .orderBy('createdAt', descending: true)
          .get();
      
      final followerIds = snapshot.docs.map((doc) => doc.id).toList();
      
      if (followerIds.isEmpty) {
        return [];
      }
      
      final followers = <UserModel>[];
      for (final id in followerIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(id).get();
          if (userDoc.exists) {
            followers.add(UserModel.fromFirestore(userDoc));
          }
        } catch (e) {
          debugPrint('팔로워 정보 조회 실패: $id, $e');
        }
      }
      
      debugPrint('팔로워 ${followers.length}명 조회 완료');
      return followers;
    } catch (e) {
      debugPrint('팔로워 목록 조회 실패: $e');
      return [];
    }
  }
  
  // 팔로잉 목록 가져오기
  Future<List<UserModel>> getFollowing(String userId) async {
    try {
      debugPrint('팔로잉 목록 조회: $userId');
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .orderBy('createdAt', descending: true)
          .get();
      
      final followingIds = snapshot.docs.map((doc) => doc.id).toList();
      
      if (followingIds.isEmpty) {
        return [];
      }
      
      final following = <UserModel>[];
      for (final id in followingIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(id).get();
          if (userDoc.exists) {
            following.add(UserModel.fromFirestore(userDoc));
          }
        } catch (e) {
          debugPrint('팔로잉 정보 조회 실패: $id, $e');
        }
      }
      
      debugPrint('팔로잉 ${following.length}명 조회 완료');
      return following;
    } catch (e) {
      debugPrint('팔로잉 목록 조회 실패: $e');
      return [];
    }
  }
}