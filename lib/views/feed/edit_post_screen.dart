import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/feed_provider.dart';
import '../../../models/post_model.dart';

class EditPostScreen extends ConsumerStatefulWidget {
  final PostModel post;

  const EditPostScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  List<String> _existingImageUrls = [];
  final List<String> _removedImageUrls = [];
  final List<File> _newImageFiles = [];
  final List<String> _selectedHashtags = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 기존 데이터 로드
    _captionController.text = widget.post.caption ?? '';
    _locationController.text = widget.post.location ?? '';
    _existingImageUrls = List<String>.from(widget.post.imageUrls ?? []);
    
    // 해시태그 로드
    if (widget.post.hashtags != null) {
      _selectedHashtags.addAll(widget.post.hashtags!);
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
      // 불필요한 문자열 보간 수정
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
  
  // 기존 이미지 제거
  void _removeExistingImage(int index) {
    setState(() {
      final removedUrl = _existingImageUrls.removeAt(index);
      _removedImageUrls.add(removedUrl);
    });
  }
  
  // 새 이미지 제거
  void _removeNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
    });
  }
  
  // 이미지 선택
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImageFiles.addAll(pickedFiles.map((pickedFile) => File(pickedFile.path)));
      });
    }
  }
  
  // 사진 촬영
  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    
    if (pickedFile != null) {
      setState(() {
        _newImageFiles.add(File(pickedFile.path));
      });
    }
  }
  
  // 게시물 업데이트 
  Future<void> _updatePost() async {
    if (_captionController.text.trim().isEmpty && 
        _existingImageUrls.isEmpty && 
        _newImageFiles.isEmpty &&
        _selectedHashtags.isEmpty) {
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
      // 수정된 게시물 데이터
      await ref.read(postControllerProvider.notifier).updatePost(
        postId: widget.post.id,
        caption: _captionController.text.trim(),
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        imageUrls: _existingImageUrls,
        newImageFiles: _newImageFiles.isEmpty ? null : _newImageFiles,
        hashtags: _selectedHashtags.isEmpty ? null : _selectedHashtags,
      );
      
      // 성공 시 이전 화면으로 돌아가기
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '게시물 수정에 실패했습니다: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // 게시물 삭제 확인
  void _confirmDeletePost() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('이 게시물을 정말 삭제하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
  
  // 게시물 삭제
  Future<void> _deletePost() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await ref.read(postControllerProvider.notifier).deletePost(widget.post.id);
      
      // 성공 시 이전 화면으로 돌아가기
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '게시물 삭제에 실패했습니다: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(),
        middle: const Text(
          '게시물 수정',
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
          onPressed: _isLoading ? null : _updatePost,
          child: const Text(
            '저장',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기존 이미지 목록
              if (_existingImageUrls.isNotEmpty) ...[
                const Text(
                  '현재 이미지',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImageUrls.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            margin: const EdgeInsets.only(right: 8.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(_existingImageUrls[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(index),
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
                const SizedBox(height: 16),
              ],
              
              // 신규 이미지 목록
              if (_newImageFiles.isNotEmpty) ...[
                const Text(
                  '새 이미지',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _newImageFiles.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            margin: const EdgeInsets.only(right: 8.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              image: DecorationImage(
                                image: FileImage(_newImageFiles[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => _removeNewImage(index),
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
                const SizedBox(height: 16),
              ],
              
              // 미디어 버튼들
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12.0),
                      onPressed: _pickImages,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.photo,
                            color: AppColors.primaryPurple,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '갤러리',
                            style: TextStyle(color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12.0),
                      onPressed: _takePicture,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.camera,
                            color: AppColors.primaryPurple,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '카메라',
                            style: TextStyle(color: AppColors.white),
                          ),
                        ],
                      ),
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
              
              const SizedBox(height: 24),
              
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
                          CupertinoIcons.number,
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
              
              const SizedBox(height: 16),
              
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
              
              // 저장 버튼
              if (!_isLoading)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(12.0),
                  onPressed: _updatePost,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_circle,
                        color: AppColors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '저장하기',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // 삭제 버튼
              if (!_isLoading)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  color: CupertinoColors.destructiveRed,
                  borderRadius: BorderRadius.circular(12.0),
                  onPressed: _confirmDeletePost,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.delete,
                        color: AppColors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '게시물 삭제',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}