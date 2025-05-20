import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
import '../../../models/hashtag_channel_model.dart';

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
  void _addHashtag() async {
    final hashtag = _hashtagController.text.trim();
    
    if (hashtag.isNotEmpty) {
      // 불필요한 문자열 보간 수정
      final formattedHashtag = hashtag.startsWith('#') ? hashtag : '#$hashtag';
      
      if (!_selectedHashtags.contains(formattedHashtag)) {
        setState(() {
          _selectedHashtags.add(formattedHashtag);
          _hashtagController.clear();
        });
        
        // 해시태그 채널 자동 생성
        await _createHashtagChannel(formattedHashtag);
      }
    }
  }
  
  // 해시태그 채널 생성 메서드
  Future<void> _createHashtagChannel(String hashtag) async {
    try {
      final channelName = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
      
      // 새 채널 모델 생성
      final newChannel = HashtagChannelModel(
        id: '', 
        name: channelName,
        description: '$channelName에 대한 게시물 모음',
        createdAt: DateTime.now(),
      );
      
      // 채널 저장
      await ref.read(hashtagChannelControllerProvider.notifier).createChannel(newChannel);
      debugPrint('해시태그 채널 생성 성공: $channelName');
    } catch (e) {
      debugPrint('해시태그 채널 생성 실패: $e');
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
      // 캡션은 해시태그 없이 그대로 사용
      String caption = _captionController.text.trim();
      
      debugPrint('게시물 작성 시도: 작성자 ${currentUser.id}, 내용: $caption, 해시태그: ${_selectedHashtags.join(' ')}');
      
      // 게시물 생성 전에 모든 해시태그에 대한 채널 생성 시도
      for (final hashtag in _selectedHashtags) {
        await _createHashtagChannel(hashtag);
      }
      
      final postId = await ref.read(postControllerProvider.notifier).createPost(
        userId: currentUser.id,
        caption: caption.isEmpty ? null : caption,
        imageFiles: _selectedImages.isEmpty ? null : _selectedImages,
        location: _locationController.text.isEmpty ? null : _locationController.text.trim(),
        hashtags: _selectedHashtags.isEmpty ? null : _selectedHashtags,
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
    final screenWidth = MediaQuery.of(context).size.width;
    
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사용자 정보
                  currentUser.when(
                    data: (user) => user != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(40),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
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
                            ),
                          )
                        : const SizedBox(),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: CupertinoActivityIndicator(),
                    ),
                    error: (_, __) => const SizedBox(),
                  ),
                  
                  // 이미지 선택 영역 - 정사각형 디자인
                  if (_selectedImages.isNotEmpty)
                    Container(
                      height: screenWidth - 32,  // 정사각형 크기 (화면 너비 - 좌우 패딩)
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
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
                                      top: 12,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withAlpha(150),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.clear,
                                            size: 20,
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
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _selectedImages.length,
                                    (index) => Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withAlpha(180),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    // 이미지 없을 때 정사각형 업로드 영역 (세련된 디자인)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        height: screenWidth - 32, // 정사각형 크기
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.separator,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.darkBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryPurple,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.photo,
                                size: 40,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '사진 추가하기',
                              style: TextStyle(
                                color: AppColors.primaryPurple,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
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
                  
                  // 미디어 버튼들 - 세련된 디자인
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryPurple.withAlpha(200),
                                AppColors.primaryPurple.withAlpha(100),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withAlpha(40),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CupertinoButton(
                            onPressed: _pickImages,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.photo,
                                color: AppColors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '갤러리',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.secondaryBlue.withAlpha(200),
                                AppColors.secondaryBlue.withAlpha(100),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondaryBlue.withAlpha(40),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CupertinoButton(
                            onPressed: _takePicture,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.camera,
                                color: AppColors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '카메라',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 캡션 입력 - 새로운 디자인
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              CupertinoIcons.text_bubble,
                              color: AppColors.primaryPurple,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '내용',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: _captionController,
                          placeholder: '무슨 생각을 하고 계신가요?',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                          ),
                          placeholderStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                          maxLines: 4,
                          minLines: 3,
                          keyboardType: TextInputType.multiline,
                          decoration: BoxDecoration(
                            color: AppColors.darkBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.separator,
                              width: 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 위치 입력 - 새로운 디자인
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              CupertinoIcons.location,
                              color: AppColors.primaryPurple,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '위치',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: _locationController,
                          placeholder: '위치 추가 (예: 서울특별시)',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                          ),
                          placeholderStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.separator,
                              width: 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 해시태그 입력 - 새로운 디자인
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              CupertinoIcons.number,
                              color: AppColors.primaryPurple,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '해시태그',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: _hashtagController,
                                placeholder: '해시태그 추가 (예: 운동)',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 15,
                                ),
                                placeholderStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.darkBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.separator,
                                    width: 1.0,
                                  ),
                                ),
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Text(
                                    '#',
                                    style: TextStyle(
                                      color: AppColors.primaryPurple,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                onSubmitted: (_) => _addHashtag(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _addHashtag,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.add,
                                  color: AppColors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedHashtags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 12.0,
                            children: _selectedHashtags.map((hashtag) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                  vertical: 8.0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withAlpha(150),
                                  borderRadius: BorderRadius.circular(16.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryPurple.withAlpha(40),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
                                    const SizedBox(width: 6),
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
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CupertinoActivityIndicator(
                          radius: 14,
                        ),
                      ),
                    ),
                  
                  // 에러 메시지
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.systemRed.withAlpha(100),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: CupertinoColors.systemRed,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: CupertinoColors.systemRed,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // 게시 버튼 - 새로운 디자인
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryPurple,
                          AppColors.secondaryBlue,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withAlpha(60),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      onPressed: _isLoading ? null : _createPost,
                      padding: EdgeInsets.zero,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              CupertinoIcons.paperplane_fill,
                              color: AppColors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '게시하기',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
      ),
    );
  }
}

class Colors {
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
}