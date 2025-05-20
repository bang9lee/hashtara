import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';

// 로컬 저장소 키 상수
const String kSignupProgressKey = 'signup_progress_state';
const String kSignupUserIdKey = 'signup_user_id';

// 회원가입 진행 상태를 로컬에 저장하는 함수
Future<void> saveSignupProgress(SignupProgress progress, String? userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kSignupProgressKey, progress.index);
    if (userId != null) {
      await prefs.setString(kSignupUserIdKey, userId);
    }
    debugPrint('회원가입 상태 저장됨: ${progress.name}, userId: $userId');
  } catch (e) {
    debugPrint('회원가입 상태 저장 실패: $e');
  }
}

// 로컬에 저장된 회원가입 진행 상태를 불러오는 함수
Future<Map<String, dynamic>> loadSignupProgress() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final progressIndex = prefs.getInt(kSignupProgressKey) ?? 0;
    final userId = prefs.getString(kSignupUserIdKey);
    
    debugPrint('저장된 회원가입 상태 불러옴: ${SignupProgress.values[progressIndex].name}, userId: $userId');
    
    return {
      'progress': SignupProgress.values[progressIndex],
      'userId': userId,
    };
  } catch (e) {
    debugPrint('회원가입 상태 불러오기 실패: $e');
    return {
      'progress': SignupProgress.none,
      'userId': null,
    };
  }
}

// 회원가입 진행 상태를 초기화하는 함수
Future<void> clearSignupProgress() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSignupProgressKey);
    await prefs.remove(kSignupUserIdKey);
    debugPrint('회원가입 상태 초기화됨');
  } catch (e) {
    debugPrint('회원가입 상태 초기화 실패: $e');
  }
}

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
    data: (user) async {
      if (user != null) {
        debugPrint('사용자 프로필 로드 시도: ${user.uid}');
        UserModel? userModel = await repository.getUserProfile(user.uid);
        
        // 사용자 정보가 없는 경우 기본 사용자 정보 생성
        if (userModel == null) {
          debugPrint('기존 사용자 정보 없음, 기본 정보 생성 시도');
          try {
            // 기본 사용자 정보 생성 시도
            final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6, 10);
            const defaultName = 'User';
            final defaultUsername = 'user_$timestamp';
            
            // 프로필 정보 생성
            await repository.createUserDocument(
              user.uid,
              defaultName,
              defaultUsername,
              null // 프로필 이미지 없음
            );
            
            // 다시 사용자 정보 로드
            userModel = await repository.getUserProfile(user.uid);
            debugPrint('기본 사용자 정보 생성 완료');
          } catch (e) {
            debugPrint('기본 사용자 정보 생성 실패: $e');
          }
        }
        
        return userModel;
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

// 회원가입 진행 상태를 위한 프로바이더
final signupProgressProvider = StateProvider<SignupProgress>((ref) => SignupProgress.none);

// 회원가입 진행 상태 열거형
enum SignupProgress {
  none,        // 기본 상태 또는 기존 사용자
  registered,  // 회원가입만 완료된 상태 (약관 동의 필요)
  termsAgreed, // 약관 동의까지 완료된 상태 (프로필 설정 필요)
  completed    // 모든 가입 절차 완료
}

// 인증 네비게이션 상태 프로바이더
final authNavigationStateProvider = StateProvider<AuthNavigationState>((ref) => 
  AuthNavigationState());

// 인증 네비게이션 상태 클래스
class AuthNavigationState {
  final String? targetRoute;
  final String? userId;
  final bool isNavigating;
  
  AuthNavigationState({
    this.targetRoute, 
    this.userId, 
    this.isNavigating = false
  });
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
  
  // 회원가입 상태 업데이트 및 저장 메서드
  Future<void> updateAndSaveSignupProgress(SignupProgress progress, String? userId) async {
    // 메모리 상태 업데이트
    _ref.read(signupProgressProvider.notifier).state = progress;
    
    // 로컬 저장소에 상태 저장
    if (progress != SignupProgress.none && userId != null) {
      await saveSignupProgress(progress, userId);
    } else if (progress == SignupProgress.none || progress == SignupProgress.completed) {
      // 초기 상태나 완료 상태면 로컬 저장소 상태 정리
      await clearSignupProgress();
    }
  }
  
  // 이메일/비밀번호 로그인
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('로그인 시도: $email');
      final userCredential = await _repository.signInWithEmailAndPassword(email, password);
      
      // 로그인 성공 시 사용자 확인 및 상태 업데이트
      await _updateSignupProgressState();
      
      state = const AsyncValue.data(null);
      debugPrint('로그인 성공: ${userCredential.user?.uid}');
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
        await updateAndSaveSignupProgress(SignupProgress.none, null);
        return;
      }
      
      // 병렬로 데이터 요청하여 성능 개선
      final results = await Future.wait([
        _repository.isTermsAgreed(user.uid),
        _repository.isProfileComplete(user.uid)
      ]);
      
      final isTermsAgreed = results[0];
      final isProfileComplete = results[1];
      
      debugPrint('사용자 상태 확인: 약관동의=$isTermsAgreed, 프로필완료=$isProfileComplete');
      
      SignupProgress progress;
      if (!isTermsAgreed) {
        debugPrint('약관 동의 필요 상태로 설정');
        progress = SignupProgress.registered;
      } else if (!isProfileComplete) {
        debugPrint('프로필 설정 필요 상태로 설정');
        progress = SignupProgress.termsAgreed;
      } else {
        debugPrint('모든 가입 절차 완료 상태로 설정');
        progress = SignupProgress.completed;
      }
      
      await updateAndSaveSignupProgress(progress, user.uid);
    } catch (e) {
      debugPrint('회원가입 진행 상태 업데이트 실패: $e');
      
      // 오류 시 로컬 저장소 데이터 복원 시도
      try {
        final savedState = await loadSignupProgress();
        if (savedState['userId'] != null) {
          _ref.read(signupProgressProvider.notifier).state = savedState['progress'];
        } else {
          _ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
        }
      } catch (_) {
        _ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
      }
    }
  }
  
  // 구글 로그인 - 통합된 메서드
  Future<UserCredential?> signInWithGoogle() async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('구글 로그인 시도');
      final result = await _repository.signInWithGoogle();
      state = const AsyncValue.data(null);
      debugPrint('구글 로그인 성공: ${result.user?.uid}');
      
      // 신규 사용자인 경우 상태 저장
      if (result.additionalUserInfo?.isNewUser == true && result.user != null) {
        debugPrint('신규 사용자 감지, 약관 동의 필요 상태로 설정');
        await updateAndSaveSignupProgress(SignupProgress.registered, result.user!.uid);
      } else if (result.user != null) {
        // 기존 사용자의 경우 상태 업데이트
        await _updateSignupProgressState();
      }
      
      return result;
    } catch (e, stack) {
      debugPrint('구글 로그인 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 회원가입
  Future<User?> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('회원가입 시도: $email');
      final user = await _repository.signUpWithEmailAndPassword(email, password);
      
      // 회원가입 성공 시 상태 저장
      if (user != null) {
        await updateAndSaveSignupProgress(SignupProgress.registered, user.uid);
      }
      
      state = const AsyncValue.data(null);
      debugPrint('회원가입 성공: ${user?.uid}');
      return user;
    } catch (e, stack) {
      debugPrint('회원가입 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 약관 동의 완료
  Future<void> completeTermsAgreement(String userId) async {
    try {
      // 약관 동의 상태를 Firestore에 업데이트
      await _repository.updateTermsAgreement(userId, true);
      
      // 회원가입 진행 상태 업데이트 및 저장
      await updateAndSaveSignupProgress(SignupProgress.termsAgreed, userId);
      
      debugPrint('약관 동의 완료 처리 성공: $userId');
    } catch (e) {
      debugPrint('약관 동의 완료 처리 실패: $e');
      rethrow;
    }
  }
  
  // 프로필 설정 완료
  Future<void> completeProfileSetup(String userId) async {
    try {
      // 프로필 완료 상태를 Firestore에 업데이트
      await _repository.updateProfileComplete(userId, true);
      
      // 회원가입 진행 상태 업데이트 및 저장
      await updateAndSaveSignupProgress(SignupProgress.completed, userId);
      
      // 현재 사용자 정보 갱신 - 반환값을 변수에 할당하여 lint 경고 제거
      final refreshResult = _ref.refresh(currentUserProvider);
      debugPrint('사용자 정보 갱신 결과: ${refreshResult.hashCode}');
      
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
      
      // 회원가입 진행 상태 초기화 및 저장소 정리
      await updateAndSaveSignupProgress(SignupProgress.none, null);
      
      state = const AsyncValue.data(null);
      debugPrint('로그아웃 성공');
    } catch (e, stack) {
      debugPrint('로그아웃 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 회원 탈퇴
  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('회원 탈퇴 시도');
      await _repository.deleteAccount();
      
      // 회원가입 진행 상태 초기화 및 저장소 정리
      await updateAndSaveSignupProgress(SignupProgress.none, null);
      
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
        
        // 사용자 데이터 갱신 - 반환값을 변수에 할당하여 lint 경고 제거
        final refreshResult = _ref.refresh(currentUserProvider);
        debugPrint('사용자 정보 갱신 결과: ${refreshResult.hashCode}');
        
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
  
  // 현재 인증 상태 새로고침
  Future<void> refreshAuthState() async {
    try {
      final user = _repository.currentUser;
      if (user != null) {
        await _updateSignupProgressState();
        
        // 사용자 정보 명시적 갱신 - 반환값을 변수에 할당하여 lint 경고 제거
        final refreshResult = _ref.refresh(currentUserProvider);
        debugPrint('사용자 정보 갱신 결과: ${refreshResult.hashCode}');
        
        debugPrint('인증 상태 새로고침 완료: ${user.uid}');
      } else {
        debugPrint('로그인된 사용자 없음, 인증 상태 초기화');
        await updateAndSaveSignupProgress(SignupProgress.none, null);
      }
    } catch (e) {
      debugPrint('인증 상태 새로고침 실패: $e');
    }
  }
}