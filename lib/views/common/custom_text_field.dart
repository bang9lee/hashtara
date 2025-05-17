import 'package:flutter/cupertino.dart';
import '../../../constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool isPassword;
  final TextInputType keyboardType;
  final Widget? prefix;
  final int maxLines;
  final bool enabled;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool isDarkMode;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.placeholder,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.isDarkMode = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: isPassword,
      keyboardType: keyboardType,
      prefix: prefix != null
          ? Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: prefix,
            )
          : null,
      prefixMode: OverlayVisibilityMode.always,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.cardBackground : CupertinoColors.white,
        border: Border.all(
          color: isDarkMode ? AppColors.separator : AppColors.mediumGray,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(12.0),
      ),
      style: TextStyle(
        fontSize: 16.0,
        color: isDarkMode ? AppColors.white : CupertinoColors.black,
      ),
      placeholderStyle: TextStyle(
        fontSize: 16.0,
        color: isDarkMode ? AppColors.textSecondary : CupertinoColors.systemGrey,
      ),
    );
  }
}