import 'package:cloud_firestore/cloud_firestore.dart';

// 채팅방 상태 열거형
enum ChatStatus {
  pending,    // 채팅 요청 대기 중
  active,     // 활성 채팅방
  rejected,   // 요청 거절됨
  left,       // 누군가 나감
}

// 채팅방 타입 열거형
enum ChatType {
  direct,     // 1:1 채팅
  group,      // 그룹 채팅
}

class ChatModel {
  final String id;
  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final bool isGroup;
  final String? groupName;
  final String? groupImageUrl;
  
  // 새로 추가된 필드들
  final ChatStatus status;                    // 채팅방 상태
  final String? requesterId;                  // 채팅 요청한 사용자 ID
  final String? receiverId;                   // 채팅 요청받은 사용자 ID
  final Map<String, DateTime>? leftUsers;     // 나간 사용자들과 나간 시간
  final DateTime? acceptedAt;                 // 채팅 수락 시간
  final DateTime? rejectedAt;                 // 채팅 거절 시간
  
  ChatModel({
    required this.id,
    required this.participantIds,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.isGroup = false,
    this.groupName,
    this.groupImageUrl,
    this.status = ChatStatus.active,
    this.requesterId,
    this.receiverId,
    this.leftUsers,
    this.acceptedAt,
    this.rejectedAt,
  });
  
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // leftUsers 맵 파싱
    Map<String, DateTime>? leftUsersMap;
    if (data['leftUsers'] != null) {
      leftUsersMap = {};
      final leftUsersData = data['leftUsers'] as Map<String, dynamic>;
      leftUsersData.forEach((key, value) {
        if (value is Timestamp) {
          leftUsersMap![key] = value.toDate();
        }
      });
    }
    
    return ChatModel(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessageAt: data['lastMessageAt'] != null 
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : (data['createdAt'] as Timestamp).toDate(),
      lastMessageText: data['lastMessageText'],
      lastMessageSenderId: data['lastMessageSenderId'],
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      groupImageUrl: data['groupImageUrl'],
      status: _stringToChatStatus(data['status'] ?? 'active'),
      requesterId: data['requesterId'],
      receiverId: data['receiverId'],
      leftUsers: leftUsersMap,
      acceptedAt: data['acceptedAt'] != null 
          ? (data['acceptedAt'] as Timestamp).toDate() 
          : null,
      rejectedAt: data['rejectedAt'] != null 
          ? (data['rejectedAt'] as Timestamp).toDate() 
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    // leftUsers를 Timestamp로 변환
    Map<String, Timestamp>? leftUsersTimestamp;
    if (leftUsers != null) {
      leftUsersTimestamp = {};
      leftUsers!.forEach((key, value) {
        leftUsersTimestamp![key] = Timestamp.fromDate(value);
      });
    }
    
    return {
      'participantIds': participantIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupImageUrl': groupImageUrl,
      'status': _chatStatusToString(status),
      'requesterId': requesterId,
      'receiverId': receiverId,
      'leftUsers': leftUsersTimestamp,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
    };
  }
  
  // 사용자가 채팅방을 나갔는지 확인
  bool hasUserLeft(String userId) {
    return leftUsers?.containsKey(userId) ?? false;
  }
  
  // 활성 참가자 목록 가져오기 (나가지 않은 사용자들)
  List<String> get activeParticipantIds {
    if (leftUsers == null || leftUsers!.isEmpty) {
      return participantIds;
    }
    return participantIds.where((id) => !leftUsers!.containsKey(id)).toList();
  }
  
  // 채팅방이 활성 상태인지 확인
  bool get isActive => status == ChatStatus.active && activeParticipantIds.isNotEmpty;
  
  // ChatStatus enum 변환 헬퍼 함수들
  static ChatStatus _stringToChatStatus(String status) {
    switch (status) {
      case 'pending':
        return ChatStatus.pending;
      case 'active':
        return ChatStatus.active;
      case 'rejected':
        return ChatStatus.rejected;
      case 'left':
        return ChatStatus.left;
      default:
        return ChatStatus.active;
    }
  }
  
  static String _chatStatusToString(ChatStatus status) {
    switch (status) {
      case ChatStatus.pending:
        return 'pending';
      case ChatStatus.active:
        return 'active';
      case ChatStatus.rejected:
        return 'rejected';
      case ChatStatus.left:
        return 'left';
    }
  }
}