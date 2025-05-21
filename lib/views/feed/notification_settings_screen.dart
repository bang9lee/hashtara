import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../providers/notification_settings_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final notificationSettingsAsync = ref.watch(notificationSettingsProvider);
    
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('알림 설정'),
      ),
      child: SafeArea(
        child: notificationSettingsAsync.when(
          data: (settings) => _buildSettingsContent(settings),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle,
                  color: CupertinoColors.systemRed,
                  size: 50,
                ),
                const SizedBox(height: 16),
                Text(
                  '설정을 불러오는 중 오류가 발생했습니다.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textEmphasis),
                ),
                const SizedBox(height: 16),
                CupertinoButton(
                  onPressed: () {
                    // unused_result 경고 해결을 위해 _ 변수 할당 
                    final _ = ref.refresh(notificationSettingsProvider);
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(Map<String, bool> settings) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 안내 헤더
            const Text(
              '앱에서 받을 알림을 설정하세요.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // 모든 알림 허용
            _buildSettingTile(
              title: '모든 알림 허용',
              subtitle: '이 기기에서 알림을 받을지 설정합니다.',
              value: settings['all_notifications'] ?? true,
              onChanged: (value) async {
                setState(() => _isLoading = true);
                await ref.read(notificationSettingsProvider.notifier).setAllNotifications(value);
                if (mounted) setState(() => _isLoading = false);
              },
            ),
            
            const SizedBox(height: 16),
            
            // 알림 타입별 설정
            const Text(
              '알림 타입',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textEmphasis,
              ),
            ),
            const SizedBox(height: 12),
            
            // 댓글 알림
            _buildSettingTile(
              title: '댓글 알림',
              subtitle: '게시물에 새 댓글이 달렸을 때 알림을 받습니다.',
              value: settings['comment_notifications'] ?? true,
              onChanged: !(settings['all_notifications'] ?? true) 
                ? null
                : (value) async {
                    setState(() => _isLoading = true);
                    await ref.read(notificationSettingsProvider.notifier)
                        .setNotificationSetting('comment_notifications', value);
                    if (mounted) setState(() => _isLoading = false);
                  },
            ),
            
            // 좋아요 알림
            _buildSettingTile(
              title: '좋아요 알림',
              subtitle: '게시물에 좋아요가 달렸을 때 알림을 받습니다.',
              value: settings['like_notifications'] ?? true,
              onChanged: !(settings['all_notifications'] ?? true) 
                ? null
                : (value) async {
                    setState(() => _isLoading = true);
                    await ref.read(notificationSettingsProvider.notifier)
                        .setNotificationSetting('like_notifications', value);
                    if (mounted) setState(() => _isLoading = false);
                  },
            ),
            
            // 팔로우 알림
            _buildSettingTile(
              title: '팔로우 알림',
              subtitle: '새로운 팔로워가 생겼을 때 알림을 받습니다.',
              value: settings['follow_notifications'] ?? true,
              onChanged: !(settings['all_notifications'] ?? true) 
                ? null
                : (value) async {
                    setState(() => _isLoading = true);
                    await ref.read(notificationSettingsProvider.notifier)
                        .setNotificationSetting('follow_notifications', value);
                    if (mounted) setState(() => _isLoading = false);
                  },
            ),
            
            // 메시지 알림
            _buildSettingTile(
              title: '메시지 알림',
              subtitle: '새로운 메시지가 도착했을 때 알림을 받습니다.',
              value: settings['message_notifications'] ?? true,
              onChanged: !(settings['all_notifications'] ?? true) 
                ? null
                : (value) async {
                    setState(() => _isLoading = true);
                    await ref.read(notificationSettingsProvider.notifier)
                        .setNotificationSetting('message_notifications', value);
                    if (mounted) setState(() => _isLoading = false);
                  },
            ),
            
            const SizedBox(height: 32),
            
            // 알림 설정 초기화 버튼
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.primaryPurple.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                onPressed: _isLoading 
                  ? null 
                  : () async {
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('알림 설정 초기화'),
                          content: const Text('모든 알림 설정을 기본값으로 초기화하시겠습니까?'),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () async {
                                Navigator.pop(context);
                                setState(() => _isLoading = true);
                                await ref.read(notificationSettingsProvider.notifier).resetSettings();
                                if (mounted) setState(() => _isLoading = false);
                              },
                              isDefaultAction: true,
                              child: const Text('초기화'),
                            ),
                          ],
                        ),
                      );
                    },
                child: const Text(
                  '알림 설정 초기화',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // 알림 도움말
            const _HelpSection(),
          ],
        ),
        
        // 로딩 오버레이
        if (_isLoading)
          Container(
            color: CupertinoColors.systemBackground.withAlpha(180),
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textEmphasis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            // activeColor 속성이 deprecated 되었으므로 activeTrackColor로 변경
            activeTrackColor: AppColors.primaryPurple,
          ),
        ],
      ),
    );
  }
}

// 도움말 섹션을 별도 위젯으로 분리하여 const 적용
class _HelpSection extends StatelessWidget {
  const _HelpSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '알림 도움말',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textEmphasis,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• 알림은 앱 내부 및 모바일 푸시 알림을 포함합니다.\n'
            '• 모든 알림을 비활성화해도 앱의 중요 공지 및 보안 관련 알림은 계속 받을 수 있습니다.\n'
            '• 메시지 알림은 실시간 채팅 메시지에 대한 알림을 의미합니다.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}