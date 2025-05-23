import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationRepository _notificationRepository = NotificationRepository();
  
  // 사용자의 활성 채팅방 목록 가져오기
  Stream<List<ChatModel>> getUserChats(String userId) {
    try {
      debugPrint('사용자 채팅방 목록 로드 시도: $userId');
      
      return _firestore
          .collection('chats')
          .where('participantIds', arrayContains: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .map((snapshot) {
            debugPrint('채팅방 ${snapshot.docs.length}개 받음');
            return snapshot.docs
                .map((doc) => ChatModel.fromFirestore(doc))
                .where((chat) => !chat.hasUserLeft(userId)) // 사용자가 나가지 않은 채팅방만
                .toList();
          })
          .handleError((error) {
            debugPrint('사용자 채팅방 목록 로드 오류: $error');
            return <ChatModel>[];
          });
    } catch (e) {
      debugPrint('사용자 채팅방 목록 로드 오류: $e');
      return Stream.value([]);
    }
  }
  
  // 사용자의 대기 중인 채팅 요청 목록 가져오기 (수정된 버전)
  Stream<List<ChatModel>> getPendingChatRequests(String userId) {
    try {
      debugPrint('대기 중인 채팅 요청 로드 시도: $userId');
      
      // orderBy를 제거하고 클라이언트 측에서 정렬
      return _firestore
          .collection('chats')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) {
            debugPrint('채팅 요청 ${snapshot.docs.length}개 받음');
            final chats = snapshot.docs
                .map((doc) => ChatModel.fromFirestore(doc))
                .toList();
            
            // 클라이언트 측에서 정렬
            chats.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            return chats;
          })
          .handleError((error) {
            debugPrint('채팅 요청 목록 로드 오류: $error');
            if (error.toString().contains('PERMISSION_DENIED')) {
              debugPrint('권한 오류 - Firestore 규칙 확인 필요');
            }
            return <ChatModel>[];
          });
    } catch (e) {
      debugPrint('채팅 요청 목록 로드 예외: $e');
      return Stream.value([]);
    }
  }
  
  // 읽지 않은 채팅 요청 수 가져오기
  Stream<int> getUnreadChatRequestsCount(String userId) {
    try {
      return _firestore
          .collection('chats')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs.length)
          .handleError((error) {
            debugPrint('읽지 않은 채팅 요청 수 로드 오류: $error');
            return 0;
          });
    } catch (e) {
      debugPrint('읽지 않은 채팅 요청 수 로드 예외: $e');
      return Stream.value(0);
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
          })
          .handleError((error) {
            debugPrint('채팅방 메시지 로드 오류: $error');
            return <MessageModel>[];
          });
    } catch (e) {
      debugPrint('채팅방 메시지 로드 예외: $e');
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
          })
          .handleError((error) {
            debugPrint('채팅방 정보 로드 오류: $error');
            return null;
          });
    } catch (e) {
      debugPrint('채팅방 정보 로드 예외: $e');
      return Stream.value(null);
    }
  }
  
  // 채팅방 정보 한 번만 가져오기
  Future<ChatModel?> getChatByIdOnce(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (doc.exists) {
        return ChatModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('채팅방 정보 가져오기 오류: $e');
      return null;
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
      
      // 채팅방 상태 확인
      final chat = await getChatByIdOnce(chatId);
      if (chat == null) {
        throw Exception('채팅방을 찾을 수 없습니다.');
      }
      
      if (chat.status != ChatStatus.active) {
        throw Exception('이 채팅방에서는 메시지를 보낼 수 없습니다.');
      }
      
      if (chat.hasUserLeft(senderId)) {
        throw Exception('나간 채팅방에서는 메시지를 보낼 수 없습니다.');
      }
      
      // 다른 참가자가 나갔는지 확인
      final activeParticipants = chat.activeParticipantIds;
      if (activeParticipants.length < 2) {
        throw Exception('상대방이 채팅방을 나갔습니다. 메시지를 보낼 수 없습니다.');
      }
      
      // 이미지 업로드
      List<String>? imageUrls;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        imageUrls = await Future.wait(
          imageFiles.map((file) => _uploadMessageImage(chatId, file))
        );
      }
      
      // 참가자 목록 가져오기
      final participants = chat.activeParticipantIds;
      
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
        type: imageUrls != null ? MessageType.image : MessageType.text,
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
  
  // 채팅방 생성 (그룹 채팅용)
  Future<String> createChat({
    required List<String> participantIds,
    bool isGroup = false,
    String? groupName,
    String? groupImageUrl,
  }) async {
    try {
      debugPrint('채팅방 생성 시도');
      
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
        status: ChatStatus.active,
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
  
  // 채팅 요청 보내기
  Future<String> sendChatRequest({
    required String requesterId,
    required String receiverId,
  }) async {
    try {
      debugPrint('채팅 요청 전송 시도: $requesterId -> $receiverId');
      
      // 기존 채팅방이나 요청이 있는지 확인
      final existingChatId = await findExistingDirectChat(requesterId, receiverId);
      if (existingChatId != null) {
        final chat = await getChatByIdOnce(existingChatId);
        if (chat != null) {
          if (chat.status == ChatStatus.pending) {
            throw Exception('이미 대기 중인 채팅 요청이 있습니다.');
          } else if (chat.status == ChatStatus.rejected) {
            // 거절된 요청이 있어도 새로운 요청 가능
            debugPrint('이전에 거절된 요청이 있음. 새 요청 생성.');
          } else if (chat.status == ChatStatus.active) {
            // 이미 활성 채팅방이 있으면 그것을 반환
            debugPrint('이미 활성 채팅방이 있음: $existingChatId');
            return existingChatId;
          }
        }
      }
      
      // 채팅 요청 데이터 생성 - Firestore 규칙 준수
      final now = DateTime.now();
      final chat = ChatModel(
        id: '',
        participantIds: [requesterId, receiverId], // 요청자와 수신자 모두 포함
        createdAt: now,
        lastMessageAt: now,
        isGroup: false,
        status: ChatStatus.pending,
        requesterId: requesterId,
        receiverId: receiverId,
      );
      
      // 채팅 요청 저장
      final docRef = await _firestore
          .collection('chats')
          .add(chat.toMap());
      
      // 채팅 요청 메시지 생성
      final requestMessage = MessageModel.chatRequest(
        chatId: docRef.id,
        senderId: requesterId,
        receiverName: '상대방',
      );
      
      await _firestore
          .collection('chats')
          .doc(docRef.id)
          .collection('messages')
          .add(requestMessage.toMap());
      
      // 수신자에게 알림 전송
      await _sendChatRequestNotification(requesterId, receiverId, docRef.id);
      
      debugPrint('채팅 요청 전송 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('채팅 요청 전송 오류: $e');
      rethrow;
    }
  }
  
  // 채팅 요청 수락
  Future<void> acceptChatRequest({
    required String chatId,
    required String userId,
  }) async {
    try {
      debugPrint('채팅 요청 수락 시도: $chatId');
      
      // 채팅방 상태 업데이트
      await _firestore.collection('chats').doc(chatId).update({
        'status': 'active',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      // 시스템 메시지 추가
      final systemMessage = MessageModel.systemMessage(
        chatId: chatId,
        systemType: SystemMessageType.chatAccepted,
        text: '채팅 요청이 수락되었습니다.',
      );
      
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(systemMessage.toMap());
      
      debugPrint('채팅 요청 수락 완료');
    } catch (e) {
      debugPrint('채팅 요청 수락 오류: $e');
      rethrow;
    }
  }
  
  // 채팅 요청 거절
  Future<void> rejectChatRequest({
    required String chatId,
    required String userId,
  }) async {
    try {
      debugPrint('채팅 요청 거절 시도: $chatId');
      
      // 채팅방 상태 업데이트
      await _firestore.collection('chats').doc(chatId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('채팅 요청 거절 완료');
    } catch (e) {
      debugPrint('채팅 요청 거절 오류: $e');
      rethrow;
    }
  }
  
  // 기존 1:1 채팅방 찾기
  Future<String?> findExistingDirectChat(String userId1, String userId2) async {
    try {
      // 방법 1: userId1이 participantIds에 있는 채팅방 찾기
      final snapshot1 = await _firestore
          .collection('chats')
          .where('participantIds', arrayContains: userId1)
          .where('isGroup', isEqualTo: false)
          .get();
      
      for (final doc in snapshot1.docs) {
        final participantIds = List<String>.from((doc.data())['participantIds'] ?? []);
        if (participantIds.length == 2 && participantIds.contains(userId2)) {
          debugPrint('기존 채팅방 발견 (방법 1): ${doc.id}');
          return doc.id;
        }
      }
      
      // 방법 2: pending 상태의 채팅 요청 확인
      final pendingSnapshot = await _firestore
          .collection('chats')
          .where('requesterId', isEqualTo: userId1)
          .where('receiverId', isEqualTo: userId2)
          .where('status', whereIn: ['pending', 'active', 'rejected'])
          .get();
      
      if (pendingSnapshot.docs.isNotEmpty) {
        debugPrint('기존 채팅 요청/채팅방 발견: ${pendingSnapshot.docs.first.id}');
        return pendingSnapshot.docs.first.id;
      }
      
      // 방법 3: 반대 방향 체크 (수신자가 요청자인 경우)
      final reverseSnapshot = await _firestore
          .collection('chats')
          .where('requesterId', isEqualTo: userId2)
          .where('receiverId', isEqualTo: userId1)
          .where('status', whereIn: ['pending', 'active', 'rejected'])
          .get();
      
      if (reverseSnapshot.docs.isNotEmpty) {
        debugPrint('기존 채팅 요청/채팅방 발견 (반대): ${reverseSnapshot.docs.first.id}');
        return reverseSnapshot.docs.first.id;
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
      
      // 먼저 사용자의 모든 활성 채팅방 ID 가져오기
      return _firestore
          .collection('chats')
          .where('participantIds', arrayContains: userId)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .asyncMap((chatSnapshot) async {
            int totalUnread = 0;
            
            for (final chatDoc in chatSnapshot.docs) {
              final chatId = chatDoc.id;
              final chat = ChatModel.fromFirestore(chatDoc);
              
              // 사용자가 나간 채팅방은 제외
              if (chat.hasUserLeft(userId)) continue;
              
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
          })
          .handleError((error) {
            debugPrint('읽지 않은 메시지 수 로드 오류: $error');
            return 0;
          });
    } catch (e) {
      debugPrint('읽지 않은 메시지 수 로드 예외: $e');
      return Stream.value(0);
    }
  }
  
  // 개선된 채팅방 나가기
  Future<void> leaveChatImproved({
    required String chatId,
    required String userId,
  }) async {
    try {
      debugPrint('채팅방 나가기 시도: $chatId, $userId');
      
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw Exception('채팅방을 찾을 수 없습니다.');
      }
      
      final chat = ChatModel.fromFirestore(chatDoc);
      
      // 이미 나간 사용자인지 확인
      if (chat.hasUserLeft(userId)) {
        debugPrint('이미 나간 채팅방입니다.');
        return;
      }
      
      // 사용자를 leftUsers에 추가
      await _firestore.collection('chats').doc(chatId).update({
        'leftUsers.$userId': FieldValue.serverTimestamp(),
      });
      
      // 시스템 메시지 추가
      final userName = await _getUserName(userId);
      final systemMessage = MessageModel.systemMessage(
        chatId: chatId,
        systemType: SystemMessageType.userLeft,
        text: '$userName님이 채팅방을 나갔습니다.',
        metadata: {'userId': userId, 'userName': userName},
      );
      
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(systemMessage.toMap());
      
      // 모든 참가자가 나갔는지 확인
      final updatedChat = await getChatByIdOnce(chatId);
      if (updatedChat != null) {
        final activeParticipants = updatedChat.activeParticipantIds;
        
        if (activeParticipants.isEmpty) {
          // 모든 참가자가 나갔으면 채팅방 상태를 'left'로 변경
          await _firestore.collection('chats').doc(chatId).update({
            'status': 'left',
          });
          debugPrint('모든 참가자가 나갔으므로 채팅방 상태를 left로 변경');
        } else if (activeParticipants.length == 1) {
          // 한 명만 남았을 때도 실질적으로 채팅이 불가능하므로 상태 변경
          await _firestore.collection('chats').doc(chatId).update({
            'status': 'left',
          });
          debugPrint('채팅 상대가 없으므로 채팅방 상태를 left로 변경');
        }
      }
      
      debugPrint('채팅방 나가기 완료');
    } catch (e) {
      debugPrint('채팅방 나가기 오류: $e');
      rethrow;
    }
  }
  
  // 사용자 이름 가져오기 (헬퍼 메서드)
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['name'] ?? data['username'] ?? '알 수 없는 사용자';
      }
      return '알 수 없는 사용자';
    } catch (e) {
      return '알 수 없는 사용자';
    }
  }
  
  // 채팅 요청 알림 전송
  Future<void> _sendChatRequestNotification(
    String requesterId,
    String receiverId,
    String chatId,
  ) async {
    try {
      final requesterName = await _getUserName(requesterId);
      
      final notification = NotificationModel(
        id: _firestore.collection('notifications').doc().id,
        userId: receiverId,
        title: '새로운 채팅 요청',
        body: '$requesterName님이 채팅을 요청했습니다.',
        type: NotificationType.chatRequest,
        data: {
          'chatId': chatId,
          'requesterId': requesterId,
          'requesterName': requesterName,
        },
        isRead: false,
        createdAt: DateTime.now(),
      );
      
      await _notificationRepository.saveNotification(notification);
      debugPrint('채팅 요청 알림 전송 완료');
    } catch (e) {
      debugPrint('채팅 요청 알림 전송 실패: $e');
    }
  }
  
  // 1:1 채팅방 가져오기 또는 생성하기 (이전 버전 호환성)
  Future<String> getOrCreateDirectChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      debugPrint('1:1 채팅방 검색 또는 생성: $currentUserId, $otherUserId');
      
      // 기존 채팅방 검색
      final existingChatId = await findExistingDirectChat(
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
  
  // 이전 버전 호환성을 위한 채팅방 나가기
  Future<void> leaveChat({
    required String chatId,
    required String userId,
  }) async {
    return leaveChatImproved(chatId: chatId, userId: userId);
  }
}