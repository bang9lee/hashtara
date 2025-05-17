import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../services/firebase_service.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseService.storage;
  final Uuid _uuid = const Uuid();
  
  // 프로필 이미지 업로드
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('프로필 이미지 업로드 중 오류가 발생했습니다: $e');
    }
  }
  
  // 게시물 이미지 업로드
  Future<String> uploadPostImage(String userId, File imageFile) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage
          .ref()
          .child('post_images')
          .child(userId)
          .child(fileName);
          
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('게시물 이미지 업로드 중 오류가 발생했습니다: $e');
    }
  }
  
  // 메시지 이미지 업로드
  Future<String> uploadMessageImage(String chatId, File imageFile) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage
          .ref()
          .child('message_images')
          .child(chatId)
          .child(fileName);
          
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('메시지 이미지 업로드 중 오류가 발생했습니다: $e');
    }
  }
  
  // 이미지 삭제
  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('이미지 삭제 중 오류가 발생했습니다: $e');
    }
  }
}