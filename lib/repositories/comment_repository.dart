import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/comment_model.dart';

class CommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 좋아요 상태 캐시
  final Map<String, BehaviorSubject<bool>> _likeStatusCache = {};
  
  // 게시물의 댓글 목록 가져오기 (스트림)
  Stream<List<CommentModel>> getCommentsForPost(String postId) {
    debugPrint('댓글 쿼리 시작: postId=$postId');
    
    // 댓글 스트림 생성
    final controller = StreamController<List<CommentModel>>();
    
    // 타임아웃 타이머
    Timer? timeoutTimer;
    
    try {
      // Firestore 쿼리 생성
      final query = _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: true);
      
      // 구독 객체
      StreamSubscription<QuerySnapshot>? subscription;
      
      // 타임아웃 타이머 설정 (5초)
      timeoutTimer = Timer(const Duration(seconds: 5), () {
        debugPrint('댓글 로드 타임아웃: $postId - 빈 목록 반환');
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
          
          debugPrint('댓글 수신 완료: ${snapshot.docs.length}개');
          
          // 댓글 객체로 변환
          final comments = snapshot.docs.map((doc) {
            try {
              return CommentModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('댓글 파싱 오류: $e, 문서 ID: ${doc.id}');
              return null;
            }
          })
          .where((comment) => comment != null)
          .cast<CommentModel>()
          .toList();
          
          // 결과 전달
          if (!controller.isClosed) {
            controller.add(comments);
          }
        },
        onError: (error) {
          // 오류 발생 시 빈 목록 전달 (스트림 종료 없음)
          debugPrint('댓글 로드 오류: $error');
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
      debugPrint('댓글 쿼리 초기화 오류: $e');
      controller.add([]);
      controller.close();
    }
    
    return controller.stream;
  }
  
  // 특정 댓글의 대댓글 가져오기 (스트림)
  Stream<List<CommentModel>> getRepliesForComment(String commentId) {
    debugPrint('대댓글 쿼리 시작: commentId=$commentId');
    
    // 대댓글 스트림 생성
    final controller = StreamController<List<CommentModel>>();
    
    // 타임아웃 타이머
    Timer? timeoutTimer;
    
    try {
      // Firestore 쿼리 생성
      final query = _firestore
          .collection('comments')
          .where('parentId', isEqualTo: commentId)
          .orderBy('createdAt', descending: false);
      
      // 구독 객체
      StreamSubscription<QuerySnapshot>? subscription;
      
      // 타임아웃 타이머 설정 (5초)
      timeoutTimer = Timer(const Duration(seconds: 5), () {
        debugPrint('대댓글 로드 타임아웃: $commentId - 빈 목록 반환');
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
          
          debugPrint('대댓글 수신 완료: ${snapshot.docs.length}개');
          
          // 댓글 객체로 변환
          final replies = snapshot.docs.map((doc) {
            try {
              return CommentModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('대댓글 파싱 오류: $e, 문서 ID: ${doc.id}');
              return null;
            }
          })
          .where((reply) => reply != null)
          .cast<CommentModel>()
          .toList();
          
          // 결과 전달
          if (!controller.isClosed) {
            controller.add(replies);
          }
        },
        onError: (error) {
          // 오류 발생 시 빈 목록 전달 (스트림 종료 없음)
          debugPrint('대댓글 로드 오류: $error');
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
      debugPrint('대댓글 쿼리 초기화 오류: $e');
      controller.add([]);
      controller.close();
    }
    
    return controller.stream;
  }
  
  // 댓글 좋아요 상태 가져오기 (초기값 포함한 스트림) - 캐싱 추가
  Stream<bool> getLikeStatusStream(String commentId, String userId) {
    final cacheKey = '$commentId:$userId';
    
    // 캐시 확인: 이미 존재하는 스트림이면 재활용
    if (_likeStatusCache.containsKey(cacheKey)) {
      debugPrint('캐시된 좋아요 상태 스트림 사용: $cacheKey');
      return _likeStatusCache[cacheKey]!.stream;
    }
    
    debugPrint('새 좋아요 상태 스트림 생성: commentId=$commentId, userId=$userId');
    
    // 문서 참조
    final docRef = _firestore
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId);
    
    // 새 BehaviorSubject 생성 (초기값은 일단 false로 설정)
    final subject = BehaviorSubject<bool>.seeded(false);
    _likeStatusCache[cacheKey] = subject;
    
    // 초기 상태 확인 (일회성 쿼리)
    docRef.get().then((doc) {
      final exists = doc.exists;
      subject.add(exists);
    }).catchError((e) {
      debugPrint('좋아요 초기 상태 확인 오류: $e');
      // 오류 시 기본값 유지
    });
    
    // 실시간 업데이트 구독
    final subscription = docRef.snapshots().listen(
      (doc) {
        // 상태가 변경된 경우만 업데이트 (중복 방지)
        if (subject.value != doc.exists) {
          subject.add(doc.exists);
        }
      },
      onError: (e) {
        debugPrint('좋아요 상태 스트림 오류: $e');
        // 오류 시 기본값 설정
        if (!subject.isClosed) {
          subject.add(false);
        }
      },
    );
    
    // 구독 정리 핸들러 설정
    subject.onCancel = () {
      subscription.cancel();
      _likeStatusCache.remove(cacheKey);
      debugPrint('좋아요 상태 스트림 해제: $cacheKey');
    };
    
    return subject.stream;
  }
  
  // 댓글 좋아요 상태 확인 (일회성)
  Future<bool> getLikeStatusOnce(String commentId, String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(userId)
          .get(const GetOptions(source: Source.serverAndCache));
      
      return docSnapshot.exists;
    } catch (e) {
      debugPrint('댓글 좋아요 상태 확인 오류: $e');
      return false;
    }
  }
  
  // 댓글 추가
  Future<String> addComment({
    required String postId,
    required String userId,
    required String text,
    String? parentId,
  }) async {
    debugPrint('댓글 추가 시작 - postId: $postId, userId: $userId, text: $text, parentId: $parentId');
    
    try {
      // 1. 댓글 문서 생성
      final commentRef = _firestore.collection('comments').doc();
      final commentId = commentRef.id;
      
      final now = DateTime.now();
      
      // 댓글 데이터
      final commentData = {
        'id': commentId,
        'postId': postId,
        'userId': userId,
        'text': text,
        'parentId': parentId,
        'createdAt': Timestamp.fromDate(now),
        'likesCount': 0,
      };
      
      // 댓글 문서 생성
      await commentRef.set(commentData);
      debugPrint('댓글 문서 생성 완료: $commentId');
      
      // 2. 게시물 댓글 수 업데이트 (부모 댓글인 경우만)
      if (parentId == null) {
        await _updatePostCommentCount(postId, 1);
      }
      
      debugPrint('댓글 추가 완료');
      return commentId;
    } catch (e) {
      debugPrint('댓글 추가 실패: $e');
      rethrow;
    }
  }
  
  // 댓글 수정
  Future<void> updateComment({
    required String commentId,
    required String text,
  }) async {
    debugPrint('댓글 수정 시작 - commentId: $commentId');
    
    try {
      await _firestore.collection('comments').doc(commentId).update({
        'text': text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('댓글 수정 성공');
    } catch (e) {
      debugPrint('댓글 수정 실패: $e');
      rethrow;
    }
  }
  
  // 댓글 삭제
  Future<void> deleteComment({
    required String commentId,
    required String postId,
    String? parentId,
  }) async {
    debugPrint('댓글 삭제 시작 - commentId: $commentId, postId: $postId');
    
    try {
      // 1. 대댓글 확인
      final repliesQuery = await _firestore
          .collection('comments')
          .where('parentId', isEqualTo: commentId)
          .get();
      
      final int repliesCount = repliesQuery.docs.length;
      debugPrint('삭제할 댓글의 대댓글 수: $repliesCount개');
      
      // 2. 대댓글 삭제
      final batch = _firestore.batch();
      for (final replyDoc in repliesQuery.docs) {
        batch.delete(replyDoc.reference);
      }
      
      // 3. 댓글 문서 삭제
      batch.delete(_firestore.collection('comments').doc(commentId));
      
      // 배치 실행
      await batch.commit();
      debugPrint('댓글 및 대댓글 삭제 완료');
      
      // 4. 게시물 댓글 카운트 업데이트
      if (parentId == null) {
        // 댓글과 대댓글 수를 모두 고려하여 감소
        await _updatePostCommentCount(postId, -(1 + repliesCount));
      }
      
      debugPrint('댓글 삭제 완료');
    } catch (e) {
      debugPrint('댓글 삭제 실패: $e');
      rethrow;
    }
  }
  
  // 게시물 댓글 수 업데이트 헬퍼 메서드
  Future<void> _updatePostCommentCount(String postId, int increment) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();
      
      if (postDoc.exists) {
        final int currentCount = postDoc.data()?['commentsCount'] ?? 0;
        final int newCount = (currentCount + increment) < 0 ? 0 : currentCount + increment;
        
        await postRef.update({'commentsCount': newCount});
        debugPrint('게시물 댓글 수 업데이트: $newCount');
      } else {
        debugPrint('게시물이 존재하지 않음: $postId');
      }
    } catch (e) {
      debugPrint('게시물 댓글 수 업데이트 실패: $e');
      // 실패해도 주요 기능에 영향을 주지 않도록 오류를 전파하지 않음
    }
  }
  
  // 좋아요 토글 최적화 - 트랜잭션 사용
  Future<bool> toggleLike({
    required String commentId,
    required String userId,
  }) async {
    debugPrint('좋아요 토글 시작: commentId=$commentId, userId=$userId');
    
    try {
      final likeRef = _firestore
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(userId);
      
      final commentRef = _firestore.collection('comments').doc(commentId);
      
      // 현재 상태 확인
      bool newLikeStatus = false;
      
      // 트랜잭션으로 처리하여 동시성 문제 방지
      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(likeRef);
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          debugPrint('댓글이 존재하지 않음: $commentId');
          throw Exception('댓글이 존재하지 않습니다');
        }
        
        final int currentLikesCount = commentDoc.data()?['likesCount'] ?? 0;
        
        if (likeDoc.exists) {
          // 좋아요 취소
          transaction.delete(likeRef);
          
          if (currentLikesCount > 0) {
            transaction.update(commentRef, {'likesCount': currentLikesCount - 1});
          }
          
          newLikeStatus = false;
          debugPrint('좋아요 취소 처리됨: 현재 카운트=${currentLikesCount - 1}');
        } else {
          // 좋아요 추가
          transaction.set(likeRef, {
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          transaction.update(commentRef, {'likesCount': currentLikesCount + 1});
          
          newLikeStatus = true;
          debugPrint('좋아요 추가 처리됨: 현재 카운트=${currentLikesCount + 1}');
        }
      });
      
      // 캐시된 스트림이 있다면 새 상태로 업데이트
      final cacheKey = '$commentId:$userId';
      if (_likeStatusCache.containsKey(cacheKey) && !_likeStatusCache[cacheKey]!.isClosed) {
        _likeStatusCache[cacheKey]!.add(newLikeStatus);
      }
      
      debugPrint('좋아요 토글 완료: 최종상태=$newLikeStatus');
      return newLikeStatus;
    } catch (e) {
      debugPrint('좋아요 토글 실패: $e');
      rethrow;
    }
  }
  
  // 리소스 정리 (앱 종료 시 호출)
  void dispose() {
    // 열려있는 모든 BehaviorSubject 닫기
    for (final subject in _likeStatusCache.values) {
      if (!subject.isClosed) {
        subject.close();
      }
    }
    _likeStatusCache.clear();
    debugPrint('CommentRepository 리소스 정리 완료');
  }
}