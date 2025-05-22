import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import '../models/user_model.dart';
import '../repositories/profile_repository.dart';
import 'auth_provider.dart';
import 'package:flutter/material.dart';

// 프로필 저장소 프로바이더 (단일 인스턴스)
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

// 사용자 정보 프로바이더 (UserModel - ID로 조회)
// auth_provider.dart에서 이동됨
final getUserProfileProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  final repository = ref.watch(authRepositoryProvider);
  return repository.getUserProfile(userId);
});

// 현재 사용자의 ProfileModel 프로바이더
final userProfileModelProvider = FutureProvider<ProfileModel?>((ref) async {
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

// 프로필 관리 컨트롤러
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

// ProfileController 클래스
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
  
  // 프로필 업데이트
  Future<void> updateProfile({
    required String userId,
    String? bio,
    List<String>? interests,
    String? location,
    List<String>? favoriteHashtags,
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
          favoriteHashtags: favoriteHashtags,
        );
        
        await _repository.updateProfile(newProfile);
        state = AsyncValue.data(newProfile);
      }
      
      // 관련 프로바이더 갱신
      _ref.invalidate(userProfileModelProvider);
      _ref.invalidate(getUserProfileProvider(userId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  // 프로필 이미지 업로드
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      final imageUrl = await _repository.uploadProfileImage(userId, imageFile);
      
      // 관련 프로바이더 갱신
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(getUserProfileProvider(userId));
      
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
      _ref.invalidate(userFollowersProvider(followingId));
      _ref.invalidate(userFollowingProvider(followerId));
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
      _ref.invalidate(userFollowersProvider(followingId));
      _ref.invalidate(userFollowingProvider(followerId));
    } catch (e) {
      debugPrint('언팔로우 실패: $e');
      rethrow;
    }
  }
}