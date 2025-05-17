import 'package:flutter/cupertino.dart';
import '../../../constants/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final IconData? icon;
  final bool isGradient;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.height = 50.0,
    this.icon,
    this.isGradient = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isGradient) {
      return SizedBox(
        height: height,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: isLoading ? null : onPressed,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Center(
              child: isLoading
                ? const CupertinoActivityIndicator(
                    color: CupertinoColors.white,
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: textColor ?? CupertinoColors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: textColor ?? CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        height: height,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: isLoading ? null : onPressed,
          color: backgroundColor ?? AppColors.primaryPurple,
          disabledColor: CupertinoColors.systemGrey3,
          borderRadius: BorderRadius.circular(12.0),
          child: isLoading
              ? const CupertinoActivityIndicator(
                  color: CupertinoColors.white,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: textColor ?? CupertinoColors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        color: textColor ?? CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }
  }
}