import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';

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
        case 'requires-recent-login':
          return AuthException(
            type: AuthErrorType.invalidCredential,
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
  final FirebaseStorage _storage; // 회원탈퇴 시 사용
  final GoogleSignIn _googleSignIn;
  final Logger _logger;

  AuthRepository({
    FirebaseAuth? auth, 
    FirebaseFirestore? firestore, 
    FirebaseStorage? storage,
    GoogleSignIn? googleSignIn, 
    Logger? logger
  })
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _logger = logger ?? Logger();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
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
      final now = DateTime.now(); // Timestamp를 DateTime으로 변경
      final newUser = UserModel(
        id: userId,
        name: name,
        username: username,
        email: _auth.currentUser?.email ?? '',  // null이면 빈 문자열 사용
        profileImageUrl: profileImageUrl,
        createdAt: now,  // DateTime 타입 사용
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
  
  // 구글 로그인
  Future<UserCredential> signInWithGoogle() async {
    try {
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
  
  // 로그아웃
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      _logger.e('로그아웃 실패: $e');
      throw AuthException(
        type: AuthErrorType.unknown,
        message: '로그아웃 중 오류가 발생했습니다.',
        originalError: e,
      );
    }
  }

  // 추가: 약관 동의 상태 업데이트 (수정된 부분)
  Future<void> updateTermsAgreement(String userId, bool agreed) async {
    try {
      // 문서가 존재하는지 먼저 확인
      final docRef = _firestore.collection('users').doc(userId);
      final docSnapshot = await docRef.get();
      
      final data = {
        'termsAgreed': agreed,
        'privacyAgreed': agreed,
        'agreementDate': FieldValue.serverTimestamp(),
      };
      
      if (docSnapshot.exists) {
        // 문서가 존재하면 업데이트
        await docRef.update(data);
      } else {
        // 문서가 존재하지 않으면 새로 생성
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

  // 추가: 프로필 완료 상태 업데이트
  Future<void> updateProfileComplete(String userId, bool complete) async {
    try {
      // 문서가 존재하는지 먼저 확인
      final docRef = _firestore.collection('users').doc(userId);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        // 문서가 존재하면 업데이트
        await docRef.update({
          'profileComplete': complete,
        });
      } else {
        // 문서가 존재하지 않으면 새로 생성
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

  // 회원 탈퇴 메서드 수정/확장
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) { 
        throw AuthException(
          type: AuthErrorType.userNotFound, 
          message: '로그인된 사용자가 없습니다.'
        ); 
      }
      
      _logger.i('회원 탈퇴 시작: ${user.uid}');
      
      // 배치 처리를 위한 객체 생성
      final batch = _firestore.batch();
      
      // 1. 사용자의 게시물 삭제
      try {
        final postsQuery = await _firestore.collection('posts').where('userId', isEqualTo: user.uid).get();
        _logger.i('삭제할 게시물 수: ${postsQuery.docs.length}');
        
        for (final doc in postsQuery.docs) {
          batch.delete(doc.reference);
          
          // 게시물의 이미지도 삭제 (비동기 실행)
          try {
            final postId = doc.id;
            final storageRef = _storage.ref().child('posts/$postId');
            
            try {
              final listResult = await storageRef.listAll();
              for (final item in listResult.items) {
                await item.delete();
              }
              _logger.i('게시물 이미지 삭제 성공: $postId');
            } catch (e) {
              _logger.e('게시물 이미지 목록 조회 실패: $e');
            }
          } catch (e) {
            _logger.e('게시물 이미지 삭제 실패 (계속 진행): $e');
          }
        }
      } catch (e) {
        _logger.e('게시물 삭제 실패 (계속 진행): $e');
      }
      
      // 2. 사용자의 댓글 삭제
      try {
        final commentsQuery = await _firestore.collection('comments').where('userId', isEqualTo: user.uid).get();
        _logger.i('삭제할 댓글 수: ${commentsQuery.docs.length}');
        
        for (final doc in commentsQuery.docs) {
          batch.delete(doc.reference);
        }
      } catch (e) {
        _logger.e('댓글 삭제 실패 (계속 진행): $e');
      }
      
      // 3. 사용자의 좋아요 삭제
      try {
        // 게시물 좋아요 삭제 - 검색 성능 이슈로 생략 가능
      } catch (e) {
        _logger.e('좋아요 삭제 실패 (계속 진행): $e');
      }
      
      // 4. 사용자의 팔로우/팔로워 관계 삭제
      try {
        final followingQuery = await _firestore.collection('users').doc(user.uid).collection('following').get();
        for (final doc in followingQuery.docs) {
          batch.delete(doc.reference);
          
          // 상대방의 팔로워 목록에서도 삭제
          try {
            final otherUserId = doc.id;
            batch.delete(_firestore.collection('users').doc(otherUserId).collection('followers').doc(user.uid));
          } catch (e) {
            _logger.e('상대방 팔로워 목록 수정 실패 (계속 진행): $e');
          }
        }
        
        final followersQuery = await _firestore.collection('users').doc(user.uid).collection('followers').get();
        for (final doc in followersQuery.docs) {
          batch.delete(doc.reference);
          
          // 상대방의 팔로잉 목록에서도 삭제
          try {
            final otherUserId = doc.id;
            batch.delete(_firestore.collection('users').doc(otherUserId).collection('following').doc(user.uid));
          } catch (e) {
            _logger.e('상대방 팔로잉 목록 수정 실패 (계속 진행): $e');
          }
        }
      } catch (e) {
        _logger.e('팔로우/팔로워 관계 삭제 실패 (계속 진행): $e');
      }
      
      // 5. 사용자의 채팅 삭제
      try {
        final chatsQuery = await _firestore.collection('chats').where('participants', arrayContains: user.uid).get();
        _logger.i('관련 채팅방 수: ${chatsQuery.docs.length}');
        
        for (final chatDoc in chatsQuery.docs) {
          // 채팅방 내 메시지 삭제
          final messagesQuery = await _firestore.collection('chats').doc(chatDoc.id).collection('messages').get();
          for (final msgDoc in messagesQuery.docs) {
            batch.delete(msgDoc.reference);
          }
          
          // 채팅방 자체 삭제
          batch.delete(chatDoc.reference);
        }
      } catch (e) {
        _logger.e('채팅 삭제 실패 (계속 진행): $e');
      }
      
      // 6. 프로필 이미지 삭제
      try {
        final profileImageRef = _storage.ref().child('profile_images/${user.uid}.jpg');
        await profileImageRef.delete();
        _logger.i('프로필 이미지 삭제 성공');
      } catch (e) {
        _logger.e('프로필 이미지 삭제 실패 (계속 진행): $e');
      }
      
      // 7. 사용자 프로필 문서 삭제
      batch.delete(_firestore.collection('profiles').doc(user.uid));
      
      // 8. 사용자 문서 삭제
      batch.delete(_firestore.collection('users').doc(user.uid));
      
      // 배치 커밋
      await batch.commit();
      _logger.i('Firebase 데이터 삭제 완료');
      
      // 9. Firebase Auth 계정 삭제
      await user.delete();
      _logger.i('계정 삭제 완료: ${user.uid}');
    } catch (e) {
      _logger.e('계정 삭제 실패: $e');
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw AuthException(
          type: AuthErrorType.invalidCredential, 
          message: '보안상의 이유로 다시 로그인한 후 계정을 삭제해주세요.', 
          originalError: e
        );
      }
      throw AuthErrorHandler.handleException(e);
    }
  }
}