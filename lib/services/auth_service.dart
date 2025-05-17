import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;
  
  // 현재 로그인한 사용자
  User? get currentUser => _auth.currentUser;
  
  // 인증 상태 변경 스트림
  Stream<User?> authStateChanges() => _auth.authStateChanges();
  
  // 이메일/비밀번호로 로그인
  Future<UserCredential> signInWithEmailAndPassword(
    String email, 
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('로그인 중 오류가 발생했습니다.');
    }
  }
  
  // 이메일/비밀번호로 회원가입
  Future<UserCredential> signUpWithEmailAndPassword(
    String email, 
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('회원가입 중 오류가 발생했습니다.');
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('비밀번호 재설정 이메일 전송 중 오류가 발생했습니다.');
    }
  }
  
  // Firebase 인증 예외 처리
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return Exception('이메일 형식이 올바르지 않습니다.');
      case 'user-disabled':
        return Exception('해당 사용자 계정이 비활성화되었습니다.');
      case 'user-not-found':
        return Exception('해당 이메일로 등록된 사용자가 없습니다.');
      case 'wrong-password':
        return Exception('비밀번호가 올바르지 않습니다.');
      case 'email-already-in-use':
        return Exception('이미 사용 중인 이메일입니다.');
      case 'operation-not-allowed':
        return Exception('이 작업은 허용되지 않습니다.');
      case 'weak-password':
        return Exception('비밀번호가 너무 약합니다.');
      default:
        return Exception('인증 중 오류가 발생했습니다: ${e.message}');
    }
  }
}