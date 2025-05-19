import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import '../models/user_model.dart';
import '../repositories/profile_repository.dart'; // 올바른 임포트 경로로 수정
import 'auth_provider.dart' hide getUserProfileProvider; // 충돌 해결을 위해 제외
import 'package:flutter/material.dart';

// 프로필 저장소 프로바이더
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

// 사용자 정보 프로바이더 (ID로) - auth_provider.dart와 중복되지 않도록 이름 변경
final getProfileProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  try {
    final repository = ref.read(profileRepositoryProvider);
    return await repository.getUserById(userId);
  } catch (e) {
    debugPrint('사용자 프로필 조회 오류: $e');
    return null;
  }
});

// 현재 사용자 프로필 프로바이더
final userProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user != null) {
        return repository.getProfile(user.uid);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// 프로필 관리 프로바이더
final profileControllerProvider = StateNotifierProvider<ProfileController, AsyncValue<ProfileModel?>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileController(repository, ref);
});

// 사용자 팔로잉 목록 프로바이더
final userFollowingProvider = FutureProvider.family<List<UserModel>, String>((ref, userId) async {
  try {
    final repository = ref.read(profileRepositoryProvider);
    return await repository.getFollowing(userId);
  } catch (e) {
    debugPrint('팔로잉 목록 조회 오류: $e');
    return [];
  }
});

// 사용자 팔로워 목록 프로바이더
final userFollowersProvider = FutureProvider.family<List<UserModel>, String>((ref, userId) async {
  try {
    final repository = ref.read(profileRepositoryProvider);
    return await repository.getFollowers(userId);
  } catch (e) {
    debugPrint('팔로워 목록 조회 오류: $e');
    return [];
  }
});

class ProfileController extends StateNotifier<AsyncValue<ProfileModel?>> {
  final ProfileRepository _repository;
  final Ref _ref;
  
  ProfileController(this._repository, this._ref) : super(const AsyncValue.loading());
  
  // 프로필 로드
  Future<void> loadProfile(String userId) async {
    state = const AsyncValue.loading();
    
    try {
      // 1. 먼저 프로필 조회
      var profile = await _repository.getProfile(userId);
      
      // 2. 프로필이 없으면 자동으로 생성
      if (profile == null) {
        debugPrint('프로필이 없어 새로 생성합니다: $userId');
        await _repository.createProfileDocument(userId, null);
        profile = await _repository.getProfile(userId);
      }
      
      // 3. 게시물 수 확인 및 업데이트
      profile = await _syncPostCount(userId, profile);
      
      state = AsyncValue.data(profile);
    } catch (e, stack) {
      debugPrint('프로필 로드 실패: $e');
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 게시물 수 동기화
  Future<ProfileModel?> _syncPostCount(String userId, ProfileModel? profile) async {
    try {
      if (profile != null) {
        // 게시물 수 확인
        final postsCount = await _repository.getUserPostsCount(userId);
        
        // 게시물 수가 다르면 업데이트
        if (profile.postCount != postsCount) {
          debugPrint('게시물 수 업데이트: ${profile.postCount} -> $postsCount');
          
          final updatedProfile = profile.copyWith(postCount: postsCount);
          await _repository.updateProfile(updatedProfile);
          return updatedProfile;
        }
      }
      return profile;
    } catch (e) {
      debugPrint('게시물 수 동기화 실패: $e');
      return profile;
    }
  }
  
  // 프로필 업데이트 (해시태그 필드 추가)
  Future<void> updateProfile({
    required String userId,
    String? bio,
    List<String>? interests,
    String? location,
    List<String>? favoriteHashtags, // 좋아하는 해시태그 필드 추가
  }) async {
    try {
      final currentProfile = state.value;
      
      if (currentProfile != null) {
        final updatedProfile = currentProfile.copyWith(
          bio: bio,
          interests: interests,
          location: location,
          favoriteHashtags: favoriteHashtags,
        );
        
        await _repository.updateProfile(updatedProfile);
        state = AsyncValue.data(updatedProfile);
      } else {
        final newProfile = ProfileModel(
          userId: userId,
          bio: bio,
          interests: interests,
          location: location,
          postCount: 0,
          followersCount: 0,
          followingCount: 0,
          favoriteHashtags: favoriteHashtags, // 해시태그 저장
        );
        
        await _repository.updateProfile(newProfile);
        state = AsyncValue.data(newProfile);
      }
      
      // 관련 프로바이더 갱신
      debugPrint('Provider 갱신 완료: ${_ref.refresh(userProfileProvider).hashCode}');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 프로필 이미지 업로드
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      final imageUrl = await _repository.uploadProfileImage(userId, imageFile);
      
      // 관련 프로바이더 갱신
      debugPrint('Provider 갱신 완료: ${_ref.refresh(currentUserProvider).hashCode}, ${_ref.refresh(getProfileProvider(userId)).hashCode}');
      
      return imageUrl;
    } catch (e) {
      debugPrint('프로필 이미지 업로드 실패: $e');
      return null;
    }
  }
  
  // 팔로우 상태 확인
  Future<bool> checkIfFollowing(String followerId, String followingId) async {
    try {
      return await _repository.checkIfFollowing(followerId, followingId);
    } catch (e) {
      debugPrint('팔로우 상태 확인 실패: $e');
      return false;
    }
  }
  
  // 사용자 팔로우
  Future<void> followUser(String followerId, String followingId) async {
    try {
      await _repository.followUser(followerId, followingId);
      
      // 프로필 상태 다시 로드
      await loadProfile(followingId);
      
      // 관련 프로바이더 갱신
      debugPrint('팔로워 목록 갱신: ${_ref.refresh(userFollowersProvider(followingId)).hashCode}');
      debugPrint('팔로잉 목록 갱신: ${_ref.refresh(userFollowingProvider(followerId)).hashCode}');
    } catch (e) {
      debugPrint('팔로우 실패: $e');
      rethrow;
    }
  }
  
  // 사용자 언팔로우
  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      await _repository.unfollowUser(followerId, followingId);
      
      // 프로필 상태 다시 로드
      await loadProfile(followingId);
      
      // 관련 프로바이더 갱신
      debugPrint('팔로워 목록 갱신: ${_ref.refresh(userFollowersProvider(followingId)).hashCode}');
      debugPrint('팔로잉 목록 갱신: ${_ref.refresh(userFollowingProvider(followerId)).hashCode}');
    } catch (e) {
      debugPrint('언팔로우 실패: $e');
      rethrow;
    }
  }
}