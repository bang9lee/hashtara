import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../../../constants/app_colors.dart';

class UserAvatar extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;
  final bool isEditable;
  final bool isLoading;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    this.size = 40.0,
    this.onTap,
    this.isEditable = false,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _imageLoadError = false;

  @override
  void initState() {
    super.initState();
    _imageLoadError = false;
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _imageLoadError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          // 기본 아바타 컨테이너
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.mediumGray,
                width: 1.0,
              ),
            ),
            child: ClipOval(
              child: _buildAvatarContent(),
            ),
          ),
          
          // 편집 가능 아이콘
          if (widget.isEditable)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.white,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  CupertinoIcons.camera_fill,
                  size: widget.size * 0.2,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          
          // 로딩 인디케이터
          if (widget.isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(77),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CupertinoActivityIndicator(
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    // 이미지 URL이 없거나 로드 에러가 발생한 경우
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty || _imageLoadError) {
      return Icon(
        CupertinoIcons.person_fill,
        size: widget.size * 0.5,
        color: CupertinoColors.systemGrey,
      );
    }

    // 🔥 웹과 모바일 모두에서 Image.network 사용
    return Image.network(
      widget.imageUrl!,
      fit: BoxFit.cover,
      width: widget.size,
      height: widget.size,
      // 🔥 웹에서 CORS 문제 해결을 위한 헤더 추가
      headers: kIsWeb ? {
        'Accept': 'image/*',
      } : null,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('🔥 이미지 로드 실패: $error');
        debugPrint('URL: ${widget.imageUrl}');
        
        // 에러 발생 시 상태 업데이트
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_imageLoadError) {
            setState(() {
              _imageLoadError = true;
            });
          }
        });
        
        return Icon(
          CupertinoIcons.person_fill,
          size: widget.size * 0.5,
          color: CupertinoColors.systemGrey,
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        
        return Center(
          child: CupertinoActivityIndicator(
            radius: widget.size * 0.3,
          ),
        );
      },
    );
  }
}