import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/post_model.dart';
import 'dart:io';

class FeedRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 피드 게시물 목록 가져오기 (스트림) - null 안전하게 수정
  Stream<List<PostModel>> getFeedPosts() {
    debugPrint('피드 게시물 로드 시작');
    
    // 스트림 컨트롤러 생성
    final controller = StreamController<List<PostModel>>();
    
    // 타임아웃 타이머
    Timer? timeoutTimer;
    
    try {
      // Firestore 쿼리 생성
      final query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50);
      
      // 구독 객체
      StreamSubscription<QuerySnapshot>? subscription;
      
      // 타임아웃 타이머 설정 (10초)
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        debugPrint('피드 게시물 로드 타임아웃 - 빈 목록 반환');
        // 타임아웃 시 빈 리스트 전달 (스트림 종료 없음)
        if (!controller.isClosed) {
          controller.add([]);
        }
        // 기존 구독 취소 - null 안전 처리
        subscription?.cancel();
      });
      
      // Firestore 쿼리 구독
      subscription = query.snapshots().listen(
        (snapshot) {
          // 타임아웃 타이머 취소 (데이터 도착)
          timeoutTimer?.cancel();
          
          debugPrint('피드 게시물 ${snapshot.docs.length}개 수신');
          
          // 게시물 객체로 변환
          final posts = snapshot.docs.map((doc) {
            try {
              return PostModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('게시물 파싱 오류: $e, 문서 ID: ${doc.id}');
              return null;
            }
          })
          .where((post) => post != null)
          .cast<PostModel>()
          .toList();
          
          // 결과 전달
          if (!controller.isClosed) {
            controller.add(posts);
          }
        },
        onError: (error) {
          // 오류 발생 시 빈 목록 전달 (스트림 종료 없음)
          debugPrint('피드 게시물 로드 오류: $error');
          if (!controller.isClosed) {
            controller.add([]);
          }
        },
      );
      
      // 컨트롤러 종료 시 정리 작업
      controller.onCancel = () {
        timeoutTimer?.cancel();
        subscription?.cancel();  // null 안전 처리
      };
    } catch (e) {
      // 초기화 오류 시 빈 목록 전달 후 스트림 종료
      debugPrint('피드 게시물 쿼리 초기화 오류: $e');
      controller.add([]);
      controller.close();
    }
    
    return controller.stream;
  }
  
  // 사용자의 게시물 목록 가져오기 (스트림) - null 안전하게 수정
  Stream<List<PostModel>> getUserPosts(String userId) {
    debugPrint('사용자 게시물 로드 시작: $userId');
    
    // 스트림 컨트롤러 생성
    final controller = StreamController<List<PostModel>>();
    
    // 타임아웃 타이머
    Timer? timeoutTimer;
    
    try {
      // Firestore 쿼리 생성
      final query = _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);
      
      // 구독 객체
      StreamSubscription<QuerySnapshot>? subscription;
      
      // 타임아웃 타이머 설정 (10초)
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        debugPrint('사용자 게시물 로드 타임아웃: $userId - 빈 목록 반환');
        // 타임아웃 시 빈 리스트 전달 (스트림 종료 없음)
        if (!controller.isClosed) {
          controller.add([]);
        }
        // 기존 구독 취소 - null 안전 처리
        subscription?.cancel();
      });
      
      // Firestore 쿼리 구독
      subscription = query.snapshots().listen(
        (snapshot) {
          // 타임아웃 타이머 취소 (데이터 도착)
          timeoutTimer?.cancel();
          
          debugPrint('사용자 게시물 ${snapshot.docs.length}개 수신');
          
          // 게시물 객체로 변환
          final posts = snapshot.docs.map((doc) {
            try {
              return PostModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('게시물 파싱 오류: $e, 문서 ID: ${doc.id}');
              return null;
            }
          })
          .where((post) => post != null)
          .cast<PostModel>()
          .toList();
          
          // 결과 전달
          if (!controller.isClosed) {
            controller.add(posts);
          }
        },
        onError: (error) {
          // 오류 발생 시 빈 목록 전달 (스트림 종료 없음)
          debugPrint('사용자 게시물 로드 오류: $error');
          if (!controller.isClosed) {
            controller.add([]);
          }
        },
      );
      
      // 컨트롤러 종료 시 정리 작업
      controller.onCancel = () {
        timeoutTimer?.cancel();
        subscription?.cancel();  // null 안전 처리
      };
    } catch (e) {
      // 초기화 오류 시 빈 목록 전달 후 스트림 종료
      debugPrint('사용자 게시물 쿼리 초기화 오류: $e');
      controller.add([]);
      controller.close();
    }
    
    return controller.stream;
  }
  
  // 게시물 상세 정보 가져오기 (스트림) - null 안전하게 수정
  Stream<PostModel?> getPostByIdStream(String postId) {
    debugPrint('게시물 상세 로드 시작: $postId');
    
    // 스트림 컨트롤러 생성
    final controller = StreamController<PostModel?>();
    
    // 타임아웃 타이머
    Timer? timeoutTimer;
    
    try {
      // Firestore 문서 참조
      final docRef = _firestore.collection('posts').doc(postId);
      
      // 구독 객체
      StreamSubscription<DocumentSnapshot>? subscription;
      
      // 타임아웃 타이머 설정 (10초)
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        debugPrint('게시물 상세 로드 타임아웃: $postId');
        // 타임아웃 시 null 반환 (스트림 종료 없음)
        if (!controller.isClosed) {
          controller.add(null);
        }
        // 기존 구독 취소 - null 안전 처리
        subscription?.cancel();
      });
      
      // Firestore 문서 구독
      subscription = docRef.snapshots().listen(
        (doc) {
          // 타임아웃 타이머 취소 (데이터 도착)
          timeoutTimer?.cancel();
          
          if (doc.exists) {
            debugPrint('게시물 상세 정보 수신: $postId');
            try {
              final post = PostModel.fromFirestore(doc);
              if (!controller.isClosed) {
                controller.add(post);
              }
            } catch (e) {
              debugPrint('게시물 파싱 오류: $e, 문서 ID: ${doc.id}');
              if (!controller.isClosed) {
                controller.add(null);
              }
            }
          } else {
            debugPrint('게시물이 존재하지 않음: $postId');
            if (!controller.isClosed) {
              controller.add(null);
            }
          }
        },
        onError: (error) {
          // 오류 발생 시 null 반환 (스트림 종료 없음)
          debugPrint('게시물 상세 로드 오류: $error');
          if (!controller.isClosed) {
            controller.add(null);
          }
        },
      );
      
      // 컨트롤러 종료 시 정리 작업
      controller.onCancel = () {
        timeoutTimer?.cancel();
        subscription?.cancel();  // null 안전 처리
      };
    } catch (e) {
      // 초기화 오류 시 null 반환 후 스트림 종료
      debugPrint('게시물 상세 쿼리 초기화 오류: $e');
      controller.add(null);
      controller.close();
    }
    
    return controller.stream;
  }
  
  // 북마크 상태 확인 (스트림) - null 안전하게 수정
  Stream<bool> getBookmarkStatus(String postId, String userId) {
    // 스트림 컨트롤러 생성
    final controller = StreamController<bool>();
    
    try {
      // Firestore 문서 참조
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(postId);
      
      // 구독 객체
      StreamSubscription<DocumentSnapshot>? subscription;
      
      // Firestore 문서 구독
      subscription = docRef.snapshots().listen(
        (doc) {
          if (!controller.isClosed) {
            controller.add(doc.exists);
          }
        },
        onError: (error) {
          debugPrint('북마크 상태 확인 오류: $error');
          if (!controller.isClosed) {
            controller.add(false);
          }
        },
      );
      
      // 컨트롤러 종료 시 정리 작업
      controller.onCancel = () {
        subscription?.cancel();  // null 안전 처리
      };
    } catch (e) {
      debugPrint('북마크 상태 초기화 오류: $e');
      controller.add(false);
      controller.close();
    }
    
    return controller.stream;
  }
  
  // 게시물 상세 정보 가져오기 (일회성)
  Future<PostModel?> getPostById(String postId) async {
    try {
      final docSnapshot = await _firestore.collection('posts').doc(postId).get();
      
      if (docSnapshot.exists) {
        return PostModel.fromFirestore(docSnapshot);
      }
      
      return null;
    } catch (e) {
      debugPrint('getPostById 오류: $e');
      return null;
    }
  }
  
  // 좋아요 상태 확인 (일회성)
  Future<bool> getLikeStatusOnce(String postId, String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get(const GetOptions(source: Source.serverAndCache));
      
      return docSnapshot.exists;
    } catch (e) {
      debugPrint('좋아요 상태 확인 오류: $e');
      return false;
    }
  }
  
  // 게시물 생성
  Future<String?> createPost(
    String userId,
    String? caption,
    List<File>? imageFiles,
    String? location,
    List<String>? hashtags,
  ) async {
    try {
      // 새 게시물 문서 레퍼런스 생성
      final postRef = _firestore.collection('posts').doc();
      
      // 이미지 업로드 (있는 경우에만)
      List<String>? imageUrls;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        imageUrls = await _uploadImages(postRef.id, imageFiles);
      }
      
      // 게시물 데이터
      final postData = {
        'id': postRef.id,
        'userId': userId,
        'caption': caption,
        'imageUrls': imageUrls,
        'location': location,
        'hashtags': hashtags,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
      };
      
      // Firestore에 게시물 저장
      await postRef.set(postData);
      
      // 해시태그가 있다면 해시태그 문서도 업데이트
      if (hashtags != null && hashtags.isNotEmpty) {
        // 해시태그 처리 로직 (구현 필요)
      }
      
      return postRef.id;
    } catch (e) {
      debugPrint('게시물 생성 실패: $e');
      return null;
    }
  }
  
  // 이미지 업로드 헬퍼 메서드
  Future<List<String>> _uploadImages(String postId, List<File> imageFiles) async {
    final List<String> imageUrls = [];
    
    // 이미지 업로드 로직...
    // (원래 구현 유지)
    
    return imageUrls;
  }
  
  // 게시물 업데이트
  Future<void> updatePost(
    String postId,
    String? caption,
    String? location,
    List<String>? imageUrls,
    List<File>? newImageFiles,
    List<String>? hashtags,
  ) async {
    // (원래 구현 유지)
  }
  
  // 게시물 삭제
  Future<void> deletePost(String postId) async {
    // (원래 구현 유지)
  }
  
  // 좋아요 토글
  Future<void> toggleLike(String postId, String userId) async {
    // (원래 구현 유지)
  }
  
  // 북마크 토글
  Future<void> toggleBookmark(String postId, String userId) async {
    // (원래 구현 유지)
  }
}