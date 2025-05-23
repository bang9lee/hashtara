import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../feed/notification_settings_screen.dart';
import '../auth/login_screen.dart';

// main.dart의 navigatorKey 가져오기
import '../../main.dart' as main_file;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;
  
  // 앱 버전 가져오기 (pubspec.yaml에서 정의된 버전)
  final String _appVersion = '1.0.0';
  
  // 이용약관 보기
  void _viewTermsOfService() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const TermsDetailScreen(
          title: '이용약관',
          content: '''해시타라(Hashtara) 이용약관

제1조 (목적)
이 약관은 해시타라 앱(이하 "서비스"라 함)의 이용 조건 및 절차, 개발자와 이용자 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.

제2조 (정의)
본 약관에서 사용하는 용어의 정의는 다음과 같습니다.
① "서비스"라 함은 해시타라 앱을 통해 제공하는 모든 서비스를 의미합니다.
② "이용자"라 함은 서비스에 접속하여 본 약관에 따라 서비스를 이용하는 사람을 말합니다.
③ "아이디(ID)"라 함은 이용자의 식별과 서비스 이용을 위하여 이용자가 설정한 이메일 주소와 비밀번호를 의미합니다.

제3조 (약관의 효력 및 변경)
① 본 약관은 서비스를 이용하고자 하는 모든 이용자에게 그 효력이 발생합니다.
② 서비스 제공자는 필요한 경우 약관을 변경할 수 있으며, 변경된 약관은 서비스 내에 공지함으로써 효력이 발생됩니다.
③ 이용자는 변경된 약관에 동의하지 않을 경우 서비스 이용을 중단하고 탈퇴할 수 있으며, 변경된 약관 시행 후에도 서비스를 계속 이용하는 경우에는 약관 변경에 동의한 것으로 간주됩니다.

제4조 (서비스 제공 및 변경)
① 서비스 제공자는 다음과 같은 서비스를 제공합니다.
1. 해시태그 기반의 소셜 네트워킹 서비스
2. 콘텐츠 공유 서비스
3. 메시지 서비스
4. 기타 해시타라 앱에서 제공하는 서비스
② 서비스 내용이 변경될 경우, 서비스 제공자는 변경 사항을 사전에 공지합니다.

제5조 (서비스 이용료)
① 기본적인 서비스 이용은 무료입니다.
② 추후 유료 서비스가 추가될 경우, 해당 서비스의 이용 조건 및 요금은 별도 공지됩니다.

제6조 (이용자의 의무)
① 이용자는 다음 각 호의 행위를 해서는 안 됩니다.
1. 다른 이용자의 계정 정보를 부정하게 사용하는 행위
2. 서비스를 통해 얻은 정보를 허가 없이 복제, 배포하는 행위
3. 타인의 저작권 등 지적재산권을 침해하는 행위
4. 타인을 비방하거나 명예를 훼손하는 행위
5. 음란물, 욕설, 혐오발언 등 공서양속에 반하는 내용을 게시하는 행위
6. 범죄와 관련된 행위
7. 기타 관련 법령에 위배되는 행위

제7조 (서비스 이용 제한)
서비스 제공자는 이용자가 본 약관의 의무를 위반하거나 서비스의 정상적인 운영을 방해했을 경우, 서비스 이용을 제한할 수 있습니다.

제8조 (저작권의 귀속 및 이용제한)
① 서비스 제공자가 작성한 저작물에 대한 저작권은 서비스 제공자에게 귀속됩니다.
② 이용자가 서비스 내에 게시한 게시물의 저작권은 해당 이용자에게 귀속됩니다.
③ 이용자는 서비스를 이용하여 얻은 정보를 서비스 제공자의 사전 승인 없이 복제, 송신, 출판, 배포, 방송 등 기타 방법에 의하여 영리 목적으로 이용하거나 제3자에게 이용하게 할 수 없습니다.

제9조 (책임제한)
① 서비스 제공자는 천재지변, 전쟁, 기간통신사업자의 서비스 중지 등 불가항력적인 사유로 서비스를 제공할 수 없는 경우에는 서비스 제공에 대한 책임을 지지 않습니다.
② 서비스 제공자는 이용자의 귀책사유로 인한 서비스 이용 장애에 대해서는 책임을 지지 않습니다.
③ 서비스 제공자는 이용자가 서비스를 통해 얻은 정보 또는 자료 등으로 인해 발생한 손해에 대하여 책임을 지지 않습니다.

제10조 (개인정보보호)
서비스 제공자는 「개인정보 보호법」 등 관련 법령이 정하는 바에 따라 이용자의 개인정보를 보호하며, 개인정보의 보호 및 사용에 대해서는 관련 법령 및 서비스 제공자의 개인정보처리방침에 따릅니다.

제11조 (분쟁해결)
① 서비스 이용과 관련하여 분쟁이 발생한 경우, 이용자와 서비스 제공자는 분쟁의 해결을 위해 성실히 협의합니다.
② 협의가 이루어지지 않을 경우 관련 법령에 따라 처리합니다.

부칙
본 약관은 2025년 5월 28일부터 시행합니다.''',
        ),
      ),
    );
  }
  
  // 개인정보처리방침 보기
  void _viewPrivacyPolicy() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const TermsDetailScreen(
          title: '개인정보처리방침',
          content: '''해시타라(Hashtara) 개인정보처리방침

최종 업데이트일: 2025년 5월 21일

본 개인정보처리방침은 해시타라 앱(이하 "서비스")의 이용자 개인정보 처리에 대한 사항을 안내드립니다.

1. 수집하는 개인정보 항목

필수 항목:
• 계정 정보: 이메일 주소, 비밀번호(암호화하여 저장)
• 프로필 정보: 이름, 사용자명(닉네임)
• 기기 정보: 기기 식별자, 앱 이용 기록

선택 항목:
• 프로필 이미지
• 자기소개(바이오)
• 관심 해시태그

2. 개인정보 수집 및 이용 목적

• 회원 식별 및 서비스 제공: 회원가입, 로그인, 계정 관리
• 소셜 네트워킹 서비스 제공: 게시물 및 댓글 작성, 팔로우/팔로잉 기능
• 서비스 개선: 사용자 경험 분석 및 개선
• 고객 지원: 문의사항 응대 및 피드백 처리

3. 개인정보의 보유 및 이용 기간

개인정보는 원칙적으로 회원 탈퇴 시까지 보유합니다. 단, 관계 법령에 따라 일정 기간 보관이 필요한 정보는 해당 기간 동안 보관합니다.

• 로그인 기록: 3개월 (통신비밀보호법)
• 불만 또는 분쟁처리에 관한 기록: 3년 (전자상거래 등에서의 소비자 보호에 관한 법률)

4. 개인정보의 제3자 제공

원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다. 단, 다음의 경우는 예외로 합니다:
• 이용자가 동의한 경우
• 법령에 의하여 제공이 요구되는 경우

5. 이용자의 권리와 행사 방법

이용자는 언제든지 다음의 권리를 행사할 수 있습니다:
• 개인정보 열람, 정정, 삭제 요청
• 개인정보 처리 정지 요청
• 회원 탈퇴

위 권리는 앱 내 설정 메뉴를 통해 행사하거나, 이메일(chchleeshop@gmail.com)로 문의하실 수 있습니다.

6. 개인정보의 안전성 확보 조치

개인정보 보호를 위해 다음과 같은 기술적, 관리적 조치를 취하고 있습니다:
• 비밀번호 암호화 저장
• 데이터 암호화 전송
• 접근 권한 관리
• 보안 시스템 구축

7. 개인정보 보호책임자 및 연락처

개인정보 보호책임자: 해시타라 개발자
이메일: chchleeshop@gmail.com

8. 개인정보처리방침의 변경

본 개인정보처리방침은 법령, 정책 또는 보안 기술의 변경에 따라 내용이 추가, 삭제 또는 수정될 수 있으며, 변경 시 앱 내 공지사항을 통해 고지할 것입니다.

공고일자: 2025년 5월 21일
시행일자: 2025년 5월 28일''',
        ),
      ),
    );
  }
  
  // 문의하기 (이메일)
  Future<void> _contactSupport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'chchleeshop@gmail.com',
      query: Uri.encodeFull('subject=해시타라 앱 문의&body=안녕하세요,\n\n'),
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        // 이메일 앱이 없거나 열 수 없는 경우 이메일 주소 복사
        _showEmailCopyDialog();
      }
    } catch (e) {
      debugPrint('이메일 앱 열기 실패: $e');
      _showEmailCopyDialog();
    }
  }
  
  // 이메일 주소 복사 다이얼로그
  void _showEmailCopyDialog() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('이메일 앱을 열 수 없습니다'),
        content: const Text(
          '문의 이메일: chchleeshop@gmail.com\n\n'
          '이메일 주소를 복사하시겠습니까?'
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              // 클립보드에 이메일 주소 복사
              Clipboard.setData(const ClipboardData(text: 'chchleeshop@gmail.com'));
              Navigator.of(dialogContext).pop();
              
              // 복사 완료 알림
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('복사 완료'),
                  content: const Text('이메일 주소가 클립보드에 복사되었습니다.'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('확인'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
            child: const Text('복사'),
          ),
        ],
      ),
    );
  }
  
  // 🔥 회원 탈퇴 함수
  Future<void> _handleDeleteAccount() async {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '정말 회원 탈퇴를 진행하시겠습니까?\n\n'
          '모든 데이터가 삭제되며 이 작업은 되돌릴 수 없습니다.'
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // 다이얼로그 먼저 닫기
              
              if (!mounted) return;
              
              // 로딩 상태로 변경
              setState(() {
                _isLoading = true;
              });
              
              debugPrint('🔥🔥🔥 회원탈퇴 처리 시작 (설정에서)');
              
              try {
                // 🔥 1단계: 강제 로그아웃 플래그 설정 (가장 먼저!)
                ref.read(forceLogoutProvider.notifier).state = true;
                debugPrint('🔥 강제 로그아웃 플래그 설정 완료');
                
                // 🔥 2단계: 상태 초기화
                ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
                await clearSignupProgress();
                debugPrint('🔥 상태 초기화 완료');
                
                // 🔥 3단계: 즉시 로그인 화면으로 네비게이션 (회원탈퇴 전에!)
                if (main_file.navigatorKey.currentState != null) {
                  main_file.navigatorKey.currentState!.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false, // 모든 이전 화면 제거
                  );
                  debugPrint('🔥 즉시 로그인 화면 이동 완료');
                } else if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                  debugPrint('🔥 로컬 네비게이터로 로그인 화면 이동 완료');
                }
                
                // 🔥 4단계: 백그라운드에서 회원탈퇴 처리
                ref.read(authControllerProvider.notifier).deleteAccount().catchError((e) {
                  debugPrint('🔥 백그라운드 회원탈퇴 에러 (무시): $e');
                });
                
                // 🔥 5단계: Provider 무효화 (백그라운드)
                Future.delayed(const Duration(milliseconds: 100), () {
                  try {
                    ref.invalidate(currentUserProvider);
                    ref.invalidate(authStateProvider);
                    debugPrint('🔥 백그라운드 프로바이더 무효화 완료');
                  } catch (e) {
                    debugPrint('🔥 백그라운드 프로바이더 무효화 에러 (무시): $e');
                  }
                });
                
                debugPrint('🔥🔥🔥 회원탈퇴 처리 완료 (설정에서)');
                
              } catch (e) {
                debugPrint('🔥 회원탈퇴 처리 실패: $e');
                
                // 실패해도 강제로 로그인 화면으로 이동
                if (main_file.navigatorKey.currentState != null) {
                  main_file.navigatorKey.currentState!.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                } else if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              } finally {
                // 로딩 상태 해제 (mounted 체크)
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: const Text('회원탈퇴'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.darkBackground,
        middle: Text(
          '설정',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              children: [
                // 계정 정보 섹션 (새로 추가)
                currentUser.when(
                  data: (user) {
                    if (user != null) {
                      return Column(
                        children: [
                          const SettingSectionHeader(title: '내 계정'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.separator),
                              ),
                              child: Row(
                                children: [
                                  // 프로필 이미지
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.darkBackground,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.separator),
                                      image: user.profileImageUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(user.profileImageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: user.profileImageUrl == null
                                        ? const Icon(
                                            CupertinoIcons.person_fill,
                                            color: AppColors.textSecondary,
                                            size: 28,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  // 사용자 정보
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name ?? '이름 없음',
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '@${user.username ?? 'unknown'}',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                
                // 알림 설정 섹션
                const SettingSectionHeader(title: '알림'),
                SettingButton(
                  icon: const Icon(
                    CupertinoIcons.bell,
                    size: 22,
                    color: AppColors.primaryPurple,
                  ),
                  title: '알림 설정',
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
                
                // 정보 섹션
                const SettingSectionHeader(title: '정보'),
                SettingButton(
                  icon: const Icon(
                    CupertinoIcons.doc_text,
                    size: 22,
                    color: AppColors.primaryPurple,
                  ),
                  title: '이용약관',
                  onTap: _viewTermsOfService,
                ),
                SettingButton(
                  icon: const Icon(
                    CupertinoIcons.lock_shield,
                    size: 22,
                    color: AppColors.primaryPurple,
                  ),
                  title: '개인정보처리방침',
                  onTap: _viewPrivacyPolicy,
                ),
                
                // 지원 섹션
                const SettingSectionHeader(title: '지원'),
                SettingButton(
                  icon: const Icon(
                    CupertinoIcons.mail,
                    size: 22,
                    color: AppColors.primaryPurple,
                  ),
                  title: '문의하기',
                  subtitle: 'chchleeshop@gmail.com',
                  onTap: _contactSupport,
                ),
                
                // 앱 정보 섹션
                const SettingSectionHeader(title: '앱 정보'),
                SettingInfoRow(
                  title: '버전',
                  value: 'v$_appVersion',
                ),
                const SettingInfoRow(
                  title: '개발자',
                  value: 'Hashtara Team',
                ),
                
                // 계정 섹션
                const SettingSectionHeader(title: '계정'),
                
                // 로그아웃 버튼 (색상 변경)
                SettingButton(
                  icon: const Icon(
                    CupertinoIcons.square_arrow_right,
                    size: 22,
                    color: AppColors.primaryPurple,
                  ),
                  title: '로그아웃',
                  onTap: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (dialogContext) => CupertinoAlertDialog(
                        title: const Text('로그아웃'),
                        content: const Text('정말 로그아웃 하시겠습니까?'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('취소'),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              // 프로필 화면의 로그아웃 메서드 호출
                              _handleLogout();
                            },
                            child: const Text('로그아웃'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 8),
                
                // 회원탈퇴 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: CupertinoColors.systemRed.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      onPressed: _isLoading ? null : _handleDeleteAccount,
                      child: const Text(
                        '회원탈퇴',
                        style: TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),
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
        ),
      ),
    );
  }
  
  // 로그아웃 처리 함수 (profile_screen.dart에서 가져옴)
  Future<void> _handleLogout() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    debugPrint('🔥🔥🔥 강화된 로그아웃 시작');
    
    try {
      // 🔥 1단계: 모든 프로바이더 즉시 무효화 (권한 오류 방지)
      ref.invalidate(currentUserProvider);
      ref.invalidate(authStateProvider);
      debugPrint('🔥 즉시 프로바이더 무효화 완료');
      
      // 🔥 2단계: 상태 완전 초기화
      ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
      ref.read(forceLogoutProvider.notifier).state = true;
      await clearSignupProgress();
      debugPrint('🔥 상태 완전 초기화 완료');
      
      // 🔥 3단계: Firebase 즉시 로그아웃 (권한 오류 방지를 위해)
      try {
        await ref.read(authControllerProvider.notifier).signOut();
        debugPrint('🔥 Firebase 로그아웃 성공');
      } catch (e) {
        debugPrint('🔥 Firebase 로그아웃 에러: $e');
        // Firebase 로그아웃 실패해도 계속 진행
      }
      
      // 🔥 4단계: 추가 프로바이더 정리 (지연)
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        ref.invalidate(currentUserProvider);
        ref.invalidate(authStateProvider);
        debugPrint('🔥 추가 프로바이더 정리 완료');
      } catch (e) {
        debugPrint('🔥 추가 프로바이더 정리 에러 (무시): $e');
      }
      
      // 🔥 5단계: 강제 네비게이션 (마지막에)
      await Future.delayed(const Duration(milliseconds: 100));
      if (main_file.navigatorKey.currentState != null) {
        main_file.navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/login',
          (route) => false, // 모든 이전 화면 제거
        );
        debugPrint('🔥 강제 로그인 화면 이동 완료');
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          CupertinoPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
        debugPrint('🔥 로컬 네비게이터로 로그인 화면 이동 완료');
      }
      
      debugPrint('🔥🔥🔥 강화된 로그아웃 완료');
      
    } catch (e) {
      debugPrint('🔥 로그아웃 처리 실패: $e');
      
      // 실패해도 강제로 처리
      try {
        ref.read(forceLogoutProvider.notifier).state = true;
        ref.read(signupProgressProvider.notifier).state = SignupProgress.none;
        await clearSignupProgress();
        
        if (main_file.navigatorKey.currentState != null) {
          main_file.navigatorKey.currentState!.pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        } else if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            CupertinoPageRoute(
              builder: (context) => const LoginScreen(),
            ),
            (route) => false,
          );
        }
      } catch (_) {}
    } finally {
      // 로딩 상태 해제 (mounted 체크)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// 설정 섹션 헤더 위젯
class SettingSectionHeader extends StatelessWidget {
  final String title;
  
  const SettingSectionHeader({
    Key? key,
    required this.title,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// 설정 버튼 위젯
class SettingButton extends StatelessWidget {
  final Icon icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  
  const SettingButton({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.separator),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 설정 정보 행 위젯
class SettingInfoRow extends StatelessWidget {
  final String title;
  final String value;
  
  const SettingInfoRow({
    Key? key,
    required this.title,
    required this.value,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.separator),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textEmphasis,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 약관 상세 화면
class TermsDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  
  const TermsDetailScreen({
    Key? key,
    required this.title,
    required this.content,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.darkBackground,
        middle: Text(
          title,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.separator),
            ),
            child: Text(
              content,
              style: const TextStyle(
                color: AppColors.textEmphasis,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}