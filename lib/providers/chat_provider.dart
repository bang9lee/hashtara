import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../repositories/chat_repository.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

// 채팅 저장소 프로바이더
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// 사용자의 채팅방 목록 프로바이더 (활성 채팅방만)
final userChatsProvider = StreamProvider.family<List<ChatModel>, String>((ref, userId) {
  debugPrint('userChatsProvider 초기화됨: $userId');
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getUserChats(userId);
});

// 사용자의 대기 중인 채팅 요청 목록 프로바이더
final pendingChatRequestsProvider = StreamProvider.family<List<ChatModel>, String>((ref, userId) {
  debugPrint('pendingChatRequestsProvider 초기화됨: $userId');
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getPendingChatRequests(userId);
});

// 특정 채팅방 메시지 프로바이더
final chatMessagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  debugPrint('chatMessagesProvider 초기화됨: $chatId');
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getChatMessages(chatId);
});

// 채팅방 정보 프로바이더
final chatDetailProvider = StreamProvider.family<ChatModel?, String>((ref, chatId) {
  debugPrint('chatDetailProvider 초기화됨: $chatId');
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getChatById(chatId);
});

// 채팅 컨트롤러 프로바이더
final chatControllerProvider = StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatController(repository, ref);
});

// 읽지 않은 메시지 카운트 프로바이더
final unreadMessagesCountProvider = StreamProvider.family<int, String>((ref, userId) {
  debugPrint('unreadMessagesCountProvider 초기화됨: $userId');
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getUnreadMessagesCount(userId);
});

// 읽지 않은 채팅 요청 카운트 프로바이더
final unreadChatRequestsCountProvider = StreamProvider.family<int, String>((ref, userId) {
  debugPrint('unreadChatRequestsCountProvider 초기화됨: $userId');
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getUnreadChatRequestsCount(userId);
});

// 채팅 컨트롤러 클래스
class ChatController extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repository;
  final Ref _ref;
  
  ChatController(this._repository, this._ref) : super(const AsyncValue.data(null));
  
  // 메시지 전송
  Future<String?> sendMessage({
    required String chatId,
    required String senderId,
    String? text,
    List<File>? imageFiles,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final messageId = await _repository.sendMessage(
        chatId: chatId,
        senderId: senderId,
        text: text,
        imageFiles: imageFiles,
      );
      
      // 필요한 프로바이더 새로고침
      final refreshMessages = _ref.refresh(chatMessagesProvider(chatId));
      debugPrint('메시지 목록 새로고침: ${refreshMessages.hashCode}');
      
      state = const AsyncValue.data(null);
      return messageId;
    } catch (e, stack) {
      debugPrint('메시지 전송 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 채팅방 생성 (기존 메서드 - 그룹 채팅용)
  Future<String?> createChat({
    required List<String> participantIds,
    bool isGroup = false,
    String? groupName,
    String? groupImageUrl,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final chatId = await _repository.createChat(
        participantIds: participantIds,
        isGroup: isGroup,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
      );
      
      // 사용자별 채팅방 목록 새로고침
      for (final userId in participantIds) {
        final refreshChats = _ref.refresh(userChatsProvider(userId));
        debugPrint('사용자 $userId 채팅방 목록 새로고침: ${refreshChats.hashCode}');
      }
      
      state = const AsyncValue.data(null);
      return chatId;
    } catch (e, stack) {
      debugPrint('채팅방 생성 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 채팅 요청 보내기
  Future<String?> sendChatRequest({
    required String requesterId,
    required String receiverId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final chatId = await _repository.sendChatRequest(
        requesterId: requesterId,
        receiverId: receiverId,
      );
      
      // 요청자와 수신자의 채팅 요청 목록 새로고침
      // ignore: unused_result
      _ref.refresh(pendingChatRequestsProvider(receiverId));
      
      state = const AsyncValue.data(null);
      return chatId;
    } catch (e, stack) {
      debugPrint('채팅 요청 전송 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 채팅 요청 수락
  Future<void> acceptChatRequest({
    required String chatId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.acceptChatRequest(chatId: chatId, userId: userId);
      
      // 채팅방 목록과 요청 목록 새로고침
      // ignore: unused_result
      _ref.refresh(userChatsProvider(userId));
      // ignore: unused_result
      _ref.refresh(pendingChatRequestsProvider(userId));
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('채팅 요청 수락 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 채팅 요청 거절
  Future<void> rejectChatRequest({
    required String chatId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.rejectChatRequest(chatId: chatId, userId: userId);
      
      // 요청 목록 새로고침
      // ignore: unused_result
      _ref.refresh(pendingChatRequestsProvider(userId));
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('채팅 요청 거절 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 메시지 읽음 표시
  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
  }) async {
    try {
      await _repository.markMessagesAsRead(chatId: chatId, userId: userId);
      
      // 메시지 목록 새로고침
      final refreshMessages = _ref.refresh(chatMessagesProvider(chatId));
      debugPrint('메시지 목록 새로고침: ${refreshMessages.hashCode}');
      
      // 읽지 않은 메시지 카운트 새로고침
      final refreshUnread = _ref.refresh(unreadMessagesCountProvider(userId));
      debugPrint('읽지 않은 메시지 새로고침: ${refreshUnread.hashCode}');
    } catch (e) {
      debugPrint('메시지 읽음 표시 실패: $e');
    }
  }
  
  // 1:1 채팅방 ID 가져오기 (없으면 생성) - 이제는 채팅 요청을 보냄
  Future<String?> getOrCreateDirectChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      // 먼저 기존 채팅방이 있는지 확인
      final existingChatId = await _repository.findExistingDirectChat(
        currentUserId,
        otherUserId,
      );
      
      if (existingChatId != null) {
        // 기존 채팅방이 있으면 상태 확인
        final chat = await _repository.getChatByIdOnce(existingChatId);
        
        if (chat != null) {
          if (chat.status == ChatStatus.active) {
            // 활성 채팅방이면 바로 반환
            state = const AsyncValue.data(null);
            return existingChatId;
          } else if (chat.status == ChatStatus.pending) {
            // 대기 중인 요청이 있으면 알림
            throw Exception('이미 채팅 요청을 보냈습니다. 상대방의 응답을 기다려주세요.');
          } else if (chat.status == ChatStatus.rejected) {
            // 거절된 요청이 있으면 알림
            throw Exception('상대방이 채팅 요청을 거절했습니다.');
          }
        }
      }
      
      // 새로운 채팅 요청 보내기
      final chatId = await sendChatRequest(
        requesterId: currentUserId,
        receiverId: otherUserId,
      );
      
      state = const AsyncValue.data(null);
      return chatId;
    } catch (e, stack) {
      debugPrint('채팅방 가져오기/생성 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 채팅방 나가기 (개선된 버전)
  Future<void> leaveChat({
    required String chatId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.leaveChatImproved(chatId: chatId, userId: userId);
      
      // 사용자의 채팅방 목록 새로고침
      final refreshChats = _ref.refresh(userChatsProvider(userId));
      debugPrint('채팅방 목록 새로고침: ${refreshChats.hashCode}');
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('채팅방 나가기 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 1:1 채팅방 ID 생성 또는 가져오기 (Profile Screen용 간소화 메서드)
  Future<String?> createOrGetChatRoom(String currentUserId, String otherUserId) async {
    try {
      return await getOrCreateDirectChat(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
    } catch (e) {
      debugPrint('채팅방 생성/조회 실패: $e');
      rethrow;
    }
  }
}