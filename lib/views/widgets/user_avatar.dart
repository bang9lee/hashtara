import 'package:flutter/cupertino.dart';
import '../../../constants/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    this.size = 40.0,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          shape: BoxShape.circle,
          image: imageUrl != null && imageUrl!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
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
    );
  }
}