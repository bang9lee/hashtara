import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
import '../common/custom_button.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? channelId; // 특정 채널에서 게시물 작성 시 채널 ID
  
  const CreatePostScreen({
    Key? key,
    this.channelId,
  }) : super(key: key);

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _hashtagController = TextEditingController();
  
  List<File> _selectedImages = [];
  final List<String> _selectedHashtags = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccessful = false; // 게시물 작성 성공 여부
  
  @override
  void initState() {
    super.initState();
    // 특정 채널에서 게시물 작성 시 해당 해시태그 자동 추가
    if (widget.channelId != null) {
      _loadChannelInfo();
    }
  }
  
  // 채널 정보 로드
  void _loadChannelInfo() async {
    final channelAsync = await ref.read(hashtagChannelProvider(widget.channelId!).future);
    if (channelAsync != null && mounted) {
      setState(() {
        _selectedHashtags.add('#${channelAsync.name}');
      });
    }
  }
  
  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }
  
  // 해시태그 추가
  void _addHashtag() {
    final hashtag = _hashtagController.text.trim();
    
    if (hashtag.isNotEmpty) {
      final formattedHashtag = hashtag.startsWith('#') ? hashtag : '#$hashtag';
      
      if (!_selectedHashtags.contains(formattedHashtag)) {
        setState(() {
          _selectedHashtags.add(formattedHashtag);
          _hashtagController.clear();
        });
      }
    }
  }
  
  // 해시태그 제거
  void _removeHashtag(String hashtag) {
    setState(() {
      _selectedHashtags.remove(hashtag);
    });
  }
  
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages = pickedFiles
            .map((pickedFile) => File(pickedFile.path))
            .toList();
      });
    }
  }
  
  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }
  
  Future<void> _createPost() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      setState(() {
        _errorMessage = '로그인이 필요합니다.';
      });
      return;
    }
    
    if (_captionController.text.isEmpty && _selectedImages.isEmpty && _selectedHashtags.isEmpty) {
      setState(() {
        _errorMessage = '텍스트, 이미지 또는 해시태그를 입력해주세요.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 캡션에 해시태그 추가
      String caption = _captionController.text.trim();
      if (_selectedHashtags.isNotEmpty) {
        caption = '$caption ${_selectedHashtags.join(' ')}';
      }
      
      debugPrint('게시물 작성 시도: 작성자 ${currentUser.id}, 내용: $caption');
      
      final postId = await ref.read(postControllerProvider.notifier).createPost(
        userId: currentUser.id,
        caption: caption.isEmpty ? null : caption,
        imageFiles: _selectedImages.isEmpty ? null : _selectedImages,
        location: _locationController.text.isEmpty ? null : _locationController.text.trim(),
      );
      
      debugPrint('게시물 작성 결과: $postId');
      
      if (postId != null) {
        // 성공 시 상태 업데이트
        if (mounted) {
          setState(() {
            _isSuccessful = true;
            _isLoading = false;
          });
          
          // 잠시 후 화면 닫기
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = '게시물 작성에 실패했습니다. 다시 시도해주세요.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('게시물 작성 오류: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '게시물 작성에 실패했습니다: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(),
        middle: const Text(
          '게시물 작성',
          style: TextStyle(color: AppColors.white),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '취소',
            style: TextStyle(color: AppColors.white),
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading || _isSuccessful ? null : _createPost,
          child: const Text(
            '공유',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: _isSuccessful 
        // 성공 화면
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.check_mark_circled_solid, 
                  color: AppColors.primaryPurple,
                  size: 60,
                ),
                SizedBox(height: 16),
                Text(
                  '게시물이 성공적으로 업로드되었습니다!',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        // 게시물 작성 화면
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 사용자 정보
                currentUser.when(
                  data: (user) => user != null
                      ? Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cardBackground,
                                image: user.profileImageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(user.profileImageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                border: Border.all(
                                  color: AppColors.separator,
                                  width: 1.0,
                                ),
                              ),
                              child: user.profileImageUrl == null
                                  ? const Icon(
                                      CupertinoIcons.person_fill,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              user.name ?? user.username ?? 'User',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 17.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(),
                  loading: () => const CupertinoActivityIndicator(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 24),
                
                // 이미지 선택 영역
                if (_selectedImages.isNotEmpty)
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.separator,
                      ),
                    ),
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  _selectedImages[index],
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.black.withAlpha(150),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.clear,
                                        size: 18,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (_selectedImages.length > 1)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _selectedImages.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: CupertinoColors.white.withAlpha(150),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.separator,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.photo_on_rectangle,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '사진 추가하기',
                            style: TextStyle(
                              color: AppColors.textEmphasis,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '탭하여 갤러리에서 선택',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                
                // 미디어 버튼들
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: '갤러리',
                        onPressed: _pickImages,
                        icon: CupertinoIcons.photo,
                        backgroundColor: AppColors.cardBackground,
                        textColor: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: '카메라',
                        onPressed: _takePicture,
                        icon: CupertinoIcons.camera,
                        backgroundColor: AppColors.cardBackground,
                        textColor: AppColors.white,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // 캡션 입력
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '내용',
                        style: TextStyle(
                          color: AppColors.textEmphasis,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _captionController,
                        placeholder: '무슨 생각을 하고 계신가요?',
                        style: const TextStyle(color: AppColors.white),
                        placeholderStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        decoration: const BoxDecoration(
                          color: AppColors.cardBackground,
                          border: null,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 위치 입력
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location,
                        color: AppColors.textEmphasis,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _locationController,
                          placeholder: '위치 추가',
                          style: const TextStyle(color: AppColors.white),
                          placeholderStyle: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.cardBackground,
                            border: null,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 해시태그 입력
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '해시태그',
                        style: TextStyle(
                          color: AppColors.textEmphasis,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.number, // hashtag 대신 number 아이콘 사용
                            color: AppColors.textEmphasis,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoTextField(
                              controller: _hashtagController,
                              placeholder: '해시태그 추가 (예: 운동)',
                              style: const TextStyle(color: AppColors.white),
                              placeholderStyle: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.cardBackground,
                                border: null,
                              ),
                              padding: EdgeInsets.zero,
                              onSubmitted: (_) => _addHashtag(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _addHashtag,
                            child: const Icon(
                              CupertinoIcons.add_circled,
                              color: AppColors.primaryPurple,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedHashtags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _selectedHashtags.map((hashtag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 6.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple,
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    hashtag,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _removeHashtag(hashtag),
                                    child: const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      color: AppColors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 로딩 인디케이터
                if (_isLoading)
                  const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                
                // 에러 메시지
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // 게시 버튼
                if (!_isLoading)
                  CustomButton(
                    text: '게시하기',
                    onPressed: _createPost,
                    isGradient: true,
                    icon: CupertinoIcons.paperplane_fill,
                  ),
              ],
            ),
          ),
      ),
    );
  }
}