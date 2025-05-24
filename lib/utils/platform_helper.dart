import 'package:flutter/foundation.dart';

class PlatformHelper {
  // 현재 플랫폼이 웹인지 확인
  static bool get isWeb => kIsWeb;
  
  // 모바일인지 확인
  static bool get isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || 
                                          defaultTargetPlatform == TargetPlatform.android);
  
  // iOS인지 확인
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  
  // Android인지 확인
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  
  // 데스크톱인지 확인
  static bool get isDesktop => !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
                                           defaultTargetPlatform == TargetPlatform.linux ||
                                           defaultTargetPlatform == TargetPlatform.macOS);
}

// 사용 예시:
// if (PlatformHelper.isWeb) {
//   // 웹 전용 코드
// } else {
//   // 모바일 전용 코드
// }