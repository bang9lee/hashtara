import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/profile_model.dart';

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
        return ProfileModel.fromFirestore(doc);
      }
      
      debugPrint('프로필이 존재하지 않음: $userId');
      // 프로필이 없으면 null 반환
      return null;
    } catch (e) {
      debugPrint('프로필 조회 실패: $e');
      rethrow;
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
            .set(newProfile.toMap());
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
          .update(profile.toMap());
      debugPrint('프로필 업데이트 성공');
    } catch (e) {
      // 문서가 없는 경우 새로 만들기 시도
      try {
        debugPrint('프로필 문서가 없어 새로 생성: ${profile.userId}');
        await _firestore
            .collection('profiles')
            .doc(profile.userId)
            .set(profile.toMap());
        debugPrint('프로필 문서 생성 성공');
      } catch (innerError) {
        debugPrint('프로필 업데이트/생성 실패: $innerError');
        rethrow;
      }
    }
  }
  
  // 프로필 이미지 업로드
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      debugPrint('프로필 이미지 업로드 시도: $userId');
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      
      // 이미지 파일 메타데이터 설정
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=1',  // 캐시 제어 설정 추가
        ),
      );
      
      final snapshot = await uploadTask.whenComplete(() {});
      final imageUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('프로필 이미지 업로드 성공: $imageUrl');
      
      // 프로필 이미지 URL을 사용자 문서에도 업데이트
      await _firestore.collection('users').doc(userId).update({
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('사용자 문서 프로필 이미지 URL 업데이트 성공');
      
      return imageUrl;
    } catch (e) {
      debugPrint('프로필 이미지 업로드 실패: $e');
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
}