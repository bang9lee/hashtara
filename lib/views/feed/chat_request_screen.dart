import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../models/chat_model.dart';
import 'chat_detail_screen.dart';

class ChatRequestScreen extends ConsumerStatefulWidget {
  const ChatRequestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatRequestScreen> createState() => _ChatRequestScreenState();
}

class _ChatRequestScreenState extends ConsumerState<ChatRequestScreen> {
  // 채팅 요청 수락
  Future<void> _acceptChatRequest(ChatModel chat) async {
    try {
      final currentUser = ref.read(currentUserProvider).valueOrNull;
      if (currentUser == null) {
        return;
      }
      
      // 채팅방 이름과 이미지 미리 가져오기
      final chatName = await _getChatName(chat, currentUser.id);
      final imageUrl = await _getChatImageUrl(chat, currentUser.id);
      
      // 로딩 다이얼로그 표시
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(),
                  SizedBox(height: 10),
                  Text(
                    '채팅 요청을 수락하는 중...',
                    style: TextStyle(color: AppColors.textEmphasis),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // 채팅 요청 수락
      await ref.read(chatControllerProvider.notifier).acceptChatRequest(
        chatId: chat.id,
        userId: currentUser.id,
      );
      
      // 상태 업데이트를 위한 짧은 대기
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // 채팅 화면으로 이동
      if (mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chat.id,
              chatName: chatName,
              imageUrl: imageUrl,
            ),
          ),
        );
      }
    } catch (e) {
      // 에러 발생 시 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showErrorDialog('오류', '채팅 요청 수락 중 오류가 발생했습니다: $e');
    }
  }
  
  // 채팅 요청 거절
  Future<void> _rejectChatRequest(ChatModel chat) async {
    // 확인 다이얼로그
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('채팅 요청 거절'),
        content: const Text('정말로 이 채팅 요청을 거절하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('거절'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      _showLoadingDialog('채팅 요청을 거절하는 중...');
      
      final currentUser = ref.read(currentUserProvider).valueOrNull;
      if (currentUser == null) return;
      
      // 채팅 요청 거절
      await ref.read(chatControllerProvider.notifier).rejectChatRequest(
        chatId: chat.id,
        userId: currentUser.id,
      );
      
      if (mounted) Navigator.pop(context);
      _showSuccessMessage('채팅 요청을 거절했습니다');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog('오류', '채팅 요청 거절 중 오류가 발생했습니다: $e');
    }
  }
  
  // 채팅방 이름 가져오기
  Future<String> _getChatName(ChatModel chat, String currentUserId) async {
    if (chat.isGroup) {
      return chat.groupName ?? '그룹 채팅';
    }
    
    // 요청자 ID 사용 (받은 사람 입장에서는 요청자가 상대방)
    final otherUserId = chat.requesterId ?? chat.participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    
    if (otherUserId.isEmpty) return '알 수 없는 사용자';
    
    try {
      final otherUser = await ref.read(getUserProfileProvider(otherUserId).future);
      if (otherUser?.name != null && otherUser!.name!.trim().isNotEmpty) {
        return otherUser.name!;
      } else if (otherUser?.username != null && otherUser!.username!.trim().isNotEmpty) {
        return '@${otherUser.username!}';
      }
    } catch (e) {
      debugPrint('사용자 정보 가져오기 오류: $e');
    }
    
    return '알 수 없는 사용자';
  }
  
  // 채팅방 이미지 가져오기
  Future<String?> _getChatImageUrl(ChatModel chat, String currentUserId) async {
    if (chat.isGroup) {
      return chat.groupImageUrl;
    }
    
    // 요청자 ID 사용
    final otherUserId = chat.requesterId ?? chat.participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    
    if (otherUserId.isEmpty) return null;
    
    try {
      final otherUser = await ref.read(getUserProfileProvider(otherUserId).future);
      return otherUser?.profileImageUrl;
    } catch (e) {
      debugPrint('사용자 이미지 가져오기 오류: $e');
      return null;
    }
  }
  
  // 로딩 다이얼로그
  void _showLoadingDialog(String message) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(color: AppColors.textEmphasis),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 성공 메시지
  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('성공'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
  
  // 오류 다이얼로그
  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        middle: Text(
          '채팅 요청',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
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
            
            final pendingRequestsAsync = ref.watch(pendingChatRequestsProvider(currentUser.id));
            
            return pendingRequestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_2,
                          size: 60,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '채팅 요청이 없습니다',
                          style: TextStyle(
                            color: AppColors.textEmphasis,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _buildChatRequestItem(request, currentUser.id);
                  },
                );
              },
              loading: () => const Center(
                child: CupertinoActivityIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text(
                  '채팅 요청을 불러오는 중 오류가 발생했습니다: $error',
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
  
  // 채팅 요청 아이템 위젯
  Widget _buildChatRequestItem(ChatModel request, String currentUserId) {
    final requesterId = request.requesterId ?? '';
    final requesterAsync = ref.watch(getUserProfileProvider(requesterId));
    
    return requesterAsync.when(
      data: (requester) {
        if (requester == null) return const SizedBox.shrink();
        
        // 표시할 이름 결정
        final displayName = requester.name != null && requester.name!.trim().isNotEmpty
            ? requester.name!
            : '@${requester.username ?? 'unknown'}';
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.separator),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 요청자 정보
              Row(
                children: [
                  // 프로필 이미지
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.darkBackground,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.separator),
                    ),
                    child: requester.profileImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: CachedNetworkImage(
                              imageUrl: requester.profileImageUrl!,
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
                  
                  // 이름과 요청 시간
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (requester.username != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@${requester.username}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _formatTimeAgo(request.createdAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 액션 버튼들
              Row(
                children: [
                  // 수락 버튼
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () => _acceptChatRequest(request),
                      child: const Text(
                        '수락',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 거절 버튼
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.mediumGray,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () => _rejectChatRequest(request),
                      child: const Text(
                        '거절',
                        style: TextStyle(
                          color: AppColors.textEmphasis,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CupertinoActivityIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
  
  // 시간 포맷팅
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}