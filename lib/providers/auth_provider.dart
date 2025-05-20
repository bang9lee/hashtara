import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../views/profile/setup_profile_screen.dart';
import '../views/auth/terms_agreement_screen.dart';

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

// 이용약관 동의 여부 확인 프로바이더
final isTermsAgreedProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final repository = ref.watch(authRepositoryProvider);
  return await repository.isTermsAgreed(userId);
});

// 추가: 회원가입 진행 상태를 위한 프로바이더
final signupProgressProvider = StateProvider<SignupProgress>((ref) => SignupProgress.none);

// 회원가입 진행 상태 열거형
enum SignupProgress {
  none,        // 기본 상태 또는 기존 사용자
  registered,  // 회원가입만 완료된 상태 (약관 동의 필요)
  termsAgreed, // 약관 동의까지 완료된 상태 (프로필 설정 필요)
  completed    // 모든 가입 절차 완료
}

// 로그인 상태 관리 프로바이더
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository, ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;
  final Ref _ref;
  
  AuthController(this._repository, this._ref) : super(const AsyncValue.data(null));
  
  // 로그인
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('로그인 시도: $email');
      await _repository.signInWithEmailAndPassword(email, password);
      
      // 로그인 성공 시 사용자 확인 및 상태 업데이트
      await _updateSignupProgressState();
      
      state = const AsyncValue.data(null);
      debugPrint('로그인 성공');
    } catch (e, stack) {
      debugPrint('로그인 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 사용자 로그인 상태에 따라 회원가입 진행 상태 업데이트
  Future<void> _updateSignupProgressState() async {
    try {
      final user = _repository.currentUser;
      if (user == null) {
        debugPrint('현재 로그인된 사용자 없음');
        _ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
        return;
      }
      
      final isTermsAgreed = await _repository.isTermsAgreed(user.uid);
      final isProfileComplete = await _repository.isProfileComplete(user.uid);
      
      if (!isTermsAgreed) {
        debugPrint('약관 동의 필요 상태로 설정');
        _ref.read(signupProgressProvider.notifier).state = SignupProgress.registered;
      } else if (!isProfileComplete) {
        debugPrint('프로필 설정 필요 상태로 설정');
        _ref.read(signupProgressProvider.notifier).state = SignupProgress.termsAgreed;
      } else {
        debugPrint('모든 가입 절차 완료 상태로 설정');
        _ref.read(signupProgressProvider.notifier).state = SignupProgress.completed;
      }
    } catch (e) {
      debugPrint('회원가입 진행 상태 업데이트 실패: $e');
      // 오류 시 기본 상태로 설정
      _ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
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
      
      // 신규 사용자인 경우 약관 동의 화면으로 이동 (수정된 부분)
      if (result.additionalUserInfo?.isNewUser == true && result.user != null) {
        debugPrint('신규 사용자, 약관 동의 화면으로 이동');
        
        // BuildContext 사용 전 mounted 체크 (context가 NavigatorState의 context가 아니어도 안전성 검사는 필요)
        if (!context.mounted) {
          debugPrint('context가 더 이상 유효하지 않습니다');
          return;
        }

        // 명시적으로 회원가입 진행 상태 설정 (추가)
        _ref.read(signupProgressProvider.notifier).state = SignupProgress.registered;
        
        // 다음 프레임에서 네비게이션 실행
        Future.microtask(() {
          // microtask 내부에서도 mounted 체크 (추가 안전성 보장)
          if (!context.mounted) return;
          
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(
              builder: (context) => TermsAgreementScreen(
                userId: result.user!.uid,
              ),
            ),
            (route) => false, // 모든 이전 화면 제거
          );
        });
      } else {
        // 기존 사용자인 경우 상태 업데이트
        await _updateSignupProgressState();
        
        // 진행 상태에 따라 필요한 화면으로 이동
        if (context.mounted) {
          final progressState = _ref.read(signupProgressProvider);
          
          switch (progressState) {
            case SignupProgress.registered:
              // 약관 동의 필요
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (context) => TermsAgreementScreen(
                    userId: result.user!.uid,
                  ),
                ),
                (route) => false,
              );
              break;
            case SignupProgress.termsAgreed:
              // 프로필 설정 필요
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (context) => SetupProfileScreen(
                    userId: result.user!.uid,
                  ),
                ),
                (route) => false,
              );
              break;
            case SignupProgress.completed:
            case SignupProgress.none:
              // 완료된 상태 또는 기본 상태 - 메인 화면으로 자동 이동
              break;
          }
        }
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
      
      // 명시적으로 회원가입 진행 상태 설정 (추가)
      if (user != null) {
        _ref.read(signupProgressProvider.notifier).state = SignupProgress.registered;
      }
      
      return user;
    } catch (e, stack) {
      debugPrint('회원가입 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 약관 동의 완료 메서드 (추가)
  Future<void> completeTermsAgreement(String userId) async {
    try {
      // 약관 동의 상태를 Firestore에 업데이트
      await _repository.updateTermsAgreement(userId, true);
      
      // 회원가입 진행 상태 업데이트
      _ref.read(signupProgressProvider.notifier).state = SignupProgress.termsAgreed;
      
      debugPrint('약관 동의 완료 처리 성공: $userId');
    } catch (e) {
      debugPrint('약관 동의 완료 처리 실패: $e');
      rethrow;
    }
  }
  
  // 프로필 설정 완료 메서드 (추가)
  Future<void> completeProfileSetup(String userId) async {
    try {
      // 프로필 완료 상태를 Firestore에 업데이트
      await _repository.updateProfileComplete(userId, true);
      
      // 회원가입 진행 상태 업데이트
      _ref.read(signupProgressProvider.notifier).state = SignupProgress.completed;
      
      debugPrint('프로필 설정 완료 처리 성공: $userId');
    } catch (e) {
      debugPrint('프로필 설정 완료 처리 실패: $e');
      rethrow;
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('로그아웃 시도');
      await _repository.signOut();
      
      // 회원가입 진행 상태 초기화
      _ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
      
      state = const AsyncValue.data(null);
      debugPrint('로그아웃 성공');
    } catch (e, stack) {
      debugPrint('로그아웃 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 회원 탈퇴 메서드 (추가)
  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('회원 탈퇴 시도');
      await _repository.deleteAccount();
      
      // 회원가입 진행 상태 초기화
      _ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
      
      state = const AsyncValue.data(null);
      debugPrint('회원 탈퇴 성공');
    } catch (e, stack) {
      debugPrint('회원 탈퇴 실패: $e');
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