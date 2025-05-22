import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

/// NotificationHandler 클래스는 앱 내에서 발생하는 이벤트에 대해 알림을 생성하고,
/// Firestore에 저장하는 역할을 합니다.
class NotificationHandler {
  final NotificationRepository _notificationRepository = NotificationRepository();
  final Uuid _uuid = const Uuid();
  
  // 싱글톤 패턴 구현
  static final NotificationHandler _instance = NotificationHandler._internal();
  
  factory NotificationHandler() {
    return _instance;
  }
  
  NotificationHandler._internal();
  
  // 댓글 알림 생성
  Future<void> createCommentNotification({
    required String postId,
    required String postOwnerId,
    required String commentId,
    required String commentorId,
    required String commentorUsername,
    required String commentText,
    String? postTitle,
  }) async {
    try {
      // 자신의 게시물에 댓글 단 경우 알림 생성 안함
      if (postOwnerId == commentorId) {
        debugPrint('자신의 게시물에 댓글: 알림 생성 안함');
        return;
      }
      
      // 알림 ID 생성
      const uuid = Uuid();
      final notificationId = uuid.v4();
      
      // 알림 제목/내용 구성
      final truncatedText = _truncateText(commentText, 40);
      const notificationTitle = '새로운 댓글';
      final notificationBody = postTitle != null
          ? '$commentorUsername님이 "${_truncateText(postTitle, 20)}" 게시물에 댓글을 남겼습니다: "$truncatedText"'
          : '$commentorUsername님이 회원님의 게시물에 댓글을 남겼습니다: "$truncatedText"';
      
      // 알림 모델 생성
      final notification = NotificationModel(
        id: notificationId,
        userId: postOwnerId,
        title: notificationTitle,
        body: notificationBody,
        type: NotificationType.comment,
        data: {
          'type': 'comment',
          'postId': postId,
          'targetId': postId,
          'commentId': commentId,
          'commentorId': commentorId,
          'commentText': commentText,
          'postTitle': postTitle,
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장 (Firebase Functions가 자동으로 FCM 전송)
      await _notificationRepository.saveNotification(notification);
      
      debugPrint('댓글 알림 생성 성공: $notificationId');
    } catch (e) {
      debugPrint('댓글 알림 생성 실패: $e');
    }
  }
  
  // 팔로우 알림 생성
  Future<void> createFollowNotification({
    required String followerId,
    required String followingId,
    required String followerUsername,
  }) async {
    try {
      // 자신을 팔로우 한 경우 알림 생성 안함
      if (followerId == followingId) {
        debugPrint('자신을 팔로우: 알림 생성 안함');
        return;
      }
      
      // 알림 ID 생성
      final notificationId = _uuid.v4();
      
      // 알림 모델 생성
      final notification = NotificationModel(
        id: notificationId,
        userId: followingId,
        title: '새로운 팔로워',
        body: '$followerUsername님이 회원님을 팔로우합니다.',
        type: NotificationType.follow,
        data: {
          'type': 'follow',
          'targetId': followerId,
          'followerId': followerId,
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장 (Firebase Functions가 자동으로 FCM 전송)
      await _notificationRepository.saveNotification(notification);
      
      debugPrint('팔로우 알림 생성 성공: $notificationId');
    } catch (e) {
      debugPrint('팔로우 알림 생성 실패: $e');
    }
  }
  
  // 댓글 답글 알림 생성
  Future<void> createReplyNotification({
    required String postId,
    required String commentId,
    required String commentOwnerId,
    required String replyId,
    required String replierId,
    required String replierUsername,
    required String replyText,
    String? commentText,
  }) async {
    try {
      // 자신의 댓글에 답글 단 경우 알림 생성 안함
      if (commentOwnerId == replierId) {
        debugPrint('자신의 댓글에 답글: 알림 생성 안함');
        return;
      }
      
      // 알림 ID 생성
      final notificationId = _uuid.v4();
      
      // 알림 내용 구성
      final truncatedReply = _truncateText(replyText, 30);
      String notificationBody;
      
      if (commentText != null) {
        final truncatedComment = _truncateText(commentText, 20);
        notificationBody = '$replierUsername님이 회원님의 댓글 "$truncatedComment"에 답글을 남겼습니다: "$truncatedReply"';
      } else {
        notificationBody = '$replierUsername님이 회원님의 댓글에 답글을 남겼습니다: "$truncatedReply"';
      }
      
      // 알림 모델 생성
      final notification = NotificationModel(
        id: notificationId,
        userId: commentOwnerId,
        title: '새로운 답글',
        body: notificationBody,
        type: NotificationType.reply,
        data: {
          'type': 'reply',
          'postId': postId,
          'targetId': postId,
          'commentId': commentId,
          'replyId': replyId,
          'replierId': replierId,
          'replyText': replyText,
          'commentText': commentText,
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장 (Firebase Functions가 자동으로 FCM 전송)
      await _notificationRepository.saveNotification(notification);
      
      debugPrint('답글 알림 생성 성공: $notificationId');
    } catch (e) {
      debugPrint('답글 알림 생성 실패: $e');
    }
  }
  
  // 좋아요 알림 생성
  Future<void> createLikeNotification({
    required String postId,
    required String postOwnerId,
    required String likerId,
    required String likerUsername,
    String? postTitle,
  }) async {
    try {
      // 자신의 게시물에 좋아요 한 경우 알림 생성 안함
      if (postOwnerId == likerId) {
        debugPrint('자신의 게시물에 좋아요: 알림 생성 안함');
        return;
      }
      
      // 알림 ID 생성
      final notificationId = _uuid.v4();
      
      // 알림 내용 구성
      String notificationBody;
      if (postTitle != null) {
        final truncatedTitle = _truncateText(postTitle, 30);
        notificationBody = '$likerUsername님이 회원님의 게시물 "$truncatedTitle"을 좋아합니다.';
      } else {
        notificationBody = '$likerUsername님이 회원님의 게시물을 좋아합니다.';
      }
      
      // 알림 모델 생성
      final notification = NotificationModel(
        id: notificationId,
        userId: postOwnerId,
        title: '새로운 좋아요',
        body: notificationBody,
        type: NotificationType.like,
        data: {
          'type': 'like',
          'postId': postId,
          'targetId': postId,
          'likerId': likerId,
          'postTitle': postTitle,
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장 (Firebase Functions가 자동으로 FCM 전송)
      await _notificationRepository.saveNotification(notification);
      
      debugPrint('좋아요 알림 생성 성공: $notificationId');
    } catch (e) {
      debugPrint('좋아요 알림 생성 실패: $e');
    }
  }
  
  // 메시지 알림 생성
  Future<void> createMessageNotification({
    required String chatId,
    required String receiverId,
    required String senderId,
    required String senderUsername,
    required String messageText,
  }) async {
    try {
      // 알림 ID 생성
      final notificationId = _uuid.v4();
      
      // 알림 모델 생성
      final notification = NotificationModel(
        id: notificationId,
        userId: receiverId,
        title: '새로운 메시지',
        body: '$senderUsername: ${_truncateText(messageText, 40)}',
        type: NotificationType.message,
        data: {
          'type': 'message',
          'targetId': chatId,
          'chatId': chatId,
          'senderId': senderId,
          'messageText': messageText,
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장 (Firebase Functions가 자동으로 FCM 전송)
      await _notificationRepository.saveNotification(notification);
      
      debugPrint('메시지 알림 생성 성공: $notificationId');
    } catch (e) {
      debugPrint('메시지 알림 생성 실패: $e');
    }
  }
  
  // 기타 알림 생성 (커스텀 알림)
  Future<void> createCustomNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // 알림 ID 생성
      final notificationId = _uuid.v4();
      
      // data에 type 추가
      final notificationData = {
        ...data,
        'type': 'other',
      };
      
      // 알림 모델 생성
      final notification = NotificationModel(
        id: notificationId,
        userId: userId,
        title: title,
        body: body,
        type: NotificationType.other,
        data: notificationData,
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장 (Firebase Functions가 자동으로 FCM 전송)
      await _notificationRepository.saveNotification(notification);
      
      debugPrint('커스텀 알림 생성 성공: $notificationId');
    } catch (e) {
      debugPrint('커스텀 알림 생성 실패: $e');
    }
  }
  
  // 텍스트 길이 제한 유틸리티 함수
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}