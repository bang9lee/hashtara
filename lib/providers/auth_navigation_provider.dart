// auth_navigation_provider.dart 파일

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 인증 화면 상태 열거형
enum AuthScreen {
  login,
  signup,
  mainTab,
  setupProfile
}

// 인증 네비게이션 상태 클래스
class AuthNavigationState {
  final AuthScreen currentScreen;
  final bool isNavigating;
  final String? userId;

  AuthNavigationState({
    required this.currentScreen, 
    this.isNavigating = false,
    this.userId,
  });

  AuthNavigationState copyWith({
    AuthScreen? currentScreen,
    bool? isNavigating,
    String? userId,
  }) {
    return AuthNavigationState(
      currentScreen: currentScreen ?? this.currentScreen,
      isNavigating: isNavigating ?? this.isNavigating,
      userId: userId ?? this.userId,
    );
  }
}

// 인증 네비게이션 노티파이어
class AuthNavigationNotifier extends StateNotifier<AuthNavigationState> {
  AuthNavigationNotifier() : super(AuthNavigationState(currentScreen: AuthScreen.login));

  // 로그인 성공 시 호출
  void navigateToMainTab() {
    if (state.isNavigating) return;
    
    state = state.copyWith(
      currentScreen: AuthScreen.mainTab,
      isNavigating: true,
    );
  }

  // 회원가입 화면으로 이동
  void navigateToSignup() {
    if (state.isNavigating) return;
    
    state = state.copyWith(
      currentScreen: AuthScreen.signup,
      isNavigating: false,
    );
  }

  // 프로필 설정 화면으로 이동
  void navigateToSetupProfile(String userId) {
    if (state.isNavigating) return;
    
    state = state.copyWith(
      currentScreen: AuthScreen.setupProfile,
      isNavigating: true,
      userId: userId,
    );
  }

  // 네비게이션 완료 후 호출
  void completeNavigation() {
    state = state.copyWith(isNavigating: false);
  }
}

// 인증 네비게이션 프로바이더
final authNavigationProvider = StateNotifierProvider<AuthNavigationNotifier, AuthNavigationState>((ref) {
  return AuthNavigationNotifier();
});