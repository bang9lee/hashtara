import 'package:cloud_firestore/cloud_firestore.dart';

// 알림 유형 열거
enum NotificationType {
  comment,      // 게시물에 댓글
  reply,        // 댓글에 대댓글
  like,         // 좋아요
  follow,       // 팔로우
  message,      // 메시지
  chatRequest,  // 채팅 요청
  other         // 기타
}

// 알림 모델 클래스
class NotificationModel {
  final String id;          // 알림 ID
  final String userId;      // 수신자 ID
  final String title;       // 알림 제목
  final String body;        // 알림 내용
  final NotificationType type; // 알림 유형
  final Map<String, dynamic> data; // 추가 데이터
  final bool isRead;        // 읽음 여부
  final DateTime createdAt; // 생성 시간
  final DateTime? readAt;   // 읽은 시간
  
  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });
  
  // Firestore에서 데이터 변환
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: _stringToNotificationType(data['type'] ?? 'other'),
      data: data['data'] ?? {},
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null,
    );
  }
  
  // Firestore로 데이터 변환
  Map<String, dynamic> toFirestore() {
    final result = {
      'userId': userId,
      'title': title,
      'body': body,
      'type': _notificationTypeToString(type),
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    
    if (readAt != null) {
      result['readAt'] = Timestamp.fromDate(readAt!);
    }
    
    return result;
  }
  
  // 복사본 생성 (속성 변경 시)
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
  
  // 알림 유형 문자열 변환 (enum -> 문자열)
  static String _notificationTypeToString(NotificationType type) {
    switch (type) {
      case NotificationType.comment:
        return 'comment';
      case NotificationType.reply:
        return 'reply';
      case NotificationType.like:
        return 'like';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.message:
        return 'message';
      case NotificationType.chatRequest:
        return 'chatRequest';
      case NotificationType.other:
        return 'other';
    }
  }
  
  // 문자열에서 알림 유형 변환 (문자열 -> enum)
  static NotificationType _stringToNotificationType(String type) {
    switch (type) {
      case 'comment':
        return NotificationType.comment;
      case 'reply':
        return NotificationType.reply;
      case 'like':
        return NotificationType.like;
      case 'follow':
        return NotificationType.follow;
      case 'message':
        return NotificationType.message;
      case 'chatRequest':
        return NotificationType.chatRequest;
      default:
        return NotificationType.other;
    }
  }
  
  @override
  String toString() {
    return 'NotificationModel{id: $id, title: $title, type: $type, isRead: $isRead}';
  }
}