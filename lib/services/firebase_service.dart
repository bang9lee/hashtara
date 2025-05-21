import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  // Firebase 인스턴스 가져오기
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static final FirebaseStorage storage = FirebaseStorage.instance;
  
  // Firestore 컬렉션 참조
  static final CollectionReference usersCollection = firestore.collection('users');
  static final CollectionReference profilesCollection = firestore.collection('profiles');
  static final CollectionReference postsCollection = firestore.collection('posts');
  static final CollectionReference chatsCollection = firestore.collection('chats');
  
  // Firebase 초기화 - App Check 포함
  static Future<void> initializeFirebase() async {
    try {
      // Firebase 기본 초기화
      await Firebase.initializeApp();
      
      // App Check 초기화
      await _initializeAppCheck();
      
      debugPrint('Firebase와 App Check 초기화 완료');
    } catch (e) {
      debugPrint('Firebase 초기화 중 오류 발생: $e');
      rethrow;
    }
  }
  
  // App Check 초기화 메서드
  static Future<void> _initializeAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        // 디버그 모드에서는 디버그 공급자 사용, 릴리스 모드에서는 실제 공급자 사용
        androidProvider: kDebugMode 
          ? AndroidProvider.debug 
          : AndroidProvider.playIntegrity,
        // 웹 공급자 설정 (필요한 경우)
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      );
      
      debugPrint('Firebase App Check 활성화 완료: ${kDebugMode ? '디버그 모드' : '프로덕션 모드'}');
    } catch (e) {
      debugPrint('Firebase App Check 활성화 실패: $e');
      // App Check 실패는 치명적이지 않을 수 있으므로 예외를 다시 던지지 않음
      // 하지만 로그는 남김
    }
  }
  
  // Firestore 설정
  static Future<void> setupFirestore() async {
    // 인덱스 설정 등이 필요할 경우
  }
  
  // 현재 로그인한 사용자 ID 가져오기 (유틸리티 함수)
  static String? get currentUserId {
    return auth.currentUser?.uid;
  }
  
  // Firestore 캐시 정리 (로그아웃 시 유용)
  static Future<void> clearFirestoreCache() async {
    try {
      await firestore.terminate();
      await firestore.clearPersistence();
      debugPrint('Firestore 캐시 정리 완료');
    } catch (e) {
      debugPrint('Firestore 캐시 정리 실패: $e');
    }
  }
  
  // Firebase Storage 캐시 정리 유틸리티 (필요한 경우)
  static Future<void> clearStorageCache() async {
    try {
      // Storage는 앱 캐시를 직접 관리하지 않지만,
      // 필요한 경우 여기에 구현 가능
      debugPrint('Storage 캐시 정리 메서드 호출됨');
    } catch (e) {
      debugPrint('Storage 캐시 정리 실패: $e');
    }
  }
}