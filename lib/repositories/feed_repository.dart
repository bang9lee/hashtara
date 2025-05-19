import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/post_model.dart';

class FeedRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // 좋아요 상태 캐시
  final Map<String, StreamController<bool>> _likeStatusCache = {};
  
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
  
  // 좋아요 상태 확인 (스트림으로 변경) - 실시간 업데이트 지원
  Stream<bool> getLikeStatus(String postId, String userId) {
    debugPrint('좋아요 상태 스트림 시작 - postId: $postId, userId: $userId');
    
    // 캐시 키 생성
    final cacheKey = '$postId:$userId';
    
    // 캐시 확인: 이미 존재하는 스트림이면 재활용
    if (_likeStatusCache.containsKey(cacheKey) && !_likeStatusCache[cacheKey]!.isClosed) {
      debugPrint('캐시된 좋아요 상태 스트림 사용: $cacheKey');
      return _likeStatusCache[cacheKey]!.stream;
    }
    
    // 브로드캐스트 스트림 컨트롤러 생성 (여러 리스너 지원)
    final controller = StreamController<bool>.broadcast();
    _likeStatusCache[cacheKey] = controller;
    
    try {
      // Firestore 문서 참조 - 좋아요 컬렉션에서 조회
      final docRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId);
      
      // 초기 상태 확인 (일회성 쿼리)
      docRef.get().then((doc) {
        final exists = doc.exists;
        if (!controller.isClosed) {
          controller.add(exists);
          debugPrint('좋아요 초기 상태: $exists - postId: $postId, userId: $userId');
        }
      }).catchError((e) {
        debugPrint('좋아요 초기 상태 확인 오류: $e');
        // 오류 시 기본값 설정
        if (!controller.isClosed) {
          controller.add(false);
        }
      });
      
      // 실시간 업데이트 구독
      final subscription = docRef.snapshots().listen(
        (doc) {
          if (!controller.isClosed) {
            controller.add(doc.exists);
            debugPrint('좋아요 상태 변경 - postId: $postId, liked: ${doc.exists}');
          }
        },
        onError: (error) {
          debugPrint('좋아요 상태 확인 오류: $error');
          if (!controller.isClosed) {
            controller.add(false);
          }
        },
      );
      
      // 컨트롤러 종료 시 정리 작업
      controller.onCancel = () {
        subscription.cancel();
        _likeStatusCache.remove(cacheKey);
        debugPrint('좋아요 상태 스트림 해제: $cacheKey');
      };
    } catch (e) {
      debugPrint('좋아요 상태 초기화 오류: $e');
      controller.add(false);
      controller.close();
      _likeStatusCache.remove(cacheKey);
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
  
  // 좋아요 상태 확인 (일회성) - 이전 메서드 유지
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
  
  // 게시물 생성 - 이미지 처리 문제 수정
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
        // 이미지 업로드 전에 로그 추가
        debugPrint('이미지 업로드 시작: ${imageFiles.length}개 파일');
        for (int i = 0; i < imageFiles.length; i++) {
          final fileSize = await imageFiles[i].length();
          debugPrint('이미지 #$i: ${fileSize ~/ 1024}KB, 경로: ${imageFiles[i].path}');
        }
        
        try {
          // 이미지 업로드 메서드 호출
          imageUrls = await _uploadImages(postRef.id, imageFiles);
          
          // 이미지 업로드 결과 확인
          if (imageUrls.isEmpty) {
            debugPrint('경고: 이미지 URL이 비어있음. 업로드 실패했을 수 있음.');
          } else {
            debugPrint('이미지 업로드 완료: ${imageUrls.length}개 URL');
            for (int i = 0; i < imageUrls.length; i++) {
              debugPrint('이미지 URL #$i: ${imageUrls[i]}');
            }
          }
        } catch (e) {
          // 이미지 업로드 실패 시 로그만 남기고 계속 진행
          debugPrint('이미지 업로드 중 오류 발생: $e');
          // 이미지 업로드에 실패해도 게시물은 계속 생성
          imageUrls = null;
        }
      }
      
      // 게시물 데이터 준비 - 서버 타임스탬프 사용
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
      
      // 게시물 데이터 로깅
      debugPrint('게시물 데이터 준비: id=${postRef.id}, userId=$userId');
      debugPrint('게시물 내용: caption=${caption?.length ?? 0}자, 이미지=${imageUrls?.length ?? 0}개');
      
      // Firestore에 게시물 저장
      await postRef.set(postData);
      debugPrint('게시물 생성 성공: ${postRef.id}');
      
      // 해시태그가 있다면 해시태그 문서도 업데이트
      if (hashtags != null && hashtags.isNotEmpty) {
        debugPrint('해시태그 업데이트: ${hashtags.join(", ")}');
        for (final tag in hashtags) {
          try {
            await _updateHashtagCount(tag);
          } catch (e) {
            // 해시태그 업데이트 실패 시 로그만 남기고 계속 진행
            debugPrint('해시태그 업데이트 오류 (무시됨): $e');
          }
        }
      }
      
      return postRef.id;
    } catch (e) {
      debugPrint('게시물 생성 실패: $e');
      rethrow; // 오류 전파
    }
  }
  
  // 해시태그 카운트 업데이트
  Future<void> _updateHashtagCount(String tag) async {
    // # 기호 제거
    final cleanTag = tag.startsWith('#') ? tag.substring(1) : tag;
    
    // 해시태그 문서 참조
    final hashtagRef = _firestore.collection('hashtags').doc(cleanTag);
    
    try {
      // 트랜잭션으로 안전하게 업데이트
      await _firestore.runTransaction((transaction) async {
        final hashtagDoc = await transaction.get(hashtagRef);
        
        if (hashtagDoc.exists) {
          // 기존 해시태그 카운트 증가
          final int currentCount = hashtagDoc.data()?['postsCount'] ?? 0;
          transaction.update(hashtagRef, {'postsCount': currentCount + 1});
        } else {
          // 새 해시태그 문서 생성
          transaction.set(hashtagRef, {
            'name': cleanTag,
            'postsCount': 1,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('해시태그 카운트 업데이트 실패: $e');
      // 해시태그 업데이트 실패는 무시하고 진행
    }
  }
  
  // 이미지 업로드 메서드 개선
  Future<List<String>> _uploadImages(String postId, List<File> imageFiles) async {
    final List<String> imageUrls = [];
    
    try {
      // 각 이미지마다 별도 처리
      for (int i = 0; i < imageFiles.length; i++) {
        try {
          final file = imageFiles[i];
          final fileSize = await file.length();
          
          // 파일 크기 로깅 및 검증
          debugPrint('이미지 #$i 업로드 시작: ${fileSize ~/ 1024}KB');
          
          // 안전하게 파일 이름 생성 (공백, 특수문자 제거)
          final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final path = 'posts/$postId/$fileName';
          
          // 스토리지 참조 생성
          final ref = _storage.ref().child(path);
          
          // 메타데이터 설정
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'postId': postId,
              'index': i.toString(),
              'originalName': file.path.split('/').last,
            },
          );
          
          // 이미지 업로드 (타임아웃 설정)
          final uploadTask = ref.putFile(file, metadata);
          
          // 업로드 상태 모니터링
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            debugPrint('이미지 #$i 업로드 진행률: ${(progress * 100).toStringAsFixed(1)}%');
          }, onError: (e) {
            debugPrint('이미지 #$i 업로드 모니터링 오류: $e');
          });
          
          // 업로드 완료 대기 (타임아웃 30초)
          final snapshot = await uploadTask.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('이미지 #$i 업로드 타임아웃');
              throw TimeoutException('이미지 업로드 시간이 초과되었습니다');
            },
          );
          
          // 업로드 완료 후 URL 가져오기
          final url = await snapshot.ref.getDownloadURL();
          imageUrls.add(url);
          
          debugPrint('이미지 #$i 업로드 완료: $url');
        } catch (e) {
          // 개별 이미지 업로드 실패 시 로그만 남기고 다음 이미지로 진행
          debugPrint('이미지 #$i 업로드 실패: $e');
        }
      }
      
      debugPrint('총 ${imageUrls.length}/${imageFiles.length}개 이미지 업로드 완료');
      return imageUrls;
    } catch (e) {
      debugPrint('이미지 업로드 전체 실패: $e');
      // 전체 이미지 업로드에 실패해도 가능한 URL 반환
      return imageUrls;
    }
  }
  
  // 게시물 업데이트
  Future<void> updatePost({
    required String postId,
    String? caption,
    String? location,
    List<String>? imageUrls,
    List<File>? newImageFiles,
    List<String>? hashtags,
  }) async {
    try {
      // 1. 새 이미지가 있으면 업로드
      List<String> updatedImageUrls = imageUrls ?? [];
      
      if (newImageFiles != null && newImageFiles.isNotEmpty) {
        final newUrls = await _uploadImages(postId, newImageFiles);
        updatedImageUrls.addAll(newUrls);
      }
      
      // 2. 게시물 데이터 업데이트
      final postData = <String, dynamic>{
        'caption': caption,
        'location': location,
        'hashtags': hashtags,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // 이미지 URL 리스트가 변경된 경우에만 업데이트
      if (updatedImageUrls.isNotEmpty) {
        postData['imageUrls'] = updatedImageUrls;
      }
      
      // 게시물 업데이트
      await _firestore.collection('posts').doc(postId).update(postData);
      
      debugPrint('게시물 업데이트 성공: $postId');
    } catch (e) {
      debugPrint('게시물 업데이트 실패: $e');
      rethrow;
    }
  }
  
  // 게시물 삭제 - 완전히 구현
  Future<void> deletePost(String postId) async {
    debugPrint('게시물 삭제 시작: $postId');
    
    try {
      // 배치 처리를 위한 객체 생성
      final batch = _firestore.batch();
      final postRef = _firestore.collection('posts').doc(postId);
      
      // 1. 게시물 좋아요 컬렉션 삭제 
      final likesSnapshot = await postRef.collection('likes').get();
      for (final likeDoc in likesSnapshot.docs) {
        batch.delete(likeDoc.reference);
      }
      debugPrint('좋아요 컬렉션 삭제 준비 완료 (${likesSnapshot.docs.length}개)');
      
      // 2. 댓글 및 댓글 좋아요 삭제
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();
      
      debugPrint('연관 댓글 ${commentsSnapshot.docs.length}개 발견');
      
      // 각 댓글의 좋아요 컬렉션 삭제
      for (final commentDoc in commentsSnapshot.docs) {
        final commentId = commentDoc.id;
        
        // 2.1 댓글 좋아요 컬렉션 조회 및 삭제
        final commentLikesSnapshot = await _firestore
            .collection('comments')
            .doc(commentId)
            .collection('likes')
            .get();
        
        for (final likeDoc in commentLikesSnapshot.docs) {
          batch.delete(likeDoc.reference);
        }
        
        // 2.2 댓글 문서 삭제
        batch.delete(commentDoc.reference);
      }
      
      // 3. Storage의 이미지 파일 삭제 시도 (비동기적으로 처리)
      _deletePostImages(postId).then((_) {
        debugPrint('게시물 이미지 삭제 완료: $postId');
      }).catchError((e) {
        debugPrint('게시물 이미지 삭제 실패 (무시됨): $e');
      });
      
      // 4. 마지막으로 게시물 문서 삭제
      batch.delete(postRef);
      
      // 배치 실행
      await batch.commit();
      
      debugPrint('게시물 삭제 완료: $postId');
    } catch (e) {
      debugPrint('게시물 삭제 실패: $e');
      rethrow;
    }
  }
  
  // Storage의 게시물 이미지 삭제
  Future<void> _deletePostImages(String postId) async {
    try {
      final folderRef = _storage.ref().child('posts/$postId');
      
      try {
        // 폴더 내 모든 파일 목록 조회
        final listResult = await folderRef.listAll();
        
        // 각 파일 삭제
        for (final item in listResult.items) {
          await item.delete();
        }
        
        debugPrint('게시물 이미지 삭제 성공: $postId');
      } catch (e) {
        debugPrint('이미지 목록 조회 실패: $e');
      }
    } catch (e) {
      debugPrint('이미지 삭제 실패: $e');
      // 스토리지 삭제 실패는 무시하고 진행
    }
  }
  
  // 좋아요 토글 - Firebase 트랜잭션으로 수정
  Future<void> toggleLike(String postId, String userId) async {
    try {
      debugPrint('좋아요 토글 시작 - postId: $postId, userId: $userId');
      
      // 캐시 키 생성
      final cacheKey = '$postId:$userId';
      
      // 트랜잭션 사용
      await _firestore.runTransaction((transaction) async {
        // 1. 좋아요 문서 참조 가져오기
        final likeDocRef = _firestore
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(userId);
        
        // 2. 현재 좋아요 상태 확인
        final likeDoc = await transaction.get(likeDocRef);
        final isLiked = likeDoc.exists;
        
        // 3. 게시물 참조 가져오기
        final postRef = _firestore.collection('posts').doc(postId);
        final postDoc = await transaction.get(postRef);
        
        if (!postDoc.exists) {
          throw Exception('게시물이 존재하지 않습니다');
        }
        
        // 4. 좋아요 토글 및 카운터 업데이트
        if (isLiked) {
          // 좋아요 취소
          transaction.delete(likeDocRef);
          
          // 현재 카운트 확인 후 조정 (음수 방지)
          final currentCount = postDoc.data()?['likesCount'] ?? 0;
          final newCount = currentCount > 0 ? currentCount - 1 : 0;
          transaction.update(postRef, {'likesCount': newCount});
          
          debugPrint('좋아요 취소 처리: 새 카운트=$newCount');
          
          // 캐시된 스트림이 있으면 즉시 업데이트
          if (_likeStatusCache.containsKey(cacheKey) && !_likeStatusCache[cacheKey]!.isClosed) {
            _likeStatusCache[cacheKey]!.add(false);
          }
        } else {
          // 좋아요 추가
          transaction.set(likeDocRef, {
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp()
          });
          
          // 현재 카운트에 1 추가
          final currentCount = postDoc.data()?['likesCount'] ?? 0;
          transaction.update(postRef, {'likesCount': currentCount + 1});
          
          debugPrint('좋아요 추가 처리: 새 카운트=${currentCount + 1}');
          
          // 캐시된 스트림이 있으면 즉시 업데이트
          if (_likeStatusCache.containsKey(cacheKey) && !_likeStatusCache[cacheKey]!.isClosed) {
            _likeStatusCache[cacheKey]!.add(true);
          }
        }
      });
      
      debugPrint('좋아요 토글 완료');
    } catch (e) {
      debugPrint('좋아요 토글 실패: $e');
      rethrow; // 에러 전파하여 상위에서 처리
    }
  }
  
  // 북마크 토글
  Future<void> toggleBookmark(String postId, String userId) async {
    try {
      // 북마크 문서 참조
      final bookmarkRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(postId);
      
      // 현재 상태 확인
      final bookmarkDoc = await bookmarkRef.get();
      
      if (bookmarkDoc.exists) {
        // 북마크 해제
        await bookmarkRef.delete();
        debugPrint('북마크 해제 완료');
      } else {
        // 북마크 추가
        await bookmarkRef.set({
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('북마크 추가 완료');
      }
    } catch (e) {
      debugPrint('북마크 토글 실패: $e');
      rethrow;
    }
  }
  
  // 리소스 정리
  void dispose() {
    // 열려있는 모든 StreamController 닫기
    for (final controller in _likeStatusCache.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _likeStatusCache.clear();
    debugPrint('FeedRepository 리소스 정리 완료');
  }
}