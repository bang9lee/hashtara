import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // 사용자의 채팅방 목록 가져오기
  Stream<List<ChatModel>> getUserChats(String userId) {
    try {
      debugPrint('사용자 채팅방 목록 로드 시도: $userId');
      
      return _firestore
          .collection('chats')
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .map((snapshot) {
            debugPrint('채팅방 ${snapshot.docs.length}개 받음');
            return snapshot.docs
                .map((doc) => ChatModel.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      debugPrint('사용자 채팅방 목록 로드 오류: $e');
      return Stream.value([]);
    }
  }
  
  // 채팅방의 메시지 목록 가져오기
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    try {
      debugPrint('채팅방 메시지 로드 시도: $chatId');
      
      return _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            debugPrint('메시지 ${snapshot.docs.length}개 받음');
            return snapshot.docs
                .map((doc) => MessageModel.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      debugPrint('채팅방 메시지 로드 오류: $e');
      return Stream.value([]);
    }
  }
  
  // 채팅방 정보 가져오기
  Stream<ChatModel?> getChatById(String chatId) {
    try {
      debugPrint('채팅방 정보 로드 시도: $chatId');
      
      return _firestore
          .collection('chats')
          .doc(chatId)
          .snapshots()
          .map((doc) {
            if (doc.exists) {
              return ChatModel.fromFirestore(doc);
            }
            return null;
          });
    } catch (e) {
      debugPrint('채팅방 정보 로드 오류: $e');
      return Stream.value(null);
    }
  }
  
  // 메시지 전송
  Future<String> sendMessage({
    required String chatId,
    required String senderId,
    String? text,
    List<File>? imageFiles,
  }) async {
    try {
      debugPrint('메시지 전송 시도: $chatId');
      
      // 이미지 업로드
      List<String>? imageUrls;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        imageUrls = await Future.wait(
          imageFiles.map((file) => _uploadMessageImage(chatId, file))
        );
      }
      
      // 참가자 목록 가져오기
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final participants = List<String>.from((chatDoc.data() as Map<String, dynamic>)['participantIds'] ?? []);
      
      // 읽음 상태 초기화
      final Map<String, bool> readBy = {};
      for (final participant in participants) {
        readBy[participant] = participant == senderId;
      }
      
      // 메시지 데이터 생성
      final message = MessageModel(
        id: '',
        chatId: chatId,
        senderId: senderId,
        text: text,
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
        isRead: false,
        readBy: readBy,
      );
      
      // 메시지 저장
      final docRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());
      
      // 채팅방 정보 업데이트
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': text ?? '이미지를 보냈습니다',
        'lastMessageSenderId': senderId,
      });
      
      debugPrint('메시지 전송 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('메시지 전송 오류: $e');
      rethrow;
    }
  }
  
  // 메시지 이미지 업로드
  Future<String> _uploadMessageImage(String chatId, File imageFile) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage
        .ref()
        .child('chat_images')
        .child(chatId)
        .child(fileName);
    
    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }
  
  // 채팅방 생성
  Future<String> createChat({
    required List<String> participantIds,
    bool isGroup = false,
    String? groupName,
    String? groupImageUrl,
  }) async {
    try {
      debugPrint('채팅방 생성 시도');
      
      // 중복 채팅방 검사 (1:1 채팅인 경우)
      if (!isGroup && participantIds.length == 2) {
        final existingChatId = await _findExistingDirectChat(
          participantIds[0],
          participantIds[1],
        );
        
        if (existingChatId != null) {
          debugPrint('기존 채팅방 발견: $existingChatId');
          return existingChatId;
        }
      }
      
      // 채팅방 데이터 생성
      final now = DateTime.now();
      final chat = ChatModel(
        id: '',
        participantIds: participantIds,
        createdAt: now,
        lastMessageAt: now,
        isGroup: isGroup,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
      );
      
      // 채팅방 저장
      final docRef = await _firestore
          .collection('chats')
          .add(chat.toMap());
      
      debugPrint('채팅방 생성 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('채팅방 생성 오류: $e');
      rethrow;
    }
  }
  
  // 기존 1:1 채팅방 찾기
  Future<String?> _findExistingDirectChat(String userId1, String userId2) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participantIds', arrayContains: userId1)
          .where('isGroup', isEqualTo: false)
          .get();
      
      for (final doc in snapshot.docs) {
        final participantIds = List<String>.from((doc.data())['participantIds'] ?? []);
        if (participantIds.length == 2 && participantIds.contains(userId2)) {
          return doc.id;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('채팅방 검색 오류: $e');
      return null;
    }
  }
  
  // 메시지 읽음 표시
  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
  }) async {
    try {
      debugPrint('메시지 읽음 표시 시도: $chatId, $userId');
      
      // 읽지 않은 메시지 검색
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('readBy.$userId', isEqualTo: false)
          .get();
      
      // 일괄 업데이트를 위한 배치 작업
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'readBy.$userId': true,
        });
      }
      
      await batch.commit();
      debugPrint('메시지 읽음 표시 완료: ${snapshot.docs.length}개');
    } catch (e) {
      debugPrint('메시지 읽음 표시 오류: $e');
      rethrow;
    }
  }
  
  // 읽지 않은 메시지 수 가져오기
  Stream<int> getUnreadMessagesCount(String userId) {
    try {
      debugPrint('읽지 않은 메시지 수 로드 시도: $userId');
      
      // 먼저 사용자의 모든 채팅방 ID 가져오기
      return _firestore
          .collection('chats')
          .where('participantIds', arrayContains: userId)
          .snapshots()
          .asyncMap((chatSnapshot) async {
            int totalUnread = 0;
            
            for (final chatDoc in chatSnapshot.docs) {
              final chatId = chatDoc.id;
              
              // 각 채팅방의 읽지 않은 메시지 수 계산
              final messagesSnapshot = await _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .where('readBy.$userId', isEqualTo: false)
                  .count()
                  .get();
              
              totalUnread += messagesSnapshot.count ?? 0;
            }
            
            debugPrint('읽지 않은 메시지 수: $totalUnread');
            return totalUnread;
          });
    } catch (e) {
      debugPrint('읽지 않은 메시지 수 로드 오류: $e');
      return Stream.value(0);
    }
  }
  
  // 1:1 채팅방 가져오기 또는 생성하기
  Future<String> getOrCreateDirectChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      debugPrint('1:1 채팅방 검색 또는 생성: $currentUserId, $otherUserId');
      
      // 기존 채팅방 검색
      final existingChatId = await _findExistingDirectChat(
        currentUserId,
        otherUserId,
      );
      
      // 기존 채팅방이 있으면 반환
      if (existingChatId != null) {
        debugPrint('기존 채팅방 발견: $existingChatId');
        return existingChatId;
      }
      
      // 없으면 새로 생성
      return await createChat(
        participantIds: [currentUserId, otherUserId],
        isGroup: false,
      );
    } catch (e) {
      debugPrint('채팅방 가져오기/생성 오류: $e');
      rethrow;
    }
  }
  
  // 채팅방 나가기
  Future<void> leaveChat({
    required String chatId,
    required String userId,
  }) async {
    try {
      debugPrint('채팅방 나가기 시도: $chatId, $userId');
      
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data() as Map<String, dynamic>;
      
      // 참가자 목록에서 사용자 제거
      final List<String> participants = List<String>.from(chatData['participantIds'] ?? []);
      participants.remove(userId);
      
      if (participants.isEmpty) {
        // 참가자가 없으면 채팅방 삭제
        await _firestore.collection('chats').doc(chatId).delete();
        debugPrint('모든 참가자가 나갔으므로 채팅방 삭제: $chatId');
      } else {
        // 참가자가 있으면 사용자만 제거
        await _firestore.collection('chats').doc(chatId).update({
          'participantIds': participants,
        });
        debugPrint('채팅방에서 사용자 제거됨: $chatId, $userId');
      }
    } catch (e) {
      debugPrint('채팅방 나가기 오류: $e');
      rethrow;
    }
  }
}