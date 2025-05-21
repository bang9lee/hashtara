import 'package:flutter/cupertino.dart';

class AppColors {
  // 은하수 느낌의 그라데이션 색상
  static const Color gradientStart = Color(0xFF2E0F5A);  // 짙은 보라색
  static const Color gradientMid = Color(0xFF3A1B7F);    // 중간 보라색
  static const Color gradientEnd = Color(0xFF5B30AB);    // 밝은 보라색
  
  // 로고와 별 색상용 그라데이션
  static const Color logoStart = Color(0xFF9C6FFF);     // 밝은 보라색
  static const Color logoEnd = Color(0xFF6248FF);       // 진한 보라색
  
  // 앱 메인 테마 색상 (보라색 -> 로고에 맞춤)
  static const Color primaryPurple = Color(0xFF7B5FFF);
  
  // 보조 색상 (보다 진한 보라색)
  static const Color secondaryBlue = Color(0xFF6248FF);
  
  // 배경 색상 (은하수 느낌의 짙은 검정색)
  static const Color darkBackground = Color(0xFF0A0E1A);  // 짙은 남색 배경색
  
  // 카드 배경 색상 (짙은 남색보다 조금 밝은 색)
  static const Color cardBackground = Color(0xFF192040);
  
  // 흰색/텍스트 기본
  static const Color white = Color(0xFFFFFFFF);
  
  // 강조 텍스트
  static const Color textEmphasis = Color(0xFFD1D1D6);
  
  // 보조 텍스트
  static const Color textSecondary = Color(0xFF8E8E93);
  
  // 버튼 색상
  static const Color buttonAccent = Color(0xFF7B5FFF);  // primaryPurple과 동일
  
  // 추가 색상
  static const Color lightGray = Color(0xFF3A3A3C);  // 다크모드용 라이트 그레이
  static const Color mediumGray = Color(0xFF2C2C2E);  // 다크모드용 미디엄 그레이
  static const Color separator = Color(0xFF38383A);  // 다크모드용 구분선
  
  // iOS 스타일 시스템 색상
  static const Color iosPrimary = CupertinoColors.systemBlue;
  static const Color iosSuccess = CupertinoColors.systemGreen;
  static const Color iosWarning = CupertinoColors.systemOrange;
  static const Color iosError = CupertinoColors.systemRed;
  
  // 알림 액센트 색상 추가 (기존 iOS 컬러를 활용하고 별도 이름을 부여)
  static const Color accentRed = CupertinoColors.systemRed;     // 알림, 좋아요 등
  static const Color accentBlue = CupertinoColors.systemBlue;   // 댓글, 정보
  static const Color accentGreen = CupertinoColors.systemGreen; // 성공, 응답
  static const Color accentYellow = CupertinoColors.systemYellow; // 경고, 메시지
  
  // 로고 그라데이션
  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [logoStart, logoEnd],
  );
  
  // 은하수 배경 그라데이션
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientMid, gradientEnd],
    stops: [0.0, 0.5, 1.0],
  );
  
  // 주요 그라데이션 (기본 앱 테마)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, secondaryBlue],
  );
}