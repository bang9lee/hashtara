import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../models/comment_model.dart';

class CommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 게시물의 댓글 목록 가져오기 (스트림) - 답글이 아닌 1차 댓글만 가져옴
  Stream<List<CommentModel>> getCommentsForPost(String postId) {
    debugPrint('댓글 쿼리 시작: postId=$postId');
    
    // 댓글 스트림 생성 (broadcast로 변경)
    final controller = StreamController<List<CommentModel>>.broadcast();
    
    // 타임아웃 타이머
    Timer? timeoutTimer;
    
    try {
      // Firestore 쿼리 생성 - 중요: 오름차순으로 변경 (오래된 댓글이 위에 표시됨)
      // replyToCommentId가 null인 것만 필터링 (답글이 아닌 1차 댓글만)
      final query = _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .where('replyToCommentId', isNull: true)
          .orderBy('createdAt');
      
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
  
  // 특정 댓글에 대한 답글 가져오기
  Stream<List<CommentModel>> getRepliesForComment(String commentId) {
    debugPrint('답글 쿼리 시작: commentId=$commentId');
    
    // 답글 스트림 생성 (broadcast로 변경)
    final controller = StreamController<List<CommentModel>>.broadcast();
    
    // 타임아웃 타이머
    Timer? timeoutTimer;
    
    try {
      // Firestore 쿼리 생성 - replyToCommentId가 commentId인 댓글만 가져옴
      final query = _firestore
          .collection('comments')
          .where('replyToCommentId', isEqualTo: commentId)
          .orderBy('createdAt');
      
      // 구독 객체
      StreamSubscription<QuerySnapshot>? subscription;
      
      // 타임아웃 타이머 설정 (5초)
      timeoutTimer = Timer(const Duration(seconds: 5), () {
        debugPrint('답글 로드 타임아웃: $commentId - 빈 목록 반환');
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
          
          debugPrint('답글 수신 완료: ${snapshot.docs.length}개');
          
          // 답글 객체로 변환
          final replies = snapshot.docs.map((doc) {
            try {
              return CommentModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('답글 파싱 오류: $e, 문서 ID: ${doc.id}');
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
          debugPrint('답글 로드 오류: $error');
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
      debugPrint('답글 쿼리 초기화 오류: $e');
      controller.add([]);
      controller.close();
    }
    
    return controller.stream;
  }
  
  // 댓글 추가
  Future<String> addComment({
    required String postId,
    required String userId,
    required String text,
    String? replyToCommentId,
  }) async {
    debugPrint('댓글 추가 시작 - postId: $postId, userId: $userId, text: $text, replyToCommentId: $replyToCommentId');
    
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
        'createdAt': Timestamp.fromDate(now),
        'replyToCommentId': replyToCommentId,
      };
      
      // 댓글 문서 생성
      await commentRef.set(commentData);
      debugPrint('댓글 문서 생성 완료: $commentId');
      
      // 2. 게시물 댓글 수 업데이트 (replyToCommentId가 null인 경우만)
      if (replyToCommentId == null) {
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
    bool isReply = false, // 답글인지 여부
  }) async {
    debugPrint('댓글 삭제 시작 - commentId: $commentId, postId: $postId, isReply: $isReply');
    
    try {
      // 1. 댓글이 답글이 아닌 경우, 해당 댓글에 달린 답글들도 함께 삭제
      if (!isReply) {
        final repliesQuery = await _firestore
            .collection('comments')
            .where('replyToCommentId', isEqualTo: commentId)
            .get();
        
        final int repliesCount = repliesQuery.docs.length;
        debugPrint('삭제할 댓글의 답글 수: $repliesCount개');
        
        // 답글 삭제
        final batch = _firestore.batch();
        for (final replyDoc in repliesQuery.docs) {
          batch.delete(replyDoc.reference);
        }
        
        // 댓글 문서 삭제
        batch.delete(_firestore.collection('comments').doc(commentId));
        
        // 배치 실행
        await batch.commit();
        debugPrint('댓글 및 답글 삭제 완료');
        
        // 게시물 댓글 카운트 업데이트 (1차 댓글만 카운트에 반영)
        await _updatePostCommentCount(postId, -1);
      } else {
        // 2. 답글인 경우, 해당 답글만 삭제
        await _firestore.collection('comments').doc(commentId).delete();
        debugPrint('답글 삭제 완료');
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
  
  // 리소스 정리 (앱 종료 시 호출)
  void dispose() {
    debugPrint('CommentRepository 리소스 정리 완료');
  }
}