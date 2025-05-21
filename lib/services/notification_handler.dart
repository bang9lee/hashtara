import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

/// NotificationHandler 클래스는 앱 내에서 발생하는 이벤트에 대해 알림을 생성하고,
/// Firestore에 저장하는 역할을 합니다.
class NotificationHandler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
    String? postTitle,  // 게시물 제목 추가
  }) async {
    try {
      // 자신의 게시물에 댓글 단 경우 알림 생성 안함
      if (postOwnerId == commentorId) {
        debugPrint('자신의 게시물에 댓글: 알림 생성 안함');
        return;
      }
      
      // 알림 ID 생성 - const 사용
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
          'id': notificationId, // 알림 ID 추가
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장
      await _notificationRepository.saveNotification(notification);
      
      // FCM 메시지 설정 및 전송 요청
      await _setupFCMMessageRequest(
        userId: postOwnerId,
        title: notification.title,
        body: notification.body,
        data: notification.data,
      );
      
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
          'targetId': followerId,  // 팔로워의 프로필로 이동하기 위해
          'followerId': followerId,
          'id': notificationId, // 알림 ID 추가
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장
      await _notificationRepository.saveNotification(notification);
      
      // FCM 메시지 설정 및 전송 요청
      await _setupFCMMessageRequest(
        userId: followingId,
        title: notification.title,
        body: notification.body,
        data: notification.data,
      );
      
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
    String? commentText,  // 원 댓글 내용 추가
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
          'id': notificationId, // 알림 ID 추가
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장
      await _notificationRepository.saveNotification(notification);
      
      // FCM 메시지 설정 및 전송 요청
      await _setupFCMMessageRequest(
        userId: commentOwnerId,
        title: notification.title,
        body: notification.body,
        data: notification.data,
      );
      
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
    String? postTitle,  // 게시물 제목 추가
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
          'id': notificationId, // 알림 ID 추가
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장
      await _notificationRepository.saveNotification(notification);
      
      // FCM 메시지 설정 및 전송 요청
      await _setupFCMMessageRequest(
        userId: postOwnerId,
        title: notification.title,
        body: notification.body,
        data: notification.data,
      );
      
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
          'id': notificationId, // 알림 ID 추가
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      // Firestore에 알림 저장
      await _notificationRepository.saveNotification(notification);
      
      // FCM 메시지 설정 및 전송 요청 (메시지는 배지 추가)
      await _setupFCMMessageRequest(
        userId: receiverId,
        title: notification.title,
        body: notification.body,
        data: notification.data,
        badge: 1, // 배지 추가
      );
      
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
      
      // data에 ID와 type 추가
      final notificationData = {
        ...data,
        'id': notificationId,
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
      
      // Firestore에 알림 저장
      await _notificationRepository.saveNotification(notification);
      
      // FCM 메시지 설정 및 전송 요청
      await _setupFCMMessageRequest(
        userId: userId,
        title: notification.title,
        body: notification.body,
        data: notification.data,
      );
      
      debugPrint('커스텀 알림 생성 성공: $notificationId');
    } catch (e) {
      debugPrint('커스텀 알림 생성 실패: $e');
    }
  }
  
  // FCM 메시지 요청 설정
  Future<void> _setupFCMMessageRequest({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    int? badge,
  }) async {
    try {
      // 토큰 정보 가져오기
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData != null && userData['fcmTokens'] != null) {
        final fcmTokens = List<String>.from(userData['fcmTokens']);
        
        // 토큰이 있는 경우에만 FCM 요청 생성
        if (fcmTokens.isNotEmpty) {
          final fcmRequest = {
            'tokens': fcmTokens,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': data,
            'createdAt': FieldValue.serverTimestamp(),
            'sent': false,
            'priority': 'high', // 우선순위 높음
            'sound': 'default', // 기본 알림음
            'contentAvailable': true, // 백그라운드에서도 처리
            'clickAction': 'FLUTTER_NOTIFICATION_CLICK', // Flutter 앱 열기
            'mutableContent': true, // iOS - 알림 내용 수정 가능 (커스텀 액션 등)
            'category': 'message', // iOS - 알림 카테고리 지정
          };
          
          // 모바일 알림 설정 강화
          fcmRequest['android'] = {
            'priority': 'high', // Android 우선순위
            'notification': {
              'channelId': 'hashtara_notifications', // Android 채널 ID
              'clickAction': 'FLUTTER_NOTIFICATION_CLICK',
              'visibility': 'public', // 잠금화면에서도 표시
              'priority': 'max', // 알림 우선순위 (팝업 표시)
              'defaultSound': true, // 기본 알림음 사용
              'defaultVibrateTimings': true, // 기본 진동 사용
              'notificationCount': 1, // 알림 카운트
            }
          };
          
          // 배지 추가 (iOS)
          if (badge != null) {
            fcmRequest['apns'] = {
              'headers': {
                'apns-priority': '10', // 높은 우선순위
              },
              'payload': {
                'aps': {
                  'badge': badge,
                  'sound': 'default',
                  'content-available': 1, // 백그라운드에서도 처리
                  'mutable-content': 1, // 알림 내용 수정 가능
                  'category': 'message', // 알림 카테고리
                  'alert': {
                    'title': title,
                    'body': body,
                  },
                },
              },
            };
          }
          
          // 메시지 큐에 저장
          await _firestore.collection('fcm_messages').add(fcmRequest);
          debugPrint('FCM 메시지 요청 생성: $title');
        } else {
          debugPrint('FCM 토큰이 없음: $userId');
        }
      } else {
        debugPrint('사용자 FCM 토큰 정보 없음: $userId');
      }
    } catch (e) {
      debugPrint('FCM 메시지 요청 생성 실패: $e');
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