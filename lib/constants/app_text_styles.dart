import 'package:flutter/cupertino.dart';
import 'app_colors.dart';

class AppTextStyles {
  // 헤더 스타일
  static const TextStyle largeTitle = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정 (pubspec.yaml에 선언한 family 이름과 일치)
    fontSize: 34.0,
    fontWeight: FontWeight.bold,
    color: AppColors.darkBackground,
    letterSpacing: 0.37,
  );
  
  static const TextStyle title1 = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 28.0,
    fontWeight: FontWeight.bold,
    color: AppColors.darkBackground,
    letterSpacing: 0.36,
  );
  
  static const TextStyle title2 = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 22.0,
    fontWeight: FontWeight.bold,
    color: AppColors.darkBackground,
    letterSpacing: 0.35,
  );
  
  static const TextStyle title3 = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    color: AppColors.darkBackground,
    letterSpacing: 0.38,
  );
  
  // 본문 스타일
  static const TextStyle body = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 17.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textEmphasis,
    letterSpacing: -0.41,
  );
  
  static const TextStyle bodyBold = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 17.0,
    fontWeight: FontWeight.w600,
    color: AppColors.darkBackground,
    letterSpacing: -0.41,
  );
  
  static const TextStyle callout = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textEmphasis,
    letterSpacing: -0.32,
  );
  
  static const TextStyle subheadline = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 15.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textEmphasis,
    letterSpacing: -0.24,
  );
  
  static const TextStyle footnote = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 13.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textEmphasis,
    letterSpacing: -0.08,
  );
  
  static const TextStyle caption1 = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textEmphasis,
    letterSpacing: 0.0,
  );
  
  static const TextStyle caption2 = TextStyle(
    fontFamily: 'SFPro',  // 'SFPro'로 수정
    fontSize: 11.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textEmphasis,
    letterSpacing: 0.06,
  );
}