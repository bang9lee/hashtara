import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';

// 로컬 저장소 키 상수
const String kSignupProgressKey = 'signup_progress_state';
const String kSignupUserIdKey = 'signup_user_id';
const String kDeletedAccountKey = 'deleted_account_flag';

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

// 탈퇴 계정 플래그 저장
Future<void> markAccountAsDeleted(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kDeletedAccountKey, userId);
    debugPrint('탈퇴 계정 플래그 저장: $userId');
  } catch (e) {
    debugPrint('탈퇴 계정 플래그 저장 실패: $e');
  }
}

// 탈퇴 계정 플래그 확인
Future<bool> isAccountDeleted(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final deletedUserId = prefs.getString(kDeletedAccountKey);
    return deletedUserId == userId;
  } catch (e) {
    debugPrint('탈퇴 계정 플래그 확인 실패: $e');
    return false;
  }
}

// 탈퇴 계정 플래그 제거
Future<void> clearDeletedAccountFlag() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kDeletedAccountKey);
    debugPrint('탈퇴 계정 플래그 제거됨');
  } catch (e) {
    debugPrint('탈퇴 계정 플래그 제거 실패: $e');
  }
}

// 인증 저장소 프로바이더
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// 인증 상태 프로바이더
final authStateProvider = StreamProvider<User?>((ref) {
  debugPrint('🔥 AuthState Provider 초기화');
  return FirebaseAuth.instance.authStateChanges();
});

// 🔥 구글 로그인 문제 해결을 위한 강화된 현재 사용자 프로바이더
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final repository = ref.watch(authRepositoryProvider);
  
  return authState.when(
    data: (user) async {
      if (user == null) {
        debugPrint('🔥 사용자 로그인되지 않음');
        return null;
      }
      
      debugPrint('🔥 로그인된 사용자: ${user.uid}');
      
      // 탈퇴 계정 체크
      final isDeleted = await isAccountDeleted(user.uid);
      if (isDeleted) {
        debugPrint('🔥 탈퇴 계정 감지, 강제 로그아웃');
        await FirebaseAuth.instance.signOut();
        await clearDeletedAccountFlag();
        return null;
      }
      
      // 🔥 사용자 문서 확인
      DocumentSnapshot? userDoc;
      try {
        userDoc = await repository.firestore.collection('users').doc(user.uid).get();
        debugPrint('🔥 사용자 문서 존재 여부: ${userDoc.exists}');
      } catch (e) {
        debugPrint('🔥 사용자 문서 조회 실패: $e');
        return null;
      }
      
      // 🔥 사용자 문서가 없으면 신규 가입자
      if (!userDoc.exists) {
        debugPrint('🔥🔥🔥 사용자 문서 없음 - 신규 가입자 확정');
        ref.read(signupProgressProvider.notifier).state = SignupProgress.registered;
        await saveSignupProgress(SignupProgress.registered, user.uid);
        return null;
      }
      
      // 🔥 사용자 문서가 존재하는 경우 - 약관/프로필 상태 확인
      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) {
        debugPrint('🔥 사용자 문서 데이터가 null');
        ref.read(signupProgressProvider.notifier).state = SignupProgress.registered;
        await saveSignupProgress(SignupProgress.registered, user.uid);
        return null;
      }
      
      final termsAgreed = userData['termsAgreed'] == true;
      final profileComplete = userData['profileComplete'] == true;
      
      debugPrint('🔥 기존 사용자 상태: 약관동의=$termsAgreed, 프로필완료=$profileComplete');
      
      // 약관 동의가 안된 경우
      if (!termsAgreed) {
        debugPrint('🔥 약관 동의 필요');
        ref.read(signupProgressProvider.notifier).state = SignupProgress.registered;
        await saveSignupProgress(SignupProgress.registered, user.uid);
        return null;
      }
      
      // 프로필 설정이 안된 경우
      if (!profileComplete) {
        debugPrint('🔥 프로필 설정 필요');
        ref.read(signupProgressProvider.notifier).state = SignupProgress.termsAgreed;
        await saveSignupProgress(SignupProgress.termsAgreed, user.uid);
        return null;
      }
      
      // 🔥 모든 조건을 만족하는 경우 - 사용자 모델 로드
      debugPrint('🔥 완료된 사용자 - 사용자 모델 로드');
      try {
        final userModel = await repository.getUserProfile(user.uid);
        if (userModel != null) {
          ref.read(signupProgressProvider.notifier).state = SignupProgress.completed;
          await saveSignupProgress(SignupProgress.completed, user.uid);
          debugPrint('🔥🔥🔥 사용자 모델 로드 성공: ${userModel.id}');
          return userModel;
        } else {
          debugPrint('🔥 사용자 모델이 없음 - 프로필 설정 다시 필요');
          ref.read(signupProgressProvider.notifier).state = SignupProgress.termsAgreed;
          await saveSignupProgress(SignupProgress.termsAgreed, user.uid);
          return null;
        }
      } catch (e) {
        debugPrint('🔥 사용자 모델 로드 에러: $e');
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// 사용자 프로필 조회 프로바이더
final getUserProfileProvider = FutureProvider.family<UserModel?, String>((ref, userId) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.getUserProfile(userId);
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
    _ref.read(signupProgressProvider.notifier).state = progress;
    
    if (progress != SignupProgress.none && userId != null) {
      await saveSignupProgress(progress, userId);
    } else {
      await clearSignupProgress();
    }
  }
  
  // 이메일/비밀번호 로그인
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('🔥 로그인 시도: $email');
      await _repository.signInWithEmailAndPassword(email, password);
      await clearDeletedAccountFlag();
      state = const AsyncValue.data(null);
      debugPrint('🔥 로그인 성공');
    } catch (e, stack) {
      debugPrint('🔥 로그인 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 🔥 구글 로그인 - 완전히 새로 작성
  Future<UserCredential?> signInWithGoogle() async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('🔥 구글 로그인 시도');
      final result = await _repository.signInWithGoogle();
      await clearDeletedAccountFlag();
      
      if (result.user != null) {
        debugPrint('🔥 구글 로그인 성공: ${result.user!.uid}');
        
        // 🔥 사용자 문서 존재 여부 확인
        final userDoc = await _repository.firestore.collection('users').doc(result.user!.uid).get();
        
        if (!userDoc.exists) {
          debugPrint('🔥🔥🔥 구글 로그인 - 신규 가입자: 약관 동의부터 시작');
          await updateAndSaveSignupProgress(SignupProgress.registered, result.user!.uid);
        } else {
          debugPrint('🔥 구글 로그인 - 기존 사용자: 상태 확인');
          
          // 기존 사용자의 경우 약관/프로필 상태 확인
          final userData = userDoc.data();
          final termsAgreed = userData?['termsAgreed'] == true;
          final profileComplete = userData?['profileComplete'] == true;
          
          if (!termsAgreed) {
            debugPrint('🔥 구글 로그인 - 약관 동의 필요');
            await updateAndSaveSignupProgress(SignupProgress.registered, result.user!.uid);
          } else if (!profileComplete) {
            debugPrint('🔥 구글 로그인 - 프로필 설정 필요');
            await updateAndSaveSignupProgress(SignupProgress.termsAgreed, result.user!.uid);
          } else {
            debugPrint('🔥 구글 로그인 - 모든 설정 완료');
            await updateAndSaveSignupProgress(SignupProgress.completed, result.user!.uid);
          }
        }
        
        // 🔥 프로바이더 강제 갱신
        _ref.invalidate(currentUserProvider);
        await Future.delayed(const Duration(milliseconds: 100));
        _ref.invalidate(currentUserProvider);
      }
      
      state = const AsyncValue.data(null);
      return result;
    } catch (e, stack) {
      debugPrint('🔥 구글 로그인 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 회원가입
  Future<User?> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('🔥 회원가입 시도: $email');
      final user = await _repository.signUpWithEmailAndPassword(email, password);
      
      if (user != null) {
        await updateAndSaveSignupProgress(SignupProgress.registered, user.uid);
      }
      
      state = const AsyncValue.data(null);
      debugPrint('🔥 회원가입 성공: ${user?.uid}');
      return user;
    } catch (e, stack) {
      debugPrint('🔥 회원가입 실패: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
  
  // 약관 동의 완료
  Future<void> completeTermsAgreement(String userId) async {
    try {
      debugPrint('🔥 약관 동의 처리 시작: $userId');
      
      // 1. 약관 동의 상태 업데이트
      await _repository.updateTermsAgreement(userId, true);
      
      // 2. 기본 사용자 문서가 없으면 생성
      final userDoc = await _repository.firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('🔥 사용자 문서가 없어서 기본 문서 생성');
        
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6, 10);
        const defaultName = 'User';
        final defaultUsername = 'user_$timestamp';
        
        await _repository.createUserDocument(
          userId,
          defaultName,
          defaultUsername,
          null,
        );
        
        debugPrint('🔥 기본 사용자 문서 생성 완료');
      }
      
      // 3. 상태 업데이트
      await updateAndSaveSignupProgress(SignupProgress.termsAgreed, userId);
      
      // 4. 프로바이더 강제 갱신
      _ref.invalidate(currentUserProvider);
      await Future.delayed(const Duration(milliseconds: 300));
      _ref.invalidate(currentUserProvider);
      
      debugPrint('🔥 약관 동의 완료: $userId');
    } catch (e) {
      debugPrint('🔥 약관 동의 실패: $e');
      rethrow;
    }
  }
  
  // 🔥 프로필 설정 완료 - 구글 로그인 문제 해결을 위해 강화
  Future<void> completeProfileSetup(String userId) async {
    try {
      debugPrint('🔥🔥🔥 프로필 설정 완료 처리 시작: $userId');
      
      // 1. 프로필 완료 상태 업데이트
      await _repository.updateProfileComplete(userId, true);
      debugPrint('🔥 Firestore 프로필 완료 상태 업데이트 완료');
      
      // 2. 상태 업데이트
      await updateAndSaveSignupProgress(SignupProgress.completed, userId);
      debugPrint('🔥 로컬 상태 업데이트 완료');
      
      // 3. 🔥 강력한 프로바이더 갱신 (여러 번)
      _ref.invalidate(currentUserProvider);
      await Future.delayed(const Duration(milliseconds: 200));
      
      _ref.invalidate(currentUserProvider);
      await Future.delayed(const Duration(milliseconds: 300));
      
      _ref.invalidate(currentUserProvider);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 4. 🔥 사용자 정보 다시 로드 확인
      try {
        final userModel = await _repository.getUserProfile(userId);
        debugPrint('🔥 프로필 설정 완료 후 사용자 모델 확인: ${userModel?.id}');
      } catch (e) {
        debugPrint('🔥 사용자 모델 로드 확인 실패: $e');
      }
      
      debugPrint('🔥🔥🔥 프로필 설정 완료: $userId');
    } catch (e) {
      debugPrint('🔥 프로필 설정 실패: $e');
      rethrow;
    }
  }
  
  // 강력한 로그아웃
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    
    try {
      debugPrint('🔥🔥🔥 강력한 로그아웃 시작');
      
      _ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
      await clearSignupProgress();
      
      await _repository.signOut();
      
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(authStateProvider);
      
      await Future.delayed(const Duration(milliseconds: 100));
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(authStateProvider);
      
      state = const AsyncValue.data(null);
      debugPrint('🔥🔥🔥 강력한 로그아웃 완료');
      
    } catch (e, stack) {
      debugPrint('🔥🔥🔥 로그아웃 실패: $e');
      
      try {
        _ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
        await clearSignupProgress();
        _ref.invalidate(currentUserProvider);
        _ref.invalidate(authStateProvider);
      } catch (_) {}
      
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 회원 탈퇴
  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    
    final user = _repository.currentUser;
    String? userId = user?.uid;
    
    try {
      debugPrint('🔥 회원 탈퇴 시도: $userId');
      
      if (userId != null) {
        await markAccountAsDeleted(userId);
      }
      
      await updateAndSaveSignupProgress(SignupProgress.none, null);
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(authStateProvider);
      
      try {
        await _repository.deleteAccount();
      } catch (e) {
        debugPrint('🔥 계정 삭제 실패하지만 계속 진행: $e');
      }
      
      try {
        await _repository.signOut();
      } catch (e) {
        debugPrint('🔥 강제 로그아웃 실패: $e');
      }
      
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(authStateProvider);
      
      state = const AsyncValue.data(null);
      debugPrint('🔥 회원 탈퇴 완료');
      
    } catch (e, stack) {
      debugPrint('🔥 회원 탈퇴 실패: $e');
      
      try {
        if (userId != null) {
          await markAccountAsDeleted(userId);
        }
        await updateAndSaveSignupProgress(SignupProgress.none, null);
        await _repository.signOut();
        _ref.invalidate(currentUserProvider);
        _ref.invalidate(authStateProvider);
      } catch (_) {}
      
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
      debugPrint('🔥 프로필 업데이트: $userId');
      final currentUser = await _repository.getUserProfile(userId);
      
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(
          name: name,
          username: username,
          profileImageUrl: profileImageUrl,
        );
        
        await _repository.updateUserProfile(updatedUser);
        
        // unused result 해결
        final refreshResult = _ref.refresh(currentUserProvider);
        debugPrint('프로바이더 갱신 결과: ${refreshResult.hashCode}');
        
        state = const AsyncValue.data(null);
        debugPrint('🔥 프로필 업데이트 성공');
      } else {
        throw Exception('사용자를 찾을 수 없습니다.');
      }
    } catch (e, stack) {
      debugPrint('🔥 프로필 업데이트 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
}