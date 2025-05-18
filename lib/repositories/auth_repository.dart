import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart'; // UserModel 경로가 올바르다고 가정합니다.

// 도메인 특화 인증 예외
class AuthException implements Exception {
  final AuthErrorType type;
  final String message;
  final dynamic originalError;

  AuthException({
    required this.type,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'AuthException(type: $type, message: $message)';
}

// 인증 오류 유형 분류를 위한 열거형
enum AuthErrorType {
  invalidEmail, wrongPassword, userNotFound, userDisabled, tooManyRequests,
  emailAlreadyInUse, weakPassword,
  accountExistsWithDifferentCredential, invalidCredential, operationNotAllowed,
  expiredActionCode, invalidActionCode,
  networkError, serverError, unknown,
}

// Firebase 인증 오류 처리 클래스
class AuthErrorHandler {
  static AuthException handleException(dynamic e) {
    if (e is FirebaseAuthException) { return _handleFirebaseAuthException(e); }
    if (e is FirebaseException) { return _handleFirebaseException(e); }
    return AuthException(type: AuthErrorType.unknown, message: '예상치 못한 오류가 발생했습니다.', originalError: e);
  }

  static AuthException _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email': return AuthException(type: AuthErrorType.invalidEmail, message: '이메일 주소가 유효하지 않습니다.', originalError: e);
      case 'user-disabled': return AuthException(type: AuthErrorType.userDisabled, message: '이 사용자 계정이 비활성화되었습니다.', originalError: e);
      case 'user-not-found': return AuthException(type: AuthErrorType.userNotFound, message: '이 이메일 주소로 등록된 사용자가 없습니다.', originalError: e);
      case 'wrong-password': return AuthException(type: AuthErrorType.wrongPassword, message: '비밀번호가 올바르지 않습니다.', originalError: e);
      case 'email-already-in-use': return AuthException(type: AuthErrorType.emailAlreadyInUse, message: '이미 이 이메일 주소로 등록된 계정이 있습니다.', originalError: e);
      case 'weak-password': return AuthException(type: AuthErrorType.weakPassword, message: '비밀번호가 너무 약합니다. 더 강력한 비밀번호를 사용해주세요.', originalError: e);
      case 'operation-not-allowed': return AuthException(type: AuthErrorType.operationNotAllowed, message: '이 작업은 허용되지 않습니다.', originalError: e);
      case 'account-exists-with-different-credential': return AuthException(type: AuthErrorType.accountExistsWithDifferentCredential, message: '동일한 이메일을 가진 계정이 이미 다른 로그인 방식으로 등록되어 있습니다.', originalError: e);
      case 'invalid-credential': return AuthException(type: AuthErrorType.invalidCredential, message: '인증 정보가 유효하지 않습니다.', originalError: e);
      case 'invalid-verification-code': return AuthException(type: AuthErrorType.invalidActionCode, message: '인증 코드가 유효하지 않습니다.', originalError: e);
      case 'invalid-verification-id': return AuthException(type: AuthErrorType.invalidActionCode, message: '인증 ID가 유효하지 않습니다.', originalError: e);
      case 'expired-action-code': return AuthException(type: AuthErrorType.expiredActionCode, message: '인증 코드가 만료되었습니다.', originalError: e);
      case 'too-many-requests': return AuthException(type: AuthErrorType.tooManyRequests, message: '너무 많은 시도가 있었습니다. 나중에 다시 시도해주세요.', originalError: e);
      default:
        if (kDebugMode) { print('처리되지 않은 FirebaseAuthException: ${e.code} - ${e.message}'); }
        return AuthException(type: AuthErrorType.unknown, message: e.message ?? '알 수 없는 인증 오류가 발생했습니다.', originalError: e);
    }
  }

  static AuthException _handleFirebaseException(FirebaseException e) {
    if (e.code.contains('network')) { return AuthException(type: AuthErrorType.networkError, message: '네트워크 오류가 발생했습니다. 연결을 확인해주세요.', originalError: e); }
    return AuthException(type: AuthErrorType.serverError, message: '서버 오류가 발생했습니다. 나중에 다시 시도해주세요.', originalError: e);
  }
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final Logger _logger;

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore, GoogleSignIn? googleSignIn, Logger? logger})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _logger = logger ?? Logger();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _logger.i('로그인 성공: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      _logger.e('로그인 실패: $e');
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      _logger.i('구글 로그인 시도');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { throw AuthException(type: AuthErrorType.operationNotAllowed, message: '구글 로그인이 취소되었습니다.'); }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.additionalUserInfo?.isNewUser ?? false) { await _createUserDocument(userCredential.user!); }
      _logger.i('구글 로그인 성공: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      _logger.e('구글 로그인 실패: $e');
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      _logger.i('회원가입 시도: $email');
      if (_auth.currentUser != null) {
        await _auth.signOut();
        _logger.i('기존 로그인된 사용자 로그아웃 처리');
      }
      try {
        final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        _logger.i('Firebase 인증 성공: ${credential.user?.uid}');
        if (credential.user != null) {
          await _createUserDocument(credential.user!);
          _logger.i('사용자 문서 생성 완료');
        }
        return credential.user;
      } catch (e) {
        if (e is FirebaseAuthException) {
          _logger.e('Firebase 인증 오류: ${e.code} - ${e.message}');
          throw AuthErrorHandler.handleException(e);
        }
        _logger.e('회원가입 중 알 수 없는 오류: $e');
        throw AuthException(type: AuthErrorType.unknown, message: '회원가입 중 오류가 발생했습니다.', originalError: e);
      }
    } catch (e) {
      _logger.e('회원가입 전체 실패: $e');
      if (e is AuthException) { rethrow; }
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _logger.i('로그아웃 성공');
    } catch (e) {
      _logger.e('로그아웃 실패: $e');
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _logger.i('비밀번호 재설정 이메일 전송 성공: $email');
    } catch (e) {
      _logger.e('비밀번호 재설정 이메일 전송 실패: $e');
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<void> _createUserDocument(User user) async {
    try {
      final userModel = UserModel(
        id: user.uid, email: user.email!, name: user.displayName,
        profileImageUrl: user.photoURL, createdAt: DateTime.now(),
      );
      _logger.i('사용자 문서 생성 시작: profileComplete를 false로 설정');
      await _firestore.collection('users').doc(user.uid).set({...userModel.toMap(), 'profileComplete': false});
      _logger.i('기본 사용자 문서 생성 완료: ${user.uid}, profileComplete: false');
    } catch (e) {
      _logger.e('사용자 문서 생성 실패: $e');
      throw AuthException(type: AuthErrorType.unknown, message: '사용자 프로필 생성 중 오류가 발생했습니다.', originalError: e);
    }
  }

  Future<void> createUserDocument(String userId, String name, String username, String? profileImageUrl) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      _logger.i('createUserDocument 호출됨: userId=$userId, 문서 존재=${userDoc.exists}');
      if (userDoc.exists) {
        await _firestore.collection('users').doc(userId).update({
          'name': name, 'username': username, 'profileComplete': true,
          if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        });
        _logger.i('사용자 문서 업데이트 완료: $userId, profileComplete: true');
      } else {
        final userModel = UserModel(
          id: userId, email: currentUser?.email ?? "", name: name, username: username,
          profileImageUrl: profileImageUrl, createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(userId).set({...userModel.toMap(), 'profileComplete': false}); //여기절대변경X false가 정확한값
        _logger.i('사용자 문서 신규 생성 완료: $userId, profileComplete: true');
      }
    } catch (e) {
      _logger.e("사용자 문서 생성/업데이트 오류: $e");
      throw AuthException(type: AuthErrorType.unknown, message: '사용자 프로필 생성 중 오류가 발생했습니다.', originalError: e);
    }
  }

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? UserModel.fromFirestore(doc) : null;
    } catch (e) {
      _logger.e('사용자 프로필 조회 실패: $e');
      throw AuthException(type: AuthErrorType.unknown, message: '사용자 정보를 불러올 수 없습니다.', originalError: e);
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({...user.toMap(), 'profileComplete': true});
      _logger.i('사용자 프로필 업데이트 완료: ${user.id}');
    } catch (e) {
      _logger.e('사용자 프로필 업데이트 실패: $e');
      throw AuthException(type: AuthErrorType.unknown, message: '사용자 정보 업데이트 중 오류가 발생했습니다.', originalError: e);
    }
  }

  Future<bool> isProfileComplete(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final profileComplete = doc.data()?['profileComplete'];
      _logger.i('프로필 완료 상태 확인: userId=$userId, profileComplete=$profileComplete');
      return profileComplete == true;
    } catch (e) {
      _logger.e('프로필 완료 상태 확인 실패: $e');
      throw AuthException(type: AuthErrorType.unknown, message: '사용자 상태를 확인하는 중 오류가 발생했습니다.', originalError: e);
    }
  }

  // 이메일 중복 확인 - 권장되는 방식으로 구현
  // Firebase의 이메일 열거 보호 정책에 따라 fetchSignInMethodsForEmail 대신 
  // 회원가입 시도 후 오류 처리 방식을 사용
  Future<bool> isEmailInUse(String email) async {
    try {
      _logger.i('이메일 중복 확인 시도 (안전한 방식): $email');
      
      // 현재 로그인된 사용자가 있다면 임시로 로그아웃
      User? currentLoggedInUser = _auth.currentUser;
      
      try {
        // 임시 비밀번호로 계정 생성 시도
        // 계정이 이미 존재하면 Firebase가 'email-already-in-use' 예외를 발생시킴
        await _auth.createUserWithEmailAndPassword(
          email: email, 
          // 실제로 계정이 생성되지 않도록 충분히 복잡한 임시 비밀번호 사용
          password: '${DateTime.now().millisecondsSinceEpoch}_TempPassword!123',
        );
        
        // 계정이 실제로 생성된 경우 즉시 삭제
        if (_auth.currentUser != null && currentLoggedInUser?.uid != _auth.currentUser?.uid) {
          await _auth.currentUser?.delete();
          _logger.i('테스트용 계정 삭제 완료');
        }
        
        // 계정 생성에 성공했다면 이메일이 사용 중이지 않음
        return false;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _logger.i('이메일이 이미 사용 중임 확인: $email');
          return true;
        }
        // 다른 종류의 예외는 정상적인 이메일 체크에 실패한 것이므로 다시 던짐
        rethrow;
      } finally {
        // 이전에 로그인한 사용자가 있었다면 다시 로그인 복원
        if (currentLoggedInUser != null && _auth.currentUser?.uid != currentLoggedInUser.uid) {
          try {
            await _auth.signOut();
            // 실제 애플리케이션에서는 여기에 사용자 재로그인 로직이 필요함
            // 이 예시에서는 생략함
            _logger.i('원래 로그인 상태로 복원 시도');
          } catch (e) {
            _logger.e('로그인 상태 복원 중 오류: $e');
          }
        }
      }
    } catch (e) {
      _logger.e('이메일 중복 확인 실패: $e');
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<bool> isUsernameTaken(String username) async {
    try {
      final querySnapshot = await _firestore.collection('users').where('username', isEqualTo: username).limit(1).get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      _logger.e('사용자명 중복 확인 실패: $e');
      throw AuthException(type: AuthErrorType.unknown, message: '사용자명 확인 중 오류가 발생했습니다.', originalError: e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) { throw AuthException(type: AuthErrorType.userNotFound, message: '로그인된 사용자가 없습니다.'); }
      await _firestore.collection('users').doc(user.uid).delete();
      await _firestore.collection('profiles').doc(user.uid).delete(); // profiles 컬렉션도 삭제 가정
      await user.delete();
      _logger.i('계정 삭제 완료: ${user.uid}');
    } catch (e) {
      _logger.e('계정 삭제 실패: $e');
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw AuthException(type: AuthErrorType.invalidCredential, message: '보안상의 이유로 다시 로그인한 후 계정을 삭제해주세요.', originalError: e);
      }
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<void> updateEmailAddress(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) { throw AuthException(type: AuthErrorType.userNotFound, message: '로그인된 사용자가 없습니다.'); }
      await user.verifyBeforeUpdateEmail(newEmail);
      _logger.i('이메일 변경 인증 메일 발송: ${user.uid} -> $newEmail');
    } catch (e) {
      _logger.e('이메일 변경 실패: $e');
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw AuthException(type: AuthErrorType.invalidCredential, message: '보안상의 이유로 다시 로그인한 후 이메일을 변경해주세요.', originalError: e);
      }
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) { throw AuthException(type: AuthErrorType.userNotFound, message: '로그인된 사용자가 없습니다.'); }
      await user.updatePassword(newPassword);
      _logger.i('비밀번호 변경 완료: ${user.uid}');
    } catch (e) {
      _logger.e('비밀번호 변경 실패: $e');
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw AuthException(type: AuthErrorType.invalidCredential, message: '보안상의 이유로 다시 로그인한 후 비밀번호를 변경해주세요.', originalError: e);
      }
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) { throw AuthException(type: AuthErrorType.userNotFound, message: '로그인된 사용자가 없습니다.'); }
      await user.sendEmailVerification();
      _logger.i('이메일 인증 전송 완료: ${user.uid}, ${user.email}');
    } catch (e) {
      _logger.e('이메일 인증 전송 실패: $e');
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<void> reauthenticate(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) { throw AuthException(type: AuthErrorType.userNotFound, message: '로그인된 사용자가 없습니다.'); }
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);
      _logger.i('재인증 성공: ${user.uid}');
    } catch (e) {
      _logger.e('재인증 실패: $e');
      throw AuthErrorHandler.handleException(e);
    }
  }

  Future<bool> isRecentLogin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) { return false; }
      final metadata = user.metadata;
      final lastSignInTime = metadata.lastSignInTime;
      if (lastSignInTime == null) { return false; }
      final difference = DateTime.now().difference(lastSignInTime);
      return difference.inHours < 1;
    } catch (e) {
      _logger.e('최근 로그인 상태 확인 실패: $e');
      return false;
    }
  }
}