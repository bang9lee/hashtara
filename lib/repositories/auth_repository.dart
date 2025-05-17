// auth_repository.dart 파일

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Logger _logger = Logger();
  
  // 현재 로그인한 사용자 정보
  User? get currentUser => _auth.currentUser;
  
  // 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
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
    } catch (e) {
      _logger.e('로그인 실패: $e');
      rethrow;
    }
  }
  
  // 구글 로그인
  Future<UserCredential> signInWithGoogle() async {
    try {
      // 구글 로그인 다이얼로그 표시
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // 로그인 취소된 경우
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }
      
      // 구글 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 파이어베이스 인증 정보 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // 파이어베이스 로그인
      final userCredential = await _auth.signInWithCredential(credential);
      
      // 신규 사용자의 경우 Firestore에 데이터 생성
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      _logger.e('구글 로그인 실패: $e');
      rethrow;
    }
  }
  
  // 이메일/비밀번호로 회원가입 - 함수 시그니처 변경 (UserCredential 대신 User 반환)
  Future<User?> signUpWithEmailAndPassword(
    String email, 
    String password,
  ) async {
    try {
      _logger.i('회원가입 시도: $email');
      
      // 회원가입 전에 기존 로그인된 사용자 로그아웃
      if (_auth.currentUser != null) {
        await _auth.signOut();
        _logger.i('기존 로그인된 사용자 로그아웃 처리');
      }
      
      try {
        // 회원가입 시도
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        _logger.i('Firebase 인증 성공: ${credential.user?.uid}');
        
        // 사용자 문서 생성
        if (credential.user != null) {
          await _createUserDocument(credential.user!);
          
          // 명시적 업데이트는 제거 - 이미 _createUserDocument에서 profileComplete: false로 설정됨
          _logger.i('사용자 문서 생성 완료');
        }
        
        return credential.user;
      } catch (e) {
        _logger.e('Firebase 인증 오류: $e');
        
        // PigeonUserDetails 문제 발생시 추가 로직
        if (e.toString().contains('PigeonUserDetails') || 
            e.toString().contains('List<Object?>')) {
          
          // 약간 대기 후 현재 사용자 확인
          await Future.delayed(const Duration(milliseconds: 800));
          final currentUser = _auth.currentUser;
          
          if (currentUser != null && currentUser.email == email) {
            _logger.i('사용자가 이미 생성됨: ${currentUser.uid}');
            
            // 사용자 문서 생성
            await _createUserDocument(currentUser);
            
            _logger.i('사용자 문서 생성 완료');
            return currentUser;
          }
          
          // 사용자가 존재하지 않아 로그인 재시도
          try {
            final signInResult = await _auth.signInWithEmailAndPassword(
              email: email,
              password: password
            );
            
            _logger.i('대체 로그인 성공: ${signInResult.user?.uid}');
            
            if (signInResult.user != null) {
              await _createUserDocument(signInResult.user!);
            }
            
            return signInResult.user;
          } catch (signInErr) {
            _logger.e('대체 로그인 실패: $signInErr');
            throw Exception('회원가입 후 로그인에 실패했습니다.');
          }
        }
        
        // 기타 오류는 그대로 전달
        rethrow;
      }
    } catch (e, stack) {
      _logger.e('회원가입 전체 실패: $e\n$stack');
      rethrow;
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    try {
      // 구글 로그인 로그아웃
      await _googleSignIn.signOut();
      // 파이어베이스 로그아웃
      await _auth.signOut();
      _logger.i('로그아웃 성공');
    } catch (e) {
      _logger.e('로그아웃 실패: $e');
      rethrow;
    }
  }
  
  // Firestore에 사용자 문서 생성
  Future<void> _createUserDocument(User user) async {
    try {
      final userModel = UserModel(
        id: user.uid,
        email: user.email!,
        name: user.displayName,  // 구글 로그인 시 이름이 있을 수 있음
        profileImageUrl: user.photoURL,  // 구글 로그인 시 프로필 사진이 있을 수 있음
        createdAt: DateTime.now(),
      );
      
      // 명시적 로그 추가
      _logger.i('사용자 문서 생성 시작: profileComplete를 false로 설정');
      
      // 사용자 문서 생성 시 profileComplete 필드를 명시적으로 false로 설정
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
            ...userModel.toMap(),
            'profileComplete': false, // 명시적으로 false로 설정
          });
      
      _logger.i('기본 사용자 문서 생성 완료: ${user.uid}, profileComplete: false');
    } catch (e) {
      _logger.e('사용자 문서 생성 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 문서 명시적 생성/수정
  Future<void> createUserDocument(
    String userId,
    String name,
    String username,
    String? profileImageUrl,
  ) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      _logger.i('createUserDocument 호출됨: userId=$userId, 문서 존재=${userDoc.exists}');
      
      if (userDoc.exists) {
        // 문서가 이미 존재하면 업데이트
        await _firestore.collection('users').doc(userId).update({
          'name': name,
          'username': username,
          'profileComplete': true, // 프로필이 완료되었음을 표시
          if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        });
        _logger.i('사용자 문서 업데이트 완료: $userId, profileComplete: true');
      } else {
        // 문서가 없으면 새로 생성
        final userModel = UserModel(
          id: userId,
          email: currentUser?.email ?? "",
          name: name,
          username: username,
          profileImageUrl: profileImageUrl,
          createdAt: DateTime.now(),
        );
        
        await _firestore
            .collection('users')
            .doc(userId)
            .set({
              ...userModel.toMap(),
              'profileComplete': false, // 이쪽부분을 ture -> fales 변경하니 회원가입후 프로필설정창이 나타남
            });
        
        _logger.i('사용자 문서 신규 생성 완료: $userId, profileComplete: true');
      }
    } catch (e) {
      _logger.e("사용자 문서 생성/업데이트 오류: $e");
      rethrow;
    }
  }
  
  // 사용자 프로필 가져오기
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _logger.e('사용자 프로필 조회 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 프로필 업데이트
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .update({
            ...user.toMap(),
            'profileComplete': true, // 프로필이 완료되었음을 표시
          });
      
      _logger.i('사용자 프로필 업데이트 완료: ${user.id}');
    } catch (e) {
      _logger.e('사용자 프로필 업데이트 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 프로필 설정 완료 여부 확인
  Future<bool> isProfileComplete(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final profileComplete = doc.data()?['profileComplete'];
      
      _logger.i('프로필 완료 상태 확인: userId=$userId, profileComplete=$profileComplete');
      
      return profileComplete == true;
    } catch (e) {
      _logger.e('프로필 완료 상태 확인 실패: $e');
      return false;
    }
  }
}