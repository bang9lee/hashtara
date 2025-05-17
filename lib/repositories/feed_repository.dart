import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../models/post_model.dart';

class FeedRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // 피드 게시물 가져오기 - 개선된 버전
  Stream<List<PostModel>> getFeedPosts() {
    try {
      debugPrint('피드 게시물 로드 시도 중...');
      
      // 최신 게시물부터 20개 로드
      return _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) {
            debugPrint('피드 문서 ${snapshot.docs.length}개 받음');
            
            // 문서가 있는지 확인하고 로그 남기기
            if (snapshot.docs.isEmpty) {
              debugPrint('⚠️ 피드에 게시물이 없습니다!');
            } else {
              for (var doc in snapshot.docs) {
                debugPrint('게시물 ID: ${doc.id}, 작성자: ${doc.data()['userId']}');
                // Firestore 데이터 확인을 위한 디버그 로그 추가
                debugPrint('게시물 데이터: ${doc.data()}');
              }
            }
            
            return snapshot.docs
                .map((doc) {
                  try {
                    return PostModel.fromFirestore(doc);
                  } catch (e) {
                    debugPrint('⚠️ 게시물 변환 오류: $e, 문서: ${doc.id}');
                    // 오류 있는 문서는 무시하고 진행
                    return null;
                  }
                })
                .where((post) => post != null) // null이 아닌 것만 필터링
                .cast<PostModel>() // 타입 캐스팅
                .toList();
          });
    } catch (e) {
      debugPrint('⚠️ 피드 로드 오류: $e');
      // 오류 발생 시 빈 리스트 반환
      return Stream.value([]);
    }
  }
  
  // 특정 사용자의 게시물 가져오기
  Stream<List<PostModel>> getUserPosts(String userId) {
    try {
      debugPrint('사용자($userId) 게시물 로드 시도 중...');
      
      return _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            debugPrint('사용자 게시물 ${snapshot.docs.length}개 받음');
            return snapshot.docs
                .map((doc) => PostModel.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      debugPrint('⚠️ 사용자 게시물 로드 오류: $e');
      return Stream.value([]);
    }
  }
  
  // 게시물 생성 - 개선된 버전
  Future<String> createPost(
    String userId, 
    String? caption, 
    List<File>? imageFiles,
    String? location,
  ) async {
    try {
      debugPrint('게시물 생성 시작: 사용자 $userId');
      
      // 해시태그 추출
      List<String>? hashtags;
      if (caption != null && caption.contains('#')) {
        hashtags = _extractHashtags(caption);
        debugPrint('해시태그 발견: $hashtags');
      }
      
      // 이미지 파일이 있으면 업로드
      List<String>? imageUrls;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        debugPrint('이미지 ${imageFiles.length}개 업로드 중...');
        
        imageUrls = await Future.wait(
          imageFiles.map((file) => _uploadPostImage(userId, file))
        );
        
        debugPrint('이미지 URL: $imageUrls');
      }
      
      // 게시물 데이터 생성
      final postData = {
        'userId': userId,
        'caption': caption,
        'imageUrls': imageUrls,
        'location': location,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'hashtags': hashtags,
      };
      
      debugPrint('Firestore에 저장 중: $postData');
      
      // Firestore에 저장
      final docRef = await _firestore.collection('posts').add(postData);
      
      debugPrint('게시물 생성 완료: ID ${docRef.id}');
      
      // 사용자의 게시물 수 업데이트 시도
      try {
        await _firestore
            .collection('profiles')
            .doc(userId)
            .update({'postCount': FieldValue.increment(1)});
        debugPrint('프로필 postCount 업데이트 완료');
      } catch (e) {
        // profiles 컬렉션에 문서가 없을 수 있음
        debugPrint('프로필 업데이트 건너뜀: $e');
      }
          
      return docRef.id;
    } catch (e) {
      debugPrint('⚠️ 게시물 생성 오류: $e');
      rethrow;
    }
  }
  
  // 게시물 이미지 업로드
  Future<String> _uploadPostImage(String userId, File imageFile) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage
        .ref()
        .child('post_images')
        .child(userId)
        .child(fileName);
        
    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }
  
  // 텍스트에서 해시태그 추출
  List<String> _extractHashtags(String text) {
    final RegExp hashtagRegExp = RegExp(r'\B#[a-zA-Z0-9_]+\b');
    
    return hashtagRegExp
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
  }
  
  // 게시물 좋아요 토글
  Future<void> toggleLike(String postId, String userId) async {
    try {
      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId);
          
      final doc = await likeRef.get();
      
      if (doc.exists) {
        // 좋아요 취소
        await likeRef.delete();
        await _firestore
            .collection('posts')
            .doc(postId)
            .update({'likesCount': FieldValue.increment(-1)});
      } else {
        // 좋아요 추가
        await likeRef.set({'timestamp': FieldValue.serverTimestamp()});
        await _firestore
            .collection('posts')
            .doc(postId)
            .update({'likesCount': FieldValue.increment(1)});
      }
    } catch (e) {
      debugPrint('⚠️ 좋아요 토글 오류: $e');
      rethrow;
    }
  }
  
  // 좋아요 상태 확인
  Stream<bool> getLikeStatus(String postId, String userId) {
    try {
      return _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .snapshots()
          .map((doc) => doc.exists);
    } catch (e) {
      debugPrint('⚠️ 좋아요 상태 확인 오류: $e');
      return Stream.value(false);
    }
  }
  
  // 임시 게시물 생성 (테스트용)
  Future<void> createTestPosts(String userId) async {
    try {
      debugPrint('테스트 게시물 생성 시작: 사용자 $userId');
      
      // 테스트 게시물 5개 생성
      for (int i = 0; i < 5; i++) {
        final postData = {
          'userId': userId,
          'caption': '테스트 게시물 #${i + 1} #해시태그 #테스트',
          'imageUrls': null,
          'location': '테스트 위치',
          'createdAt': FieldValue.serverTimestamp(),
          'likesCount': 0,
          'commentsCount': 0,
          'hashtags': ['#해시태그', '#테스트'],
        };
        
        await _firestore.collection('posts').add(postData);
      }
      
      debugPrint('테스트 게시물 생성 완료');
    } catch (e) {
      debugPrint('⚠️ 테스트 게시물 생성 오류: $e');
      rethrow;
    }
  }
}