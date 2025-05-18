import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hashtara/constants/app_colors.dart'; // 'package:' import로 변경
import 'package:hashtara/constants/app_strings.dart'; // 'package:' import로 변경
import 'package:hashtara/providers/auth_provider.dart'; // 'package:' import로 변경
import 'package:hashtara/providers/profile_provider.dart'; // 'package:' import로 변경
import 'package:hashtara/views/feed/main_tab_screen.dart'; // 추가: MainTabScreen import

// 프로필 설정 상태를 위한 프로바이더
final profileSetupStateProvider = StateNotifierProvider<ProfileSetupNotifier, ProfileSetupState>((ref) {
  return ProfileSetupNotifier();
});

// 프로필 설정 상태 클래스
class ProfileSetupState {
  final bool isCompleting;
  final bool isSkipping;
  final String? errorMessage;

  ProfileSetupState({
    this.isCompleting = false,
    this.isSkipping = false,
    this.errorMessage,
  });

  ProfileSetupState copyWith({
    bool? isCompleting,
    bool? isSkipping,
    String? errorMessage,
  }) {
    return ProfileSetupState(
      isCompleting: isCompleting ?? this.isCompleting,
      isSkipping: isSkipping ?? this.isSkipping,
      errorMessage: errorMessage, // 이전 값을 유지하지 않도록 수정 (null일 수 있음)
    );
  }
}

// 프로필 설정 상태 노티파이어
class ProfileSetupNotifier extends StateNotifier<ProfileSetupState> {
  ProfileSetupNotifier() : super(ProfileSetupState());

  void startProfileCompletion() {
    state = state.copyWith(isCompleting: true, errorMessage: null);
  }

  void startSkipping() {
    state = state.copyWith(isSkipping: true, errorMessage: null);
  }

  void setError(String message) {
    state = state.copyWith(isCompleting: false, isSkipping: false, errorMessage: message);
  }

  void completeProfileSetup() {
    // isCompleting는 이미 true일 것이므로, 여기서는 isNavigating 플래그처럼 작동하게 함
    // 혹은 성공 상태를 명시적으로 나타내는 새로운 상태값을 추가할 수 있음
    state = state.copyWith(isCompleting: true, errorMessage: null); // 성공 시에도 isCompleting 유지
  }

  void skipProfileSetup() {
    state = state.copyWith(isSkipping: true, errorMessage: null); // 성공 시에도 isSkipping 유지
  }

  void reset() {
    state = ProfileSetupState();
  }
}

class SetupProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const SetupProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _nameError = false;
  bool _usernameError = false;

  @override
  void initState() {
    super.initState();
    debugPrint('SetupProfileScreen 초기화됨: ${widget.userId}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  bool _isValidUsername(String username) {
    final validUsernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    return validUsernameRegex.hasMatch(username);
  }

  Future<void> _saveProfile() async {
    setState(() {
      _nameError = false;
      _usernameError = false;
    });

    if (_nameController.text.isEmpty) {
      setState(() => _nameError = true);
      ref.read(profileSetupStateProvider.notifier).setError('이름은 필수입니다.');
      return;
    }
    if (_usernameController.text.isEmpty) {
      setState(() => _usernameError = true);
      ref.read(profileSetupStateProvider.notifier).setError('사용자명은 필수입니다.');
      return;
    }
    if (!_isValidUsername(_usernameController.text)) {
      setState(() => _usernameError = true);
      ref.read(profileSetupStateProvider.notifier).setError('사용자명은 영문, 숫자, 언더스코어(_)만 사용할 수 있습니다.');
      return;
    }

    ref.read(profileSetupStateProvider.notifier).startProfileCompletion();

    try {
      debugPrint('프로필 저장 시도: ${widget.userId}');
      await ref.read(authRepositoryProvider).createUserDocument(
            widget.userId,
            _nameController.text.trim(),
            _usernameController.text.trim(),
            null,
          );
      await ref.read(profileRepositoryProvider).createProfileDocument(
            widget.userId,
            _bioController.text.trim(),
          );
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'profileComplete': true,
      });
      debugPrint('프로필 저장 성공, 피드로 이동');
      ref.read(profileSetupStateProvider.notifier).completeProfileSetup();
    } catch (e) {
      debugPrint('프로필 저장 실패: $e');
      ref.read(profileSetupStateProvider.notifier).setError('프로필 설정에 실패했습니다. 다시 시도해주세요. 오류: $e');
    }
  }

  void _showSkipConfirmationDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('프로필 설정 건너뛰기'),
          content: const Text('프로필 설정은 나중에 할 수 있습니다. 지금 건너뛰시겠습니까?'),
          actions: [
            CupertinoDialogAction(child: const Text('취소'), onPressed: () => Navigator.pop(dialogContext)),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(dialogContext);
                _skipProfile();
              },
              child: const Text('건너뛰기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _skipProfile() async {
    ref.read(profileSetupStateProvider.notifier).startSkipping();
    try {
      debugPrint('프로필 건너뛰기: ${widget.userId}');
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6, 10);
      final defaultUsername = 'user_$timestamp';
      await ref.read(authRepositoryProvider).createUserDocument(widget.userId, 'User', defaultUsername, null);
      await ref.read(profileRepositoryProvider).createProfileDocument(widget.userId, '프로필이 아직 설정되지 않았습니다.');
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'profileComplete': true});
      debugPrint('기본 프로필 생성 성공, 피드로 이동');
      ref.read(profileSetupStateProvider.notifier).skipProfileSetup();
    } catch (e) {
      debugPrint('기본 프로필 생성 실패: $e');
      ref.read(profileSetupStateProvider.notifier).setError('기본 프로필 설정에 실패했습니다. 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final horizontalPadding = screenSize.width * 0.06;
    final buttonHeight = screenSize.height * 0.06;
    final verticalSpacing = screenSize.height * 0.02;
    final circleSize = screenSize.width * 0.25;

    final profileSetupState = ref.watch(profileSetupStateProvider);

    // 상태 변경 감지 및 화면 전환 (성공 시에만)
    ref.listen<ProfileSetupState>(profileSetupStateProvider, (previous, next) {
      if (mounted && (next.isCompleting || next.isSkipping) && next.errorMessage == null) {
        // isCompleting 또는 isSkipping이 true이고, 에러가 없을 때만 네비게이션
        // 네비게이션 후 상태 리셋은 한번만 호출되도록 보장
        WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted && (ref.read(profileSetupStateProvider).isCompleting || ref.read(profileSetupStateProvider).isSkipping) && ref.read(profileSetupStateProvider).errorMessage == null) {
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(builder: (context) => const MainTabScreen()), // MainTabScreen() 호출
              (route) => false,
            );
            ref.read(profileSetupStateProvider.notifier).reset(); // 네비게이션 후 상태 리셋
          }
        });
      }
    });


    return PopScope(
      canPop: false,
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.darkBackground,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: AppColors.primaryPurple,
          middle: Text(AppStrings.setupProfile, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
          automaticallyImplyLeading: false,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: verticalSpacing),
                const Text(AppStrings.profileSetupDesc, style: TextStyle(color: AppColors.textEmphasis, fontSize: 16.0), textAlign: TextAlign.center),
                SizedBox(height: verticalSpacing * 2),
                Center(
                  child: Container(
                    width: circleSize, height: circleSize,
                    decoration: BoxDecoration(color: AppColors.cardBackground, shape: BoxShape.circle, border: Border.all(color: AppColors.separator, width: 2.0)),
                    child: const Icon(CupertinoIcons.person_fill, size: 60, color: AppColors.textEmphasis),
                  ),
                ),
                SizedBox(height: verticalSpacing * 1.5),
                Row(
                  children: [
                    const Text('이름', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textEmphasis)),
                    const SizedBox(width: 5),
                    Text('(필수)', style: TextStyle(fontSize: 13, color: _nameError ? CupertinoColors.systemRed : AppColors.textSecondary)),
                  ],
                ),
                SizedBox(height: verticalSpacing / 2),
                CupertinoTextField(
                  controller: _nameController, placeholder: '이름을 입력하세요',
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: _nameError ? CupertinoColors.systemRed : AppColors.separator)),
                  style: const TextStyle(color: AppColors.white), placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                  enabled: !profileSetupState.isCompleting && !profileSetupState.isSkipping,
                  onChanged: (value) { if (_nameError && value.isNotEmpty) setState(() => _nameError = false); },
                ),
                SizedBox(height: verticalSpacing),
                Row(
                  children: [
                    const Text('사용자명', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textEmphasis)),
                    const SizedBox(width: 5),
                    Text('(필수)', style: TextStyle(fontSize: 13, color: _usernameError ? CupertinoColors.systemRed : AppColors.textSecondary)),
                  ],
                ),
                SizedBox(height: verticalSpacing / 2),
                CupertinoTextField(
                  controller: _usernameController, placeholder: '사용자명을 입력하세요 (예: user123)',
                  prefix: const Padding(padding: EdgeInsets.only(left: 16), child: Text('@', style: TextStyle(color: AppColors.textSecondary, fontSize: 16))),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: _usernameError ? CupertinoColors.systemRed : AppColors.separator)),
                  style: const TextStyle(color: AppColors.white), placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                  enabled: !profileSetupState.isCompleting && !profileSetupState.isSkipping,
                  onChanged: (value) { if (_usernameError && value.isNotEmpty) setState(() => _usernameError = false); },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                  child: Text('영문, 숫자, 언더스코어(_)만 사용 가능합니다.', style: TextStyle(fontSize: 12, color: _usernameError ? CupertinoColors.systemRed : AppColors.textSecondary)),
                ),
                SizedBox(height: verticalSpacing),
                const Text('소개 (선택)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textEmphasis)),
                SizedBox(height: verticalSpacing / 2),
                CupertinoTextField(
                  controller: _bioController, placeholder: '자신을 소개해보세요', maxLines: 3,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.separator)),
                  style: const TextStyle(color: AppColors.white), placeholderStyle: const TextStyle(color: AppColors.textSecondary),
                  enabled: !profileSetupState.isCompleting && !profileSetupState.isSkipping,
                ),
                SizedBox(height: verticalSpacing * 2),
                SizedBox(
                  height: buttonHeight,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero, color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(12),
                    onPressed: (profileSetupState.isCompleting || profileSetupState.isSkipping) ? null : _saveProfile,
                    child: (profileSetupState.isCompleting) ? const CupertinoActivityIndicator(color: AppColors.white) : const Text(AppStrings.saveProfile, style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: verticalSpacing),
                if (!profileSetupState.isCompleting && !profileSetupState.isSkipping)
                  Center(child: CupertinoButton(onPressed: _showSkipConfirmationDialog, child: const Text(AppStrings.skip, style: TextStyle(color: AppColors.textEmphasis, fontSize: 15)))),
                if (profileSetupState.isSkipping && profileSetupState.errorMessage == null) // 에러가 없을 때만 로딩 표시
                  const Center(
                    child: Column(
                      children: [
                        CupertinoActivityIndicator(), SizedBox(height: 8),
                        Text('기본 프로필 설정 중...', style: TextStyle(color: AppColors.textEmphasis, fontSize: 14)),
                      ],
                    ),
                  ),
                if (profileSetupState.errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: verticalSpacing),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: CupertinoColors.systemRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(profileSetupState.errorMessage!, style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 14), textAlign: TextAlign.center),
                    ),
                  ),
                SizedBox(height: verticalSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}