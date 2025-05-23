import 'package:cloud_firestore/cloud_firestore.dart';

// 메시지 타입 열거형
enum MessageType {
  text,           // 일반 텍스트 메시지
  image,          // 이미지 메시지
  system,         // 시스템 메시지
  chatRequest,    // 채팅 요청 메시지
}

// 시스템 메시지 타입
enum SystemMessageType {
  userJoined,         // 사용자 참여
  userLeft,           // 사용자 나감
  chatAccepted,       // 채팅 요청 수락됨
  chatRejected,       // 채팅 요청 거절됨
  chatRequestSent,    // 채팅 요청 전송됨
  other,              // 기타
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final List<String>? imageUrls;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, bool>? readBy;
  
  // 새로 추가된 필드들
  final MessageType type;                    // 메시지 타입
  final SystemMessageType? systemType;        // 시스템 메시지 타입
  final Map<String, dynamic>? metadata;       // 추가 메타데이터
  
  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    this.imageUrls,
    required this.createdAt,
    this.isRead = false,
    this.readBy,
    this.type = MessageType.text,
    this.systemType,
    this.metadata,
  });
  
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 이미지 URLs 처리
    List<String>? imageUrlsList;
    if (data['imageUrls'] != null) {
      imageUrlsList = List<String>.from(data['imageUrls']);
    }
    
    // readBy 맵 처리
    Map<String, bool>? readByMap;
    if (data['readBy'] != null) {
      readByMap = Map<String, bool>.from(data['readBy']);
    }
    
    // metadata 처리
    Map<String, dynamic>? metadataMap;
    if (data['metadata'] != null) {
      metadataMap = Map<String, dynamic>.from(data['metadata']);
    }
    
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'],
      imageUrls: imageUrlsList,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      readBy: readByMap,
      type: _stringToMessageType(data['type'] ?? 'text'),
      systemType: data['systemType'] != null 
          ? _stringToSystemMessageType(data['systemType']) 
          : null,
      metadata: metadataMap,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'readBy': readBy,
      'type': _messageTypeToString(type),
      'systemType': systemType != null ? _systemMessageTypeToString(systemType!) : null,
      'metadata': metadata,
    };
  }
  
  // 시스템 메시지 생성 팩토리 메서드
  factory MessageModel.systemMessage({
    required String chatId,
    required SystemMessageType systemType,
    required String text,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: '',
      chatId: chatId,
      senderId: 'system',
      text: text,
      createdAt: DateTime.now(),
      type: MessageType.system,
      systemType: systemType,
      metadata: metadata,
    );
  }
  
  // 채팅 요청 메시지 생성 팩토리 메서드
  factory MessageModel.chatRequest({
    required String chatId,
    required String senderId,
    required String receiverName,
  }) {
    return MessageModel(
      id: '',
      chatId: chatId,
      senderId: senderId,
      text: '$receiverName님에게 채팅을 요청했습니다.',
      createdAt: DateTime.now(),
      type: MessageType.chatRequest,
      systemType: SystemMessageType.chatRequestSent,
      metadata: {
        'receiverName': receiverName,
      },
    );
  }
  
  // MessageType enum 변환 헬퍼 함수들
  static MessageType _stringToMessageType(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'system':
        return MessageType.system;
      case 'chatRequest':
        return MessageType.chatRequest;
      default:
        return MessageType.text;
    }
  }
  
  static String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.system:
        return 'system';
      case MessageType.chatRequest:
        return 'chatRequest';
    }
  }
  
  // SystemMessageType enum 변환 헬퍼 함수들
  static SystemMessageType _stringToSystemMessageType(String type) {
    switch (type) {
      case 'userJoined':
        return SystemMessageType.userJoined;
      case 'userLeft':
        return SystemMessageType.userLeft;
      case 'chatAccepted':
        return SystemMessageType.chatAccepted;
      case 'chatRejected':
        return SystemMessageType.chatRejected;
      case 'chatRequestSent':
        return SystemMessageType.chatRequestSent;
      default:
        return SystemMessageType.other;
    }
  }
  
  static String _systemMessageTypeToString(SystemMessageType type) {
    switch (type) {
      case SystemMessageType.userJoined:
        return 'userJoined';
      case SystemMessageType.userLeft:
        return 'userLeft';
      case SystemMessageType.chatAccepted:
        return 'chatAccepted';
      case SystemMessageType.chatRejected:
        return 'chatRejected';
      case SystemMessageType.chatRequestSent:
        return 'chatRequestSent';
      case SystemMessageType.other:
        return 'other';
    }
  }
}