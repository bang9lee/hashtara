import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
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
        // 수정: DocumentSnapshot -> Map<String, dynamic> 변환 및 docId 추가
        return ProfileModel.fromFirestore(doc.data() ?? {}, doc.id);
      }
      
      debugPrint('프로필이 존재하지 않음: $userId');
      // 프로필이 없으면 null 반환
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
        // 문서가 이미 존재하면 업데이트
        await _firestore.collection('profiles').doc(userId).update({
          'bio': bio,
        });
        debugPrint('기존 프로필 문서 업데이트: $userId');
      } else {
        // 문서가 없으면 새로 생성
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
            .set(newProfile.toFirestore()); // toMap -> toFirestore 변경
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
          .update(profile.toFirestore()); // toMap -> toFirestore 변경
      debugPrint('프로필 업데이트 성공');
    } catch (e) {
      // 문서가 없는 경우 새로 만들기 시도
      try {
        debugPrint('프로필 문서가 없어 새로 생성: ${profile.userId}');
        await _firestore
            .collection('profiles')
            .doc(profile.userId)
            .set(profile.toFirestore()); // toMap -> toFirestore 변경
        debugPrint('프로필 문서 생성 성공');
      } catch (innerError) {
        debugPrint('프로필 업데이트/생성 실패: $innerError');
        rethrow;
      }
    }
  }
  
  // 프로필 이미지 업로드 - 에러 처리 및 재시도 로직 보강
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      debugPrint('프로필 이미지 업로드 시도: $userId');
      debugPrint('이미지 파일 정보: 경로=${imageFile.path}, 크기=${await imageFile.length()} 바이트');
      
      // Storage 참조 생성
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      
      // 이미지 파일 메타데이터 설정
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=3600',  // 1시간 캐싱
        customMetadata: {
          'userId': userId,
          'uploadTime': DateTime.now().toIso8601String(),
        },
      );
      
      // 업로드 작업 시작
      final uploadTask = ref.putFile(imageFile, metadata);
      
      // 업로드 진행 상황 모니터링
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint('업로드 진행률: ${progress.toStringAsFixed(1)}%');
        },
        onError: (e) {
          debugPrint('업로드 상태 모니터링 오류: $e');
        },
      );
      
      // 업로드 완료 대기
      final snapshot = await uploadTask.whenComplete(() => 
        debugPrint('프로필 이미지 업로드 작업 완료'));
      
      // URL 가져오기
      final imageUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('프로필 이미지 업로드 성공: $imageUrl');
      
      // 재시도 최대 3회로 사용자 문서 업데이트
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          // 프로필 이미지 URL을 사용자 문서에 업데이트
          await _firestore.collection('users').doc(userId).update({
            'profileImageUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          debugPrint('사용자 문서 프로필 이미지 URL 업데이트 성공');
          return imageUrl;  // 성공 시 URL 반환
        } catch (e) {
          retryCount++;
          debugPrint('사용자 문서 업데이트 실패 ($retryCount/$maxRetries): $e');
          
          if (retryCount < maxRetries) {
            // 지수 백오프 대기 (0.5초, 1초, 2초...)
            final waitTime = Duration(milliseconds: 500 * (1 << (retryCount - 1)));
            debugPrint('${waitTime.inMilliseconds}ms 후 재시도...');
            await Future.delayed(waitTime);
          }
        }
      }
      
      // 이미지는 업로드됐으나 문서 업데이트 실패
      debugPrint('사용자 문서 업데이트 최대 재시도 횟수 초과');
      debugPrint('이미지는 업로드되었으나 사용자 문서 업데이트는 실패함');
      
      // 이미지 URL은 반환 (부분 성공)
      return imageUrl;
    } catch (e) {
      debugPrint('프로필 이미지 업로드 중 오류 발생: $e');
      _logger.e('프로필 이미지 업로드 실패: $e');
      
      // 상세 오류 정보 로깅
      if (e is FirebaseException) {
        debugPrint('Firebase 오류 코드: ${e.code}, 메시지: ${e.message}');
      }
      
      rethrow;
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
      
      return count ?? 0; // null 체크 추가
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
  
  // 사용자 팔로우 - 권한 오류를 방지하기 위해 수정됨
  Future<void> followUser(String followerId, String followingId) async {
    try {
      debugPrint('사용자 팔로우 시도: $followerId -> $followingId');
      
      // 이미 팔로우 중인지 확인
      final isAlreadyFollowing = await checkIfFollowing(followerId, followingId);
      if (isAlreadyFollowing) {
        debugPrint('이미 팔로우 중인 사용자입니다');
        return;
      }
      
      // 1. 팔로잉 관계 생성 - 자신의 following 컬렉션에 추가
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
      
      // 2. 팔로워 관계 생성 - 상대방의 followers 컬렉션에 추가
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
      
      // 3. 팔로잉 카운트 업데이트 - 자신의 프로필 문서
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
      
      // 4. 팔로워 카운트 업데이트 - 상대방의 프로필 문서
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
        // 팔로워 정보 가져오기
        final followerDoc = await _firestore.collection('users').doc(followerId).get();
        if (followerDoc.exists) {
          final followerData = followerDoc.data();
          final followerUsername = followerData?['username'] ?? '사용자';
          
          // 알림 생성
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
  
  // 사용자 언팔로우 - 권한 오류를 방지하기 위해 수정됨
  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      debugPrint('사용자 언팔로우 시도: $followerId -> $followingId');
      
      // 팔로우 중인지 확인
      final isFollowing = await checkIfFollowing(followerId, followingId);
      if (!isFollowing) {
        debugPrint('팔로우 중이 아닌 사용자입니다');
        return;
      }
      
      // 1. 팔로잉 관계 삭제 - 자신의 following 컬렉션에서 제거
      await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .delete();
      debugPrint('팔로잉 관계 삭제 성공');
      
      // 2. 팔로워 관계 삭제 - 상대방의 followers 컬렉션에서 제거
      await _firestore
          .collection('users')
          .doc(followingId)
          .collection('followers')
          .doc(followerId)
          .delete();
      debugPrint('팔로워 관계 삭제 성공');
      
      // 3. 팔로잉 카운트 업데이트 - 자신의 프로필 문서
      try {
        final followerProfileRef = _firestore.collection('profiles').doc(followerId);
        final followerProfileDoc = await followerProfileRef.get();
        
        if (followerProfileDoc.exists) {
          final currentFollowingCount = followerProfileDoc.data()?['followingCount'] ?? 0;
          // 음수가 되지 않도록 체크
          final newCount = currentFollowingCount > 0 ? currentFollowingCount - 1 : 0;
          await followerProfileRef.update({'followingCount': newCount});
          debugPrint('팔로잉 카운트 업데이트 성공');
        }
      } catch (e) {
        debugPrint('팔로잉 카운트 업데이트 실패 (계속 진행): $e');
      }
      
      // 4. 팔로워 카운트 업데이트 - 상대방의 프로필 문서
      try {
        final followingProfileRef = _firestore.collection('profiles').doc(followingId);
        final followingProfileDoc = await followingProfileRef.get();
        
        if (followingProfileDoc.exists) {
          final currentFollowersCount = followingProfileDoc.data()?['followersCount'] ?? 0;
          // 음수가 되지 않도록 체크
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
      
      // 팔로워 사용자 정보 조회
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
      
      // 팔로잉 사용자 정보 조회
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