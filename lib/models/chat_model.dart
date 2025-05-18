import 'package:cloud_firestore/cloud_firestore.dart';

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
  });
  
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupImageUrl': groupImageUrl,
    };
  }
}