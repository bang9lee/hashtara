import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String? imageUrl;
  final bool isGroup;

  const ChatDetailScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.imageUrl,
    this.isGroup = false,
  }) : super(key: key);

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isSending = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 채팅방 입장시 메시지 읽음 상태 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 메시지 읽음 표시
  void _markMessagesAsRead() {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser != null) {
      ref.read(chatControllerProvider.notifier).markMessagesAsRead(
        chatId: widget.chatId,
        userId: currentUser.id,
      );
    }
  }
  
  // 이미지 선택
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty && mounted) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((pickedFile) => File(pickedFile.path)));
      });
    }
  }
  
  // 사진 촬영
  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    
    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }
  
  // 메시지 전송
  Future<void> _sendMessage() async {
    // Store all variables including context before async operations
    final text = _messageController.text.trim();
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    
    if (currentUser == null) {
      return;
    }
    
    // 텍스트와 이미지 모두 없으면 전송하지 않음
    if (text.isEmpty && _selectedImages.isEmpty) {
      return;
    }
    
    // Set loading state before async operation
    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }
    
    try {
      // Async operation
      await ref.read(chatControllerProvider.notifier).sendMessage(
        chatId: widget.chatId,
        senderId: currentUser.id,
        text: text.isEmpty ? null : text,
        imageFiles: _selectedImages.isEmpty ? null : _selectedImages,
      );
      
      // Check if widget is still mounted before setState
      if (!mounted) return;
      
      // Update UI after successful send
      _messageController.clear();
      setState(() {
        _selectedImages.clear();
        _isSending = false;
      });
      
      // Scroll to top (latest message)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Check if widget is still mounted before setState
      if (!mounted) return;
      
      // Update loading state
      setState(() {
        _isSending = false;
      });
      
      // Show error dialog - properly using context only after mounted check
      _showErrorDialog('메시지 전송 실패', '메시지를 전송하는 중 오류가 발생했습니다: $e');
    }
  }

  // Show an error dialog safely
  void _showErrorDialog(String title, String message) {
    // Only use context after checking mounted
    if (!mounted) return;
    
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  // Helper method to safely leave chat
  Future<void> _leaveChat(String userId) async {
    try {
      // Async operation
      await ref.read(chatControllerProvider.notifier).leaveChat(
        chatId: widget.chatId,
        userId: userId,
      );
      
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      // Now it's safe to use context after the mounted check
      Navigator.pop(context);
    } catch (e) {
      // Check if widget is still mounted
      if (!mounted) return;
      
      // Show error dialog - properly using context only after mounted check
      _showErrorDialog('채팅방 나가기 실패', '채팅방을 나가는 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 로그인한 사용자
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    
    // 채팅방 메시지 목록
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(
          bottom: BorderSide(color: AppColors.separator),
        ),
        middle: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.imageUrl != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(widget.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.chatName,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(
            CupertinoIcons.back,
            color: AppColors.white,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            // 채팅방 옵션 표시
            showCupertinoModalPopup(
              context: context,
              builder: (context) => CupertinoActionSheet(
                title: const Text('채팅방 옵션'),
                actions: [
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(context);
                      // 프로필 보기 (구현 필요)
                    },
                    child: const Text('프로필 보기'),
                  ),
                  CupertinoActionSheetAction(
                    isDestructiveAction: true,
                    onPressed: () {
                      // First, close the action sheet
                      Navigator.pop(context);
                      
                      if (currentUser != null) {
                        // Call the helper method which safely handles context
                        _leaveChat(currentUser.id);
                      }
                    },
                    child: const Text('채팅방 나가기'),
                  ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ),
            );
          },
          child: const Icon(
            CupertinoIcons.ellipsis,
            color: AppColors.white,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 메시지 목록
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        '아직 메시지가 없습니다',
                        style: TextStyle(color: AppColors.textEmphasis),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // 최신 메시지가 아래쪽에 표시
                    padding: const EdgeInsets.all(16.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = currentUser?.id == message.senderId;
                      
                      // 이전 메시지와 시간 비교 (날짜 구분선 표시용)
                      final showDateSeparator = index == messages.length - 1 || 
                        !_isSameDay(messages[index].createdAt, messages[index + 1].createdAt);
                      
                      return Column(
                        children: [
                          if (showDateSeparator)
                            _buildDateSeparator(message.createdAt),
                          _buildMessageItem(
                            context,
                            message,
                            isMe,
                            ref,
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    '메시지를 불러오는 중 오류가 발생했습니다: $error',
                    style: const TextStyle(color: AppColors.textEmphasis),
                  ),
                ),
              ),
            ),
            
            // 선택된 이미지 미리보기
            if (_selectedImages.isNotEmpty)
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                color: AppColors.cardBackground,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 8.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            image: DecorationImage(
                              image: FileImage(_selectedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4.0),
                              decoration: const BoxDecoration(
                                color: AppColors.lightGray,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.clear,
                                size: 16,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            
            // 메시지 입력 영역
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.cardBackground,
              child: Row(
                children: [
                  // 이미지 버튼
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickImages,
                    child: const Icon(
                      CupertinoIcons.photo,
                      color: AppColors.primaryPurple,
                      size: 28,
                    ),
                  ),
                  
                  // 카메라 버튼
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _takePicture,
                    child: const Icon(
                      CupertinoIcons.camera,
                      color: AppColors.primaryPurple,
                      size: 28,
                    ),
                  ),
                  
                  // 메시지 입력 필드
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkBackground,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: CupertinoTextField(
                        controller: _messageController,
                        placeholder: '메시지 입력...',
                        decoration: const BoxDecoration(
                          color: AppColors.darkBackground,
                          border: null,
                        ),
                        style: const TextStyle(color: AppColors.white),
                        placeholderStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 5,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  
                  // 전송 버튼
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isSending ? null : _sendMessage,
                    child: _isSending
                        ? const CupertinoActivityIndicator()
                        : const Icon(
                            CupertinoIcons.paperplane_fill,
                            color: AppColors.primaryPurple,
                            size: 28,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 날짜 구분선
  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              color: AppColors.separator,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: AppColors.separator,
            ),
          ),
        ],
      ),
    );
  }
  
  // 메시지 아이템
  Widget _buildMessageItem(
    BuildContext context,
    dynamic message,
    bool isMe,
    WidgetRef ref,
  ) {
    final messageText = message.text;
    final messageImages = message.imageUrls;
    
    // 발신자 정보 (내 메시지가 아닌 경우)
    Widget senderInfo = const SizedBox.shrink();
    if (!isMe) {
      final senderAsync = ref.watch(getUserProfileProvider(message.senderId));
      senderInfo = senderAsync.when(
        data: (sender) {
          return Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
            child: Text(
              sender?.name ?? sender?.username ?? '알 수 없는 사용자',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 발신자 정보 (내 메시지가 아닌 경우만)
          if (!isMe) senderInfo,
          
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 메시지 시간 (내 메시지인 경우 왼쪽에 표시)
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              
              // 메시지 내용
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 이미지가 있는 경우
                    if (messageImages != null && messageImages.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                          maxHeight: 200,
                        ),
                        margin: const EdgeInsets.only(bottom: 4.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.0),
                          color: isMe ? AppColors.primaryPurple : AppColors.cardBackground,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: CachedNetworkImage(
                            imageUrl: messageImages[0],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CupertinoActivityIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    // 텍스트가 있는 경우
                    if (messageText != null && messageText.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primaryPurple : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Text(
                          messageText,
                          style: TextStyle(
                            color: isMe ? AppColors.white : AppColors.textEmphasis,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 메시지 시간 (내 메시지가 아닌 경우 오른쪽에 표시)
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  // 날짜가 같은지 확인
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }
  
  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    
    if (_isSameDay(date, now)) {
      return '오늘';
    } else if (_isSameDay(date, yesterday)) {
      return '어제';
    } else {
      return '${date.year}.${date.month}.${date.day}';
    }
  }
  
  // 시간 포맷팅
  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? '오후' : '오전';
    
    return '$amPm ${hour == 0 ? 12 : hour}:$minute';
  }
}