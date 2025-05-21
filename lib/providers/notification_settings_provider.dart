import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

// 알림 설정 상태를 관리하는 프로바이더
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, AsyncValue<Map<String, bool>>>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return NotificationSettingsNotifier(notificationService);
});

class NotificationSettingsNotifier extends StateNotifier<AsyncValue<Map<String, bool>>> {
  final NotificationService _notificationService;
  
  NotificationSettingsNotifier(this._notificationService) : super(const AsyncValue.loading()) {
    _loadSettings();
  }
  
  // 알림 설정 로드
  Future<void> _loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final prefs = await SharedPreferences.getInstance();
      
      // 기본 알림 설정 정의
      final Map<String, bool> settings = {
        'all_notifications': prefs.getBool('all_notifications') ?? true,
        'comment_notifications': prefs.getBool('comment_notifications') ?? true,
        'like_notifications': prefs.getBool('like_notifications') ?? true,
        'follow_notifications': prefs.getBool('follow_notifications') ?? true,
        'message_notifications': prefs.getBool('message_notifications') ?? true,
      };
      
      state = AsyncValue.data(settings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      debugPrint('알림 설정 로드 실패: $e');
    }
  }
  
  // 모든 알림 설정 변경
  Future<void> setAllNotifications(bool value) async {
    try {
      final currentSettings = state.value ?? {};
      final updatedSettings = Map<String, bool>.from(currentSettings);
      
      // 모든 알림 설정 업데이트
      updatedSettings['all_notifications'] = value;
      
      // 모든 알림이 비활성화된 경우 하위 설정도 비활성화
      if (!value) {
        updatedSettings['comment_notifications'] = false;
        updatedSettings['like_notifications'] = false;
        updatedSettings['follow_notifications'] = false;
        updatedSettings['message_notifications'] = false;
        
        // FCM 토큰 제거 (알림 비활성화)
        await _notificationService.deleteToken();
      }
      
      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      for (final entry in updatedSettings.entries) {
        await prefs.setBool(entry.key, entry.value);
      }
      
      state = AsyncValue.data(updatedSettings);
    } catch (e, stackTrace) {
      debugPrint('알림 설정 변경 실패: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  // 특정 알림 설정 변경
  Future<void> setNotificationSetting(String key, bool value) async {
    try {
      if (state.value == null) return;
      
      final currentSettings = Map<String, bool>.from(state.value!);
      currentSettings[key] = value;
      
      // 하위 알림 중 하나라도 활성화되었을 때 모든 알림도 활성화
      if (value && 
          (key == 'comment_notifications' || 
           key == 'like_notifications' || 
           key == 'follow_notifications' || 
           key == 'message_notifications')) {
        currentSettings['all_notifications'] = true;
        
        // FCM 토큰 설정 (알림 활성화)
        // _setupFCMToken 대신 public 메소드인 setupFCMToken 사용
        await _notificationService.setupFCMToken();
      }
      
      // 모든 하위 설정이 비활성화되었는지 확인
      if (!value && 
          !currentSettings['comment_notifications']! && 
          !currentSettings['like_notifications']! && 
          !currentSettings['follow_notifications']! && 
          !currentSettings['message_notifications']!) {
        currentSettings['all_notifications'] = false;
        
        // FCM 토큰 제거 (알림 비활성화)
        await _notificationService.deleteToken();
      }
      
      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      await prefs.setBool('all_notifications', currentSettings['all_notifications']!);
      
      state = AsyncValue.data(currentSettings);
    } catch (e, stackTrace) {
      debugPrint('알림 설정 변경 실패: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  // 알림 설정 초기화
  Future<void> resetSettings() async {
    try {
      // 기본 설정으로 초기화
      final Map<String, bool> defaultSettings = {
        'all_notifications': true,
        'comment_notifications': true,
        'like_notifications': true,
        'follow_notifications': true,
        'message_notifications': true,
      };
      
      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      for (final entry in defaultSettings.entries) {
        await prefs.setBool(entry.key, entry.value);
      }
      
      // FCM 토큰 설정 갱신
      // _setupFCMToken 대신 public 메소드인 setupFCMToken 사용
      await _notificationService.setupFCMToken();
      
      state = AsyncValue.data(defaultSettings);
    } catch (e, stackTrace) {
      debugPrint('알림 설정 초기화 실패: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }
}