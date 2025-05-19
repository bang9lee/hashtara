import 'package:flutter/cupertino.dart';
import '../../../constants/app_colors.dart';

class UserAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // 기본 아바타 컨테이너
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              shape: BoxShape.circle,
              image: imageUrl != null && imageUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        // 이미지 로드 오류 처리
                        debugPrint('이미지 로드 오류: $exception');
                      },
                    )
                  : null,
              border: Border.all(
                color: AppColors.mediumGray,
                width: 1.0,
              ),
            ),
            child: imageUrl == null || imageUrl!.isEmpty
                ? Icon(
                    CupertinoIcons.person_fill,
                    size: size * 0.5,
                    color: CupertinoColors.systemGrey,
                  )
                : null,
          ),
          
          // 편집 가능 아이콘 (조건부 표시)
          if (isEditable)
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
                  size: size * 0.2,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          
          // 로딩 인디케이터 (조건부 표시)
          if (isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(77), // withOpacity 대신 withAlpha 사용
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
}