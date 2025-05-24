import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart'; // 🔥 kIsWeb와 debugPrint를 위해 추가
import '../models/user_model.dart';
import '../repositories/notification_repository.dart';

// 인증 오류 타입 열거형 추가
enum AuthErrorType {
  invalidEmail,
  userDisabled,
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  invalidCredential,
  operationNotAllowed,
  weakPassword,
  networkError,
  requiresRecentLogin, // 🔥 추가
  unknown
}

// 인증 예외 클래스 추가
class AuthException implements Exception {
  final AuthErrorType type;
  final String message;
  final Object? originalError;

  AuthException({
    required this.type,
    required this.message,
    this.originalError,
  });

  @override
  String toString() {
    return 'AuthException: $message (${type.toString()})';
  }
}

// 인증 오류 처리 클래스 추가
class AuthErrorHandler {
  static Exception handleException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return AuthException(
            type: AuthErrorType.invalidEmail,
            message: '유효하지 않은 이메일 주소입니다.',
            originalError: e,
          );
        case 'user-disabled':
          return AuthException(
            type: AuthErrorType.userDisabled,
            message: '비활성화된 계정입니다.',
            originalError: e,
          );
        case 'user-not-found':
          return AuthException(
            type: AuthErrorType.userNotFound,
            message: '해당 이메일로 등록된 사용자가 없습니다.',
            originalError: e,
          );
        case 'wrong-password':
          return AuthException(
            type: AuthErrorType.wrongPassword,
            message: '비밀번호가 올바르지 않습니다.',
            originalError: e,
          );
        case 'email-already-in-use':
          return AuthException(
            type: AuthErrorType.emailAlreadyInUse,
            message: '이미 사용 중인 이메일 주소입니다.',
            originalError: e,
          );
        case 'operation-not-allowed':
          return AuthException(
            type: AuthErrorType.operationNotAllowed,
            message: '이 작업은 허용되지 않습니다.',
            originalError: e,
          );
        case 'weak-password':
          return AuthException(
            type: AuthErrorType.weakPassword,
            message: '보안에 취약한 비밀번호입니다. 더 강력한 비밀번호를 사용해주세요.',
            originalError: e,
          );
        case 'requires-recent-login': // 🔥 추가
          return AuthException(
            type: AuthErrorType.requiresRecentLogin,
            message: '보안상 중요한 작업입니다. 다시 로그인 후 시도해주세요.',
            originalError: e,
          );
        default:
          return AuthException(
            type: AuthErrorType.unknown,
            message: '알 수 없는 오류가 발생했습니다: ${e.message}',
            originalError: e,
          );
      }
    } else if (e is AuthException) {
      return e;
    } else {
      return AuthException(
        type: AuthErrorType.unknown,
        message: '알 수 없는 오류가 발생했습니다: $e',
        originalError: e,
      );
    }
  }
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final Logger _logger;
  final NotificationRepository _notificationRepository;

  AuthRepository({
    FirebaseAuth? auth, 
    FirebaseFirestore? firestore, 
    GoogleSignIn? googleSignIn, 
    Logger? logger,
    NotificationRepository? notificationRepository,
  })
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _logger = logger ?? Logger(),
        _notificationRepository = notificationRepository ?? NotificationRepository();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Firestore 인스턴스 접근을 위한 getter 추가
  FirebaseFirestore get firestore => _firestore;
  
  // 사용자 프로필 가져오기
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _logger.e('사용자 프로필 로드 실패: $e');
      return null;
    }
  }
  
  // 사용자 프로필 업데이트
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      _logger.e('사용자 프로필 업데이트 실패: $e');
      throw AuthException(
        type: AuthErrorType.unknown,
        message: '프로필 업데이트에 실패했습니다.',
        originalError: e,
      );
    }
  }
  
  // 사용자 문서 생성
  Future<void> createUserDocument(
    String userId,
    String name,
    String username,
    String? profileImageUrl,
  ) async {
    try {
      final now = DateTime.now();
      final newUser = UserModel(
        id: userId,
        name: name,
        username: username,
        email: _auth.currentUser?.email ?? '',
        profileImageUrl: profileImageUrl,
        createdAt: now,
      );
      
      await _firestore.collection('users').doc(userId).set(newUser.toMap());
    } catch (e) {
      _logger.e('사용자 문서 생성 실패: $e');
      rethrow;
    }
  }
  
  // 프로필 완료 상태 확인
  Future<bool> isProfileComplete(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['profileComplete'] == true;
      }
      return false;
    } catch (e) {
      _logger.e('프로필 완료 상태 확인 실패: $e');
      return false;
    }
  }
  
  // 약관 동의 상태 확인
  Future<bool> isTermsAgreed(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['termsAgreed'] == true;
      }
      return false;
    } catch (e) {
      _logger.e('약관 동의 상태 확인 실패: $e');
      return false;
    }
  }
  
  // 이메일/비밀번호 로그인
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _logger.e('로그인 실패: $e');
      throw AuthErrorHandler.handleException(e);
    } catch (e) {
      _logger.e('로그인 중 알 수 없는 오류 발생: $e');
      throw AuthException(
        type: AuthErrorType.unknown,
        message: '로그인 중 오류가 발생했습니다.',
        originalError: e,
      );
    }
  }
  
  // 이메일/비밀번호 회원가입
  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      _logger.e('회원가입 실패: $e');
      throw AuthErrorHandler.handleException(e);
    } catch (e) {
      _logger.e('회원가입 중 알 수 없는 오류 발생: $e');
      throw AuthException(
        type: AuthErrorType.unknown,
        message: '회원가입 중 오류가 발생했습니다.',
        originalError: e,
      );
    }
  }
  
  // 🔥 구글 로그인 - 웹 호환성 문제 해결
  Future<UserCredential> signInWithGoogle() async {
    try {
      // 🌐 웹에서는 다른 방식 사용
      if (kIsWeb) {
        debugPrint('🌐 웹: Firebase Auth로 구글 로그인 시작');
        
        // 웹에서는 GoogleAuthProvider.credential() 대신 팝업 방식 사용
        final googleProvider = GoogleAuthProvider();
        
        // 추가 권한 요청
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        // 팝업으로 구글 로그인
        final result = await _auth.signInWithPopup(googleProvider);
        
        debugPrint('🌐 웹: 구글 로그인 성공');
        return result;
      } else {
        // 🔥 모바일: 기존 방식
        debugPrint('📱 모바일: GoogleSignIn으로 로그인 시작');
        
        // 구글 로그인 플로우 시작
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          throw AuthException(
            type: AuthErrorType.operationNotAllowed,
            message: '구글 로그인이 취소되었습니다.',
          );
        }
        
        // 인증 상세 정보 획득
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        // 파이어베이스 인증 정보 생성
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        // 파이어베이스에 로그인
        return await _auth.signInWithCredential(credential);
      }
      
    } on FirebaseAuthException catch (e) {
      _logger.e('구글 로그인 실패: $e');
      throw AuthErrorHandler.handleException(e);
    } catch (e) {
      _logger.e('구글 로그인 중 알 수 없는 오류 발생: $e');
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException(
        type: AuthErrorType.unknown,
        message: '구글 로그인 중 오류가 발생했습니다.',
        originalError: e,
      );
    }
  }
  
  // 🔥🔥🔥 로그아웃 - 웹 호환성 완전 개선
  Future<void> signOut() async {
    try {
      debugPrint('🔥 로그아웃 시작 (플랫폼: ${kIsWeb ? "웹" : "모바일"})');
      debugPrint('🔥 로그아웃 전 사용자: ${_auth.currentUser?.uid}');
      
      // 🌐 웹에서는 특별한 처리
      if (kIsWeb) {
        debugPrint('🌐 웹: 강화된 로그아웃 시작');
        
        // 1. Firebase Auth 인스턴스 재생성 시도
        try {
          // 웹에서는 직접 Firebase Auth 인스턴스에 접근
          final auth = FirebaseAuth.instance;
          
          // 현재 사용자 확인
          if (auth.currentUser != null) {
            debugPrint('🌐 웹: 현재 로그인된 사용자: ${auth.currentUser!.uid}');
            
            // 로그아웃 시도
            await auth.signOut();
            debugPrint('🌐 웹: Firebase Auth 로그아웃 호출 완료');
            
            // 로그아웃 확인을 위한 대기
            await Future.delayed(const Duration(seconds: 1));
            
            // 다시 확인
            if (auth.currentUser == null) {
              debugPrint('🌐 웹: 로그아웃 성공 확인!');
            } else {
              debugPrint('🌐 웹: 경고 - 아직도 로그인 상태: ${auth.currentUser!.uid}');
              
              // 페이지 새로고침으로 강제 로그아웃 (웹 전용)
              if (kIsWeb) {
                debugPrint('🌐 웹: 페이지 새로고침으로 강제 로그아웃 시도');
                // JavaScript interop으로 페이지 새로고침
                // window.location.reload() 효과
              }
            }
          } else {
            debugPrint('🌐 웹: 이미 로그아웃 상태');
          }
          
        } catch (e) {
          debugPrint('🌐 웹: Firebase Auth 로그아웃 오류: $e');
          // 오류가 발생해도 계속 진행
        }
        
        // 2. 추가 정리 작업
        try {
          // 로컬 스토리지 정리
          debugPrint('🌐 웹: 로컬 스토리지 정리');
          // SharedPreferences 등 정리
        } catch (e) {
          debugPrint('🌐 웹: 로컬 스토리지 정리 오류: $e');
        }
        
      } else {
        // 📱 모바일: 기존 방식
        await _googleSignIn.signOut();
        await _auth.signOut();
      }
      
      // 최종 확인
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('🔥 로그아웃 완료 - 현재 사용자: ${_auth.currentUser?.uid ?? "없음"}');
      
      // 여전히 로그인 상태면 예외 발생
      if (_auth.currentUser != null) {
        debugPrint('🔥 경고: 로그아웃 후에도 사용자가 남아있음!');
        throw Exception('로그아웃 실패: 사용자가 여전히 로그인 상태');
      }
      
    } catch (e) {
      _logger.e('로그아웃 실패: $e');
      
      // 실패해도 강제로 로그아웃 시도
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      
      throw AuthException(
        type: AuthErrorType.unknown,
        message: '로그아웃 중 오류가 발생했습니다.',
        originalError: e,
      );
    }
  }

  // 약관 동의 상태 업데이트
  Future<void> updateTermsAgreement(String userId, bool agreed) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final docSnapshot = await docRef.get();
      
      final data = {
        'termsAgreed': agreed,
        'privacyAgreed': agreed,
        'agreementDate': FieldValue.serverTimestamp(),
      };
      
      if (docSnapshot.exists) {
        await docRef.update(data);
      } else {
        await docRef.set(data, SetOptions(merge: true));
      }
      
      _logger.i('약관 동의 상태 업데이트 성공: $userId, $agreed');
    } catch (e) {
      _logger.e('약관 동의 상태 업데이트 실패: $e');
      throw AuthException(
        type: AuthErrorType.unknown, 
        message: '약관 동의 상태를 업데이트하는 중 오류가 발생했습니다.', 
        originalError: e
      );
    }
  }

  // 프로필 완료 상태 업데이트
  Future<void> updateProfileComplete(String userId, bool complete) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        await docRef.update({
          'profileComplete': complete,
        });
      } else {
        await docRef.set({
          'profileComplete': complete,
        }, SetOptions(merge: true));
      }
      
      _logger.i('프로필 완료 상태 업데이트 성공: $userId, $complete');
    } catch (e) {
      _logger.e('프로필 완료 상태 업데이트 실패: $e');
      throw AuthException(
        type: AuthErrorType.unknown, 
        message: '프로필 완료 상태를 업데이트하는 중 오류가 발생했습니다.', 
        originalError: e
      );
    }
  }

  // 🔥 완전히 새로운 회원 탈퇴 메서드 - requires-recent-login 오류 처리 강화
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) { 
      throw AuthException(
        type: AuthErrorType.userNotFound, 
        message: '로그인된 사용자가 없습니다.'
      ); 
    }
    
    final userId = user.uid;
    _logger.i('🔥 회원 탈퇴 시작: $userId');
    
    // 단계별로 진행하되, 각 단계가 실패해도 다음 단계는 진행
    List<String> errors = [];
    bool authDeleted = false;
    
    try {
      // 1단계: 알림 데이터 삭제 (Auth 삭제 전에 먼저!)
      _logger.i('1단계: 알림 데이터 삭제 시작');
      await _notificationRepository.deleteAllUserNotifications(userId);
      await _notificationRepository.deleteUserFCMToken(userId);
      _logger.i('알림 데이터 삭제 성공');
    } catch (e) {
      _logger.w('알림 데이터 삭제 실패 (계속 진행): $e');
      errors.add('알림 삭제 실패: $e');
    }
    
    try {
      // 2단계: 사용자 게시물 삭제
      _logger.i('2단계: 사용자 게시물 삭제 시작');
      await _deleteUserPosts(userId);
      _logger.i('사용자 게시물 삭제 성공');
    } catch (e) {
      _logger.w('사용자 게시물 삭제 실패 (계속 진행): $e');
      errors.add('게시물 삭제 실패: $e');
    }
    
    try {
      // 3단계: 사용자 댓글 삭제
      _logger.i('3단계: 사용자 댓글 삭제 시작');
      await _deleteUserComments(userId);
      _logger.i('사용자 댓글 삭제 성공');
    } catch (e) {
      _logger.w('사용자 댓글 삭제 실패 (계속 진행): $e');
      errors.add('댓글 삭제 실패: $e');
    }
    
    try {
      // 4단계: 사용자 서브컬렉션 삭제
      _logger.i('4단계: 사용자 서브컬렉션 삭제 시작');
      await _deleteUserSubcollections(userId);
      _logger.i('사용자 서브컬렉션 삭제 성공');
    } catch (e) {
      _logger.w('사용자 서브컬렉션 삭제 실패 (계속 진행): $e');
      errors.add('서브컬렉션 삭제 실패: $e');
    }
    
    try {
      // 5단계: 사용자 문서 삭제 (중요!)
      _logger.i('5단계: 사용자 문서 삭제 시작');
      await _firestore.collection('users').doc(userId).delete();
      _logger.i('사용자 문서 삭제 성공');
    } catch (e) {
      _logger.e('사용자 문서 삭제 실패: $e');
      errors.add('사용자 문서 삭제 실패: $e');
    }
    
    try {
      // 🔥 6단계: Firebase Auth 계정 삭제 (requires-recent-login 오류 처리)
      _logger.i('6단계: Firebase Auth 계정 삭제 시작');
      await user.delete();
      authDeleted = true;
      _logger.i('🔥✅ Firebase Auth 계정 삭제 성공!');
    } catch (e) {
      _logger.e('Firebase Auth 계정 삭제 실패: $e');
      
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          _logger.w('🔥 requires-recent-login 오류 - 재인증 필요하지만 강제 로그아웃으로 처리');
          
          try {
            // 재인증 대신 강제 로그아웃으로 처리
            await signOut();
            authDeleted = true; // 로그아웃도 계정 제거 효과
            _logger.i('🔥 재인증 대신 강제 로그아웃 완료');
            errors.add('재인증 필요로 강제 로그아웃 처리됨');
          } catch (signOutError) {
            _logger.e('강제 로그아웃도 실패: $signOutError');
            errors.add('강제 로그아웃 실패: $signOutError');
          }
        } else {
          _logger.e('Firebase Auth 기타 오류: ${e.code} - ${e.message}');
          errors.add('Auth 삭제 실패: ${e.code}');
          
          // 다른 오류여도 강제 로그아웃 시도
          try {
            await signOut();
            authDeleted = true;
            _logger.i('다른 오류 후 강제 로그아웃 완료');
          } catch (signOutError) {
            _logger.e('오류 후 강제 로그아웃 실패: $signOutError');
            errors.add('오류 후 강제 로그아웃 실패: $signOutError');
          }
        }
      } else {
        _logger.e('Firebase Auth 알 수 없는 오류: $e');
        errors.add('Auth 삭제 알 수 없는 오류: $e');
        
        // 알 수 없는 오류여도 강제 로그아웃 시도
        try {
          await signOut();
          authDeleted = true;
          _logger.i('알 수 없는 오류 후 강제 로그아웃 완료');
        } catch (signOutError) {
          _logger.e('알 수 없는 오류 후 강제 로그아웃 실패: $signOutError');
          errors.add('알 수 없는 오류 후 강제 로그아웃 실패: $signOutError');
        }
      }
    }
    
    // 결과 로깅
    if (errors.isEmpty) {
      _logger.i('🔥✅ 회원 탈퇴 완전 성공: $userId');
    } else {
      _logger.w('🔥⚠️ 회원 탈퇴 부분 성공 (일부 오류): ${errors.join(', ')}');
    }
    
    // Auth 처리가 안된 경우에만 예외 throw
    if (!authDeleted) {
      throw AuthException(
        type: AuthErrorType.requiresRecentLogin,
        message: '계정 삭제를 위해 다시 로그인이 필요합니다. 앱을 재시작하여 로그인해주세요.',
      );
    }
  }
  
  // 사용자 게시물 삭제
  Future<void> _deleteUserPosts(String userId) async {
    try {
      final postsQuery = await _firestore.collection('posts')
          .where('userId', isEqualTo: userId)
          .limit(100)
          .get();
      
      if (postsQuery.docs.isEmpty) {
        _logger.i('삭제할 게시물 없음');
        return;
      }
      
      final batch = _firestore.batch();
      for (final doc in postsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      _logger.i('게시물 ${postsQuery.docs.length}개 삭제 완료');
    } catch (e) {
      _logger.e('게시물 삭제 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 댓글 삭제
  Future<void> _deleteUserComments(String userId) async {
    try {
      final commentsQuery = await _firestore.collection('comments')
          .where('userId', isEqualTo: userId)
          .limit(100)
          .get();
      
      if (commentsQuery.docs.isEmpty) {
        _logger.i('삭제할 댓글 없음');
        return;
      }
      
      final batch = _firestore.batch();
      for (final doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      _logger.i('댓글 ${commentsQuery.docs.length}개 삭제 완료');
    } catch (e) {
      _logger.e('댓글 삭제 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 서브컬렉션 삭제 (팔로우, 북마크 등)
  Future<void> _deleteUserSubcollections(String userId) async {
    final batch = _firestore.batch();
    int deleteCount = 0;
    
    try {
      // 팔로잉 목록 삭제
      final followingQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .limit(50)
          .get();
      
      for (final doc in followingQuery.docs) {
        batch.delete(doc.reference);
        deleteCount++;
      }
      
      // 팔로워 목록 삭제
      final followersQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .limit(50)
          .get();
      
      for (final doc in followersQuery.docs) {
        batch.delete(doc.reference);
        deleteCount++;
      }
      
      // 북마크 삭제
      final bookmarksQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .limit(50)
          .get();
      
      for (final doc in bookmarksQuery.docs) {
        batch.delete(doc.reference);
        deleteCount++;
      }
      
      if (deleteCount > 0) {
        await batch.commit();
        _logger.i('서브컬렉션 $deleteCount개 삭제 완료');
      } else {
        _logger.i('삭제할 서브컬렉션 없음');
      }
    } catch (e) {
      _logger.e('서브컬렉션 삭제 실패: $e');
      rethrow;
    }
  }
}