import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  
  // Firebase 초기화
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
  }
  
  // Firestore 설정
  static Future<void> setupFirestore() async {
    // 인덱스 설정 등이 필요할 경우
  }
  
  // 현재 로그인한 사용자 ID 가져오기 (유틸리티 함수)
  static String? get currentUserId {
    return auth.currentUser?.uid;
  }
}