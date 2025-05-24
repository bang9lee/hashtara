import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🔥 kIsWeb 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../profile/setup_profile_screen.dart';

// 약관 동의 상태 관리를 위한 프로바이더
final termsAgreementStateProvider = StateNotifierProvider<TermsAgreementNotifier, TermsAgreementState>((ref) {
  return TermsAgreementNotifier();
});

// 약관 동의 상태 클래스
class TermsAgreementState {
  final bool isLoading;
  final bool isNavigating;
  final String? errorMessage;
  final bool termsAgreed;
  final bool privacyAgreed;
  final bool marketingAgreed;

  TermsAgreementState({
    this.isLoading = false,
    this.isNavigating = false,
    this.errorMessage,
    this.termsAgreed = false,
    this.privacyAgreed = false,
    this.marketingAgreed = false,
  });

  bool get canProceed => termsAgreed && privacyAgreed;

  TermsAgreementState copyWith({
    bool? isLoading,
    bool? isNavigating,
    String? errorMessage,
    bool? termsAgreed,
    bool? privacyAgreed,
    bool? marketingAgreed,
  }) {
    return TermsAgreementState(
      isLoading: isLoading ?? this.isLoading,
      isNavigating: isNavigating ?? this.isNavigating,
      errorMessage: errorMessage,
      termsAgreed: termsAgreed ?? this.termsAgreed,
      privacyAgreed: privacyAgreed ?? this.privacyAgreed,
      marketingAgreed: marketingAgreed ?? this.marketingAgreed,
    );
  }
}

// 약관 동의 상태 노티파이어
class TermsAgreementNotifier extends StateNotifier<TermsAgreementState> {
  TermsAgreementNotifier() : super(TermsAgreementState());

  void setTermsAgreed(bool value) {
    state = state.copyWith(termsAgreed: value);
  }

  void setPrivacyAgreed(bool value) {
    state = state.copyWith(privacyAgreed: value);
  }

  void setMarketingAgreed(bool value) {
    state = state.copyWith(marketingAgreed: value);
  }

  void setAllAgreed(bool value) {
    state = state.copyWith(
      termsAgreed: value,
      privacyAgreed: value,
      marketingAgreed: value,
    );
  }

  void startProcessing() {
    state = state.copyWith(isLoading: true, errorMessage: null);
  }

  void setError(String message) {
    state = state.copyWith(isLoading: false, errorMessage: message);
  }

  void completeProcessing() {
    state = state.copyWith(isLoading: false, errorMessage: null);
  }

  void startNavigation() {
    state = state.copyWith(isNavigating: true);
  }

  void resetState() {
    state = TermsAgreementState();
  }
}

class TermsAgreementScreen extends ConsumerStatefulWidget {
  final String userId;
  
  const TermsAgreementScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends ConsumerState<TermsAgreementScreen> {
  bool _pageInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('TermsAgreementScreen 초기화됨: ${widget.userId}');
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 🔥 웹 안전한 네비게이션 함수
  Future<void> _safeNavigateToProfile() async {
    if (!mounted) return;
    
    ref.read(termsAgreementStateProvider.notifier).startNavigation();
    
    try {
      if (kIsWeb) {
        // 🌐 웹에서는 더 안전한 방식으로 네비게이션
        debugPrint('🌐 웹: 프로필 설정 화면으로 안전한 네비게이션');
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted && context.mounted) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (context) => SetupProfileScreen(
                userId: widget.userId,
              ),
            ),
          );
        }
      } else {
        // 📱 모바일에서는 기존 방식
        if (mounted) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (context) => SetupProfileScreen(
                userId: widget.userId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('네비게이션 오류: $e');
      if (mounted) {
        ref.read(termsAgreementStateProvider.notifier).setError(
          '화면 이동 중 오류가 발생했습니다. 다시 시도해주세요.'
        );
      }
    }
  }

  // 약관 동의 저장 및 다음 화면으로 이동
  Future<void> _saveAgreementsAndNavigate() async {
    final state = ref.read(termsAgreementStateProvider);
    
    if (!state.canProceed) {
      ref.read(termsAgreementStateProvider.notifier).setError('필수 약관에 모두 동의해주세요.');
      return;
    }

    ref.read(termsAgreementStateProvider.notifier).startProcessing();

    try {
      debugPrint('🔥 약관 동의 처리 시작: ${widget.userId}');
      
      // Firebase에 약관 동의 정보 저장 - AuthController를 통해 처리
      await ref.read(authControllerProvider.notifier).completeTermsAgreement(widget.userId);
      
      ref.read(termsAgreementStateProvider.notifier).completeProcessing();
      
      debugPrint('✅ 약관 동의 저장 완료, 프로필 설정 화면으로 이동');
      
      // 🔥 웹 안전한 네비게이션 사용
      await _safeNavigateToProfile();
      
    } catch (e) {
      debugPrint('약관 동의 저장 실패: $e');
      
      // 🌐 웹에서 더 사용자 친화적인 오류 메시지
      String errorMessage;
      if (kIsWeb) {
        if (e.toString().contains('permission') || e.toString().contains('denied')) {
          errorMessage = '권한이 없습니다. 다시 로그인해주세요.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = '네트워크 연결을 확인하고 다시 시도해주세요.';
        } else {
          errorMessage = '약관 동의 처리 중 오류가 발생했습니다. 다시 시도해주세요.';
        }
      } else {
        errorMessage = '약관 동의 정보를 저장하는 중 오류가 발생했습니다. 다시 시도해주세요.';
      }
      
      ref.read(termsAgreementStateProvider.notifier).setError(errorMessage);
    }
  }

  // 약관 전체 내용 보기 모달
  void _showTermsDetail(String title, String content) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(title),
          message: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                content,
                style: const TextStyle(
                  color: AppColors.textEmphasis,
                  fontSize: 14.0,
                ),
              ),
            ),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(termsAgreementStateProvider);
    
    if (!_pageInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(termsAgreementStateProvider.notifier).resetState();
        _pageInitialized = true;
      });
    }

    return PopScope(
      canPop: false,
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.darkBackground,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.transparent)),
          middle: Text(
            '이용 약관 동의',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 컨텐츠
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더 (앱 로고)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20.0, bottom: 30.0),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo2.png',
                              width: 100,
                              height: 100,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Hashtara 서비스 이용을 위한\n약관에 동의해주세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 전체 동의 체크박스
                    Container(
                      margin: const EdgeInsets.only(bottom: 24.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: AppColors.separator),
                      ),
                      child: Row(
                        children: [
                          Transform.scale(
                            scale: 1.1,
                            child: CupertinoSwitch(
                              value: state.termsAgreed && state.privacyAgreed && state.marketingAgreed,
                              activeTrackColor: AppColors.primaryPurple,
                              onChanged: (value) {
                                ref.read(termsAgreementStateProvider.notifier).setAllAgreed(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          const Expanded(
                            child: Text(
                              '모든 약관에 동의합니다.',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 개별 약관 동의 체크박스들
                    // 1. 이용약관 (필수)
                    _buildTermsItem(
                      title: '이용약관 동의 (필수)',
                      isChecked: state.termsAgreed,
                      onChanged: (value) {
                        ref.read(termsAgreementStateProvider.notifier).setTermsAgreed(value ?? false);
                      },
                      onViewDetails: () {
                        _showTermsDetail(
                          '이용약관',
                          '''해시타라(Hashtara) 이용약관

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
본 약관은 2025년 5월 28일부터 시행합니다.'''
                        );
                      },
                    ),

                    // 2. 개인정보 수집 및 이용 동의 (필수)
                    _buildTermsItem(
                      title: '개인정보 수집 및 이용 동의 (필수)',
                      isChecked: state.privacyAgreed,
                      onChanged: (value) {
                        ref.read(termsAgreementStateProvider.notifier).setPrivacyAgreed(value ?? false);
                      },
                      onViewDetails: () {
                        _showTermsDetail(
                          '개인정보 수집 및 이용 동의',
                          '''해시타라(Hashtara) 개인정보처리방침

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
시행일자: 2025년 5월 28일'''
                        );
                      },
                    ),

                    // 3. 마케팅 목적 개인정보 수집 및 이용 동의 (선택)
                    _buildTermsItem(
                      title: '마케팅 목적 개인정보 수집 및 이용 동의 (선택)',
                      isChecked: state.marketingAgreed,
                      onChanged: (value) {
                        ref.read(termsAgreementStateProvider.notifier).setMarketingAgreed(value ?? false);
                      },
                      onViewDetails: () {
                        _showTermsDetail(
                          '마케팅 목적 개인정보 수집 및 이용 동의',
                          '''마케팅 목적 개인정보 수집 및 이용 동의

1. 수집하는 개인정보 항목
- 이메일 주소, 관심 해시태그, 앱 이용 기록

2. 개인정보 수집 및 이용 목적
- 신규 서비스 및 이벤트 정보 안내
- 맞춤형 콘텐츠 추천
- 서비스 이용 통계 분석
- 이벤트 및 프로모션 안내

3. 개인정보 보유 및 이용 기간
- 마케팅 동의 철회 시 또는 회원 탈퇴 시까지

4. 동의 거부권 및 불이익
- 본 마케팅 목적 개인정보 수집 및 이용 동의는 선택사항입니다.
- 동의를 거부하더라도 서비스 이용에 제한이 없습니다.
- 다만, 동의하지 않을 경우 맞춤형 혜택 및 이벤트 정보 제공 등의 서비스를 받지 못할 수 있습니다.

※ 마케팅 동의 변경은 설정 메뉴에서 언제든지 변경 가능합니다.'''
                        );
                      },
                    ),

                    // 오류 메시지
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemRed.withAlpha(30),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 14.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                    // 하단 여백
                    const SizedBox(height: 120),
                  ],
                ),
              ),

              // 하단 버튼
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: const BoxDecoration(
                    color: AppColors.darkBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    color: state.canProceed
                        ? AppColors.primaryPurple
                        : AppColors.primaryPurple.withAlpha(128),
                    borderRadius: BorderRadius.circular(12.0),
                    onPressed: state.isLoading || state.isNavigating 
                        ? null 
                        : (state.canProceed ? _saveAgreementsAndNavigate : null),
                    child: state.isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoActivityIndicator(color: AppColors.white),
                              SizedBox(width: 8),
                              Text(
                                kIsWeb ? '처리 중...' : '저장 중...',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                          '동의하고 계속하기',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 약관 동의 아이템 위젯
  Widget _buildTermsItem({
    required String title,
    required bool isChecked,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewDetails,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Transform.scale(
                scale: 1.0,
                child: CupertinoSwitch(
                  value: isChecked,
                  activeTrackColor: AppColors.primaryPurple,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textEmphasis,
                    fontSize: 15.0,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onViewDetails,
                child: const Text(
                  '보기',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontSize: 14.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}