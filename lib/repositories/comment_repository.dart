import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../models/comment_model.dart';
import '../services/notification_handler.dart';

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
  
  // 댓글 추가 - 트랜잭션 사용 및 알림 생성 추가
  Future<String> addComment({
    required String postId,
    required String userId,
    required String text,
    String? replyToCommentId,
  }) async {
    debugPrint('댓글 추가 시작 - postId: $postId, userId: $userId, text: $text, replyToCommentId: $replyToCommentId');
    
    try {
      // 댓글 문서 참조 생성
      final commentRef = _firestore.collection('comments').doc();
      final commentId = commentRef.id;
      
      // 게시물 정보와 사용자 정보를 먼저 가져오기 (알림 생성을 위해)
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('게시물이 존재하지 않습니다');
      }
      
      final postData = postDoc.data()!;
      final postOwnerId = postData['userId'] as String;
      final postCaption = postData['caption'] as String?;
      
      // 댓글 작성자 정보 가져오기
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }
      
      final userData = userDoc.data()!;
      final commentorUsername = userData['username'] as String? ?? userData['name'] as String? ?? 'Someone';
      
      // 트랜잭션으로 댓글 추가와 카운트 업데이트를 원자적으로 처리
      await _firestore.runTransaction((transaction) async {
        // 1. 댓글 데이터 준비
        final commentData = {
          'id': commentId,
          'postId': postId,
          'userId': userId,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'replyToCommentId': replyToCommentId,
        };
        
        // 2. 댓글 문서 생성
        transaction.set(commentRef, commentData);
        
        // 3. 게시물 댓글 수 업데이트
        final currentCount = postData['commentsCount'] ?? 0;
        final newCount = currentCount + 1;
        
        debugPrint('댓글 카운트 업데이트: $currentCount → $newCount');
        
        transaction.update(_firestore.collection('posts').doc(postId), {
          'commentsCount': newCount,
        });
      }, timeout: const Duration(seconds: 10));
      
      // 4. 알림 생성 (트랜잭션 외부에서 처리)
      if (postOwnerId != userId) {
        debugPrint('알림 생성 시작: 게시물 작성자($postOwnerId)에게 댓글 알림');
        
        try {
          final notificationHandler = NotificationHandler();
          
          if (replyToCommentId == null) {
            // 일반 댓글 알림
            await notificationHandler.createCommentNotification(
              postId: postId,
              postOwnerId: postOwnerId,
              commentId: commentId,
              commentorId: userId,
              commentorUsername: commentorUsername,
              commentText: text,
              postTitle: postCaption,
            );
            debugPrint('댓글 알림 생성 완료');
          } else {
            // 답글 알림 (답글인 경우)
            final parentCommentDoc = await _firestore.collection('comments').doc(replyToCommentId).get();
            if (parentCommentDoc.exists) {
              final parentCommentData = parentCommentDoc.data()!;
              final parentCommentOwnerId = parentCommentData['userId'] as String;
              final parentCommentText = parentCommentData['text'] as String?;
              
              if (parentCommentOwnerId != userId) {
                await notificationHandler.createReplyNotification(
                  postId: postId,
                  commentId: replyToCommentId,
                  commentOwnerId: parentCommentOwnerId,
                  replyId: commentId,
                  replierId: userId,
                  replierUsername: commentorUsername,
                  replyText: text,
                  commentText: parentCommentText,
                );
                debugPrint('답글 알림 생성 완료');
              }
            }
          }
        } catch (notifError) {
          // 알림 생성 실패는 댓글 작성을 막지 않음
          debugPrint('알림 생성 실패 (무시하고 진행): $notifError');
        }
      }
      
      debugPrint('댓글 추가 완료: $commentId');
      return commentId;
    } catch (e, stackTrace) {
      debugPrint('댓글 추가 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
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
  
  // 댓글 삭제 - 트랜잭션 사용으로 수정
  Future<void> deleteComment({
    required String commentId,
    required String postId,
    bool isReply = false,
  }) async {
    debugPrint('댓글 삭제 시작 - commentId: $commentId, postId: $postId, isReply: $isReply');
    
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. 삭제할 댓글 문서 가져오기
        final commentRef = _firestore.collection('comments').doc(commentId);
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('댓글이 존재하지 않습니다');
        }
        
        // 2. 게시물 문서 가져오기
        final postRef = _firestore.collection('posts').doc(postId);
        final postDoc = await transaction.get(postRef);
        
        if (!postDoc.exists) {
          throw Exception('게시물이 존재하지 않습니다');
        }
        
        // 3. 삭제할 댓글 수 계산
        int commentsToDelete = 1; // 기본적으로 자기 자신
        
        // 답글이 아닌 경우, 해당 댓글의 답글들도 카운트
        if (!isReply) {
          final repliesQuery = await _firestore
              .collection('comments')
              .where('replyToCommentId', isEqualTo: commentId)
              .get();
          
          commentsToDelete += repliesQuery.docs.length;
          debugPrint('삭제할 답글 수: ${repliesQuery.docs.length}개');
          
          // 답글들 삭제
          for (final replyDoc in repliesQuery.docs) {
            transaction.delete(replyDoc.reference);
          }
        }
        
        // 4. 댓글 문서 삭제
        transaction.delete(commentRef);
        
        // 5. 게시물 댓글 수 업데이트 (모든 삭제된 댓글 수만큼 감소)
        final currentCount = postDoc.data()?['commentsCount'] ?? 0;
        final newCount = (currentCount - commentsToDelete).clamp(0, double.infinity).toInt();
        
        transaction.update(postRef, {
          'commentsCount': newCount,
        });
        
        debugPrint('트랜잭션 완료: 댓글 $commentsToDelete개 삭제, 카운트 $currentCount → $newCount');
      });
      
      debugPrint('댓글 삭제 완료');
    } catch (e) {
      debugPrint('댓글 삭제 실패: $e');
      rethrow;
    }
  }
  
  // 리소스 정리 (앱 종료 시 호출)
  void dispose() {
    debugPrint('CommentRepository 리소스 정리 완료');
  }
}