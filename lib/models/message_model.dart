import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final List<String>? imageUrls;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, bool>? readBy;
  
  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    this.imageUrls,
    required this.createdAt,
    this.isRead = false,
    this.readBy,
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
    
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'],
      imageUrls: imageUrlsList,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      readBy: readByMap,
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
    };
  }
}