import 'package:flutter/cupertino.dart';
import '../../../constants/app_colors.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const LoadingIndicator({
    Key? key,
    this.size = 24.0,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoActivityIndicator(
        radius: size / 2,
        color: color ?? AppColors.primaryPurple,
      ),
    );
  }
}