// auth_provider.dart 파일

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../views/profile/setup_profile_screen.dart';

// 인증 저장소 프로바이더
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// 인증 상태 프로바이더 (로그인 여부)
final authStateProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  debugPrint('인증 상태 프로바이더 초기화됨');
  return repository.authStateChanges;
});

// 현재 로그인한 사용자 프로바이더
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  
  debugPrint('현재 사용자 프로바이더 실행됨');
  
  return authState.when(
    data: (user) {
      if (user != null) {
        debugPrint('사용자 프로필 로드 시도: ${user.uid}');
        return repository.getUserProfile(user.uid);
      }
      debugPrint('로그인된 사용자 없음');
      return null;
    },
    loading: () {
      debugPrint('authState 로딩 중...');
      return null;
    },
    error: (error, stack) {
      debugPrint('authState 에러: $error');
      return null;
    },
  );
});

// 사용자 프로필 조회 프로바이더 - 전역으로 정의하여 어디서나 접근 가능하게 함
final getUserProfileProvider = FutureProvider.family<UserModel?, String>((ref, userId) {
  final repository = ref.watch(authRepositoryProvider);
  debugPrint('사용자 프로필 조회 프로바이더 실행: $userId');
  return repository.getUserProfile(userId);
});

// 프로필 설정 완료 여부 확인 프로바이더
final isProfileCompleteProvider = FutureProvider.family<bool, String>((ref, userId) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.isProfileComplete(userId);
});

// 로그인 상태 관리 프로바이더
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;
  
  AuthController(this._repository) : super(const AsyncValue.data(null));
  
  // 로그인
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('로그인 시도: $email');
      await _repository.signInWithEmailAndPassword(email, password);
      state = const AsyncValue.data(null);
      debugPrint('로그인 성공');
    } catch (e, stack) {
      debugPrint('로그인 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 구글 로그인
  Future<void> signInWithGoogle(BuildContext context) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('구글 로그인 시도');
      final result = await _repository.signInWithGoogle();
      state = const AsyncValue.data(null);
      debugPrint('구글 로그인 성공');
      
      // 신규 사용자인 경우 프로필 설정 화면으로 이동
      if (result.additionalUserInfo?.isNewUser == true && result.user != null) {
        debugPrint('신규 사용자, 프로필 설정 화면으로 이동');
        
        // BuildContext 사용 전 mounted 체크 (context가 NavigatorState의 context가 아니어도 안전성 검사는 필요)
        if (!context.mounted) {
          debugPrint('context가 더 이상 유효하지 않습니다');
          return;
        }
        
        // 다음 프레임에서 네비게이션 실행
        Future.microtask(() {
          // microtask 내부에서도 mounted 체크 (추가 안전성 보장)
          if (!context.mounted) return;
          
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(
              builder: (context) => SetupProfileScreen(
                userId: result.user!.uid,
              ),
            ),
            (route) => false, // 모든 이전 화면 제거
          );
        });
      }
    } catch (e, stack) {
      debugPrint('구글 로그인 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 회원가입 - 반환 타입 변경됨
  Future<User?> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('회원가입 시도: $email');
      final user = await _repository.signUpWithEmailAndPassword(email, password);
      state = const AsyncValue.data(null);
      debugPrint('회원가입 성공: ${user?.uid}');
      return user;
    } catch (e, stack) {
      debugPrint('회원가입 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('로그아웃 시도');
      await _repository.signOut();
      state = const AsyncValue.data(null);
      debugPrint('로그아웃 성공');
    } catch (e, stack) {
      debugPrint('로그아웃 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 사용자 프로필 업데이트
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? username,
    String? profileImageUrl,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('사용자 프로필 업데이트 시도: $userId');
      final currentUser = await _repository.getUserProfile(userId);
      
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(
          name: name,
          username: username,
          profileImageUrl: profileImageUrl,
        );
        
        await _repository.updateUserProfile(updatedUser);
        state = const AsyncValue.data(null);
        debugPrint('사용자 프로필 업데이트 성공');
      } else {
        throw Exception('사용자를 찾을 수 없습니다.');
      }
    } catch (e, stack) {
      debugPrint('사용자 프로필 업데이트 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
}