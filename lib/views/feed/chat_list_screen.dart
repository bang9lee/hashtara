import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../models/chat_model.dart';
import 'chat_detail_screen.dart';
import 'chat_request_screen.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  @override
  Widget build(BuildContext context) {
    // 현재 로그인한 사용자 가져오기
    final currentUserAsync = ref.watch(currentUserProvider);
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: const Text(
          '메시지',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: currentUserAsync.maybeWhen(
          data: (currentUser) {
            if (currentUser == null) return null;
            
            // 읽지 않은 채팅 요청 수
            final unreadRequestsAsync = ref.watch(unreadChatRequestsCountProvider(currentUser.id));
            
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => const ChatRequestScreen(),
                  ),
                );
              },
              child: Stack(
                children: [
                  const Icon(
                    CupertinoIcons.envelope,
                    color: AppColors.white,
                  ),
                  // 읽지 않은 요청이 있으면 빨간 점 표시
                  unreadRequestsAsync.maybeWhen(
                    data: (count) {
                      if (count > 0) {
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accentRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
          orElse: () => null,
        ),
      ),
      child: SafeArea(
        child: currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) {
              return const Center(
                child: Text(
                  '로그인이 필요합니다',
                  style: TextStyle(color: AppColors.textEmphasis),
                ),
              );
            }
            
            // 사용자의 채팅방 목록 가져오기
            final chatsAsync = ref.watch(userChatsProvider(currentUser.id));
            
            return chatsAsync.when(
              data: (chats) {
                if (chats.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_text,
                          size: 60,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '대화가 없습니다',
                          style: TextStyle(
                            color: AppColors.textEmphasis,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '프로필에서 다른 사용자를 팔로우하고\n메시지를 보내보세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    
                    // 상대방 ID 찾기 (1:1 채팅인 경우)
                    String otherUserId = '';
                    if (!chat.isGroup && chat.participantIds.length == 2) {
                      otherUserId = chat.participantIds.firstWhere(
                        (id) => id != currentUser.id,
                        orElse: () => '',
                      );
                    }
                    
                    return _buildChatListItem(
                      context,
                      chat,
                      currentUser.id,
                      otherUserId,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CupertinoActivityIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text(
                  '채팅방 목록을 불러오는 중 오류가 발생했습니다: $error',
                  style: const TextStyle(color: AppColors.textEmphasis),
                ),
              ),
            );
          },
          loading: () => const Center(
            child: CupertinoActivityIndicator(),
          ),
          error: (error, stack) => Center(
            child: Text(
              '사용자 정보를 불러오는 중 오류가 발생했습니다: $error',
              style: const TextStyle(color: AppColors.textEmphasis),
            ),
          ),
        ),
      ),
    );
  }
  
  // 채팅방 목록 아이템 위젯
  Widget _buildChatListItem(
    BuildContext context, 
    ChatModel chat,
    String currentUserId,
    String otherUserId,
  ) {
    // 채팅방 이름 결정
    String chatName = '';
    String? imageUrl;
    
    if (chat.isGroup) {
      // 그룹 채팅인 경우
      chatName = chat.groupName ?? '그룹 채팅';
      imageUrl = chat.groupImageUrl;
    } else {
      // 1:1 채팅인 경우 상대방 정보 가져오기
      final otherUserAsync = ref.watch(getUserProfileProvider(otherUserId));
      
      return otherUserAsync.when(
        data: (otherUser) {
          if (otherUser == null) {
            return const SizedBox.shrink();
          }
          
          chatName = otherUser.name ?? otherUser.username ?? '알 수 없는 사용자';
          imageUrl = otherUser.profileImageUrl;
          
          return _buildChatItem(
            context, 
            chat, 
            chatName, 
            imageUrl, 
            currentUserId,
          );
        },
        loading: () => const Center(
          child: CupertinoActivityIndicator(),
        ),
        error: (_, __) => const SizedBox.shrink(),
      );
    }
    
    return _buildChatItem(
      context, 
      chat, 
      chatName, 
      imageUrl, 
      currentUserId,
    );
  }
  
  Widget _buildChatItem(
    BuildContext context, 
    ChatModel chat, 
    String chatName, 
    String? imageUrl, 
    String currentUserId,
  ) {
    // 읽지 않은 메시지 확인
    bool hasUnreadMessages = false;
    if (chat.lastMessageSenderId != null && 
        chat.lastMessageSenderId != currentUserId) {
      // 임시로 모든 메시지를 읽지 않음으로 처리
      // 실제로는 readBy 상태를 확인해야 함
      hasUnreadMessages = true;
    }
    
    // 사용자가 나간 채팅방인지 확인
    final hasUserLeft = chat.hasUserLeft(currentUserId);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chat.id,
              chatName: chatName,
              imageUrl: imageUrl,
              isGroup: chat.isGroup,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0, 
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          color: hasUserLeft ? AppColors.darkBackground.withValues(alpha: 0.5) : AppColors.darkBackground,
          border: const Border(
            bottom: BorderSide(
              color: AppColors.separator,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // 프로필 이미지
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.separator,
                  width: 1.0,
                ),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.person_fill,
                          color: AppColors.textSecondary,
                          size: 28,
                        ),
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.person_fill,
                      color: AppColors.textSecondary,
                      size: 28,
                    ),
            ),
            const SizedBox(width: 12),
            
            // 채팅 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                chatName,
                                style: TextStyle(
                                  color: hasUserLeft ? AppColors.textSecondary : AppColors.white,
                                  fontSize: 16,
                                  fontWeight: hasUnreadMessages && !hasUserLeft
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUserLeft) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.mediumGray,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '나감',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _formatTimeAgo(chat.lastMessageAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessageText ?? '새로운 대화가 시작되었습니다',
                          style: TextStyle(
                            color: hasUserLeft 
                                ? AppColors.textSecondary.withValues(alpha: 0.7)
                                : (hasUnreadMessages
                                    ? AppColors.white
                                    : AppColors.textSecondary),
                            fontSize: 14,
                            fontWeight: hasUnreadMessages && !hasUserLeft
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnreadMessages && !hasUserLeft)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryPurple,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 시간 형식 포맷팅
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      // 일주일 지나면 날짜만 표시
      return '${dateTime.month}/${dateTime.day}';
    } else if (difference.inDays > 0) {
      // 하루 이상 지났으면 'n일 전'
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      // 시간 단위
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      // 분 단위
      return '${difference.inMinutes}분 전';
    } else {
      // 1분 미만
      return '방금 전';
    }
  }
}