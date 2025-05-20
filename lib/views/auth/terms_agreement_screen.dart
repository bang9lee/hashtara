// terms_agreement_screen.dart - 약관 동의 완료 처리 수정

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // 사용하지 않음 - 제거
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart'; // 추가: AuthController를 사용하기 위해 임포트
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
  final bool marketingAgreed; // 선택 항목

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

  // 약관 동의 저장 및 다음 화면으로 이동 - 수정된 메소드
  Future<void> _saveAgreementsAndNavigate() async {
    final state = ref.read(termsAgreementStateProvider);
    
    if (!state.canProceed) {
      ref.read(termsAgreementStateProvider.notifier).setError('필수 약관에 모두 동의해주세요.');
      return;
    }

    ref.read(termsAgreementStateProvider.notifier).startProcessing();

    try {
      // Firebase에 약관 동의 정보 저장 - AuthController를 통해 처리 (수정)
      await ref.read(authControllerProvider.notifier).completeTermsAgreement(widget.userId);
      
      ref.read(termsAgreementStateProvider.notifier).completeProcessing();
      
      // 다음 화면(프로필 설정)으로 이동
      if (mounted) {
        ref.read(termsAgreementStateProvider.notifier).startNavigation();
        
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => SetupProfileScreen(
              userId: widget.userId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('약관 동의 저장 실패: $e');
      ref.read(termsAgreementStateProvider.notifier).setError('약관 동의 정보를 저장하는 중 오류가 발생했습니다. 다시 시도해주세요.');
      rethrow;
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
      // 페이지 로드 시 상태 초기화
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
          border:  Border(bottom: BorderSide(color: Colors.transparent)),
          middle:  Text(
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
                          '해시타라(Hashtara) 이용약관\n\n'
                          '제1조 (목적)\n'
                          '이 약관은 해시타라(이하 "회사"라 함)가 제공하는 모든 서비스(이하 "서비스"라 함)의 이용 조건 및 절차, 회사와 회원 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n'
                          '제2조 (정의)\n'
                          '본 약관에서 사용하는 용어의 정의는 다음과 같습니다.\n'
                          '① "서비스"라 함은 회사가 제공하는 모든 서비스를 의미합니다.\n'
                          '② "회원"이라 함은 회사의 서비스에 접속하여 본 약관에 따라 회사와 이용계약을 체결하고, 회사가 제공하는 서비스를 이용하는 고객을 말합니다.\n'
                          '③ "아이디(ID)"라 함은 회원의 식별과 서비스 이용을 위하여 회원이 설정하고 회사가 승인하는 문자와 숫자의 조합을 의미합니다.\n\n'
                          '제3조 (약관의 효력 및 변경)\n'
                          '① 본 약관은 서비스를 이용하고자 하는 모든 회원에 대하여 그 효력을 발생합니다.\n'
                          '② 회사는 필요하다고 인정되는 경우, 본 약관을 변경할 수 있으며, 변경된 약관은 회사가 제공하는 서비스 내에 공지함으로써 효력이 발생됩니다.\n'
                          '③ 회원은 변경된 약관에 동의하지 않을 경우 서비스 이용을 중단하고 회원 탈퇴를 요청할 수 있으며, 변경된 약관의 효력 발생일 이후에도 서비스를 계속 이용할 경우 약관의 변경사항에 동의한 것으로 간주됩니다.\n\n'
                          '제4조 (서비스 제공 및 변경)\n'
                          '① 회사는 다음과 같은 서비스를 제공합니다.\n'
                          '1. 해시태그 기반의 소셜 네트워킹 서비스\n'
                          '2. 콘텐츠 공유 서비스\n'
                          '3. 메시지 서비스\n'
                          '4. 기타 회사가 추가 개발하거나 다른 회사와의 제휴를 통해 회원에게 제공하는 서비스\n'
                          '② 회사는 서비스의 내용, 이용방법, 이용시간에 대하여 변경이 있는 경우에는 변경사유, 변경될 서비스의 내용 및 제공일자 등을 사전에 서비스 내에 공지합니다.\n\n'
                          '제5조 (서비스 이용료)\n'
                          '① 기본적인 서비스 이용은 무료입니다.\n'
                          '② 회사가 유료 서비스를 제공하는 경우, 해당 서비스의 이용 조건 및 요금은 별도 공지됩니다.\n\n'
                          
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
                          '개인정보 수집 및 이용 동의\n\n'
                          '해시타라(이하 "회사")는 개인정보보호법, 정보통신망 이용촉진 및 정보보호 등에 관한 법률 등 관련 법령에 의거하여 본 동의서를 통해 개인정보의 수집 및 이용에 관한 사항을 안내드리고 있습니다.\n\n'
                          '1. 수집하는 개인정보의 항목\n'
                          '- 필수 항목: 이메일 주소, 비밀번호, 이름, 사용자명, 프로필 이미지\n'
                          '- 선택 항목: 위치 정보, 관심사, 소개, 기기 정보, 서비스 이용 기록\n\n'
                          '2. 개인정보 수집 및 이용 목적\n'
                          '- 회원 관리: 회원제 서비스 제공, 본인 확인, 개인 식별, 불량 회원의 부정 이용 방지, 분쟁 조정을 위한 기록 보존, 민원처리, 공지사항 전달\n'
                          '- 서비스 제공: 콘텐츠 제공, 맞춤 서비스 제공, 서비스 이용 기록 통계 및 분석\n'
                          '- 마케팅 및 광고: 이벤트 및 광고성 정보 제공, 참여 기회 제공, 서비스 개선을 위한 통계 활용\n\n'
                          '3. 개인정보 보유 및 이용 기간\n'
                          '- 회원 탈퇴 시까지\n'
                          '- 단, 관계 법령의 규정에 의하여 보존할 필요가 있는 경우, 해당 법령에서 정한 기간 동안 개인정보를 보관합니다.\n'
                          '  • 전자상거래 등에서의 소비자 보호에 관한 법률: 계약 또는 청약철회 등 관련 기록 (5년), 대금결제 및 재화 등의 공급에 관한 기록 (5년), 소비자 불만 또는 분쟁처리에 관한 기록 (3년)\n'
                          '  • 통신비밀보호법: 로그인 기록 (3개월)\n\n'
                          '4. 동의 거부 권리 및 거부 시 불이익\n'
                          '- 필수 항목에 대한 동의를 거부할 경우 회원 가입 및 서비스 이용이 제한됩니다.\n'
                          '- 선택 항목에 대한 동의를 거부하더라도 서비스 이용에 제한은 없으나, 일부 서비스 이용에 제약이 있을 수 있습니다.\n\n'
                          '5. 개인정보의 제3자 제공\n'
                          '- 회사는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다. 다만, 아래의 경우에는 예외로 합니다.\n'
                          '  • 이용자가 사전에 동의한 경우\n'
                          '  • 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우\n\n'
                          
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
                          '마케팅 목적 개인정보 수집 및 이용 동의\n\n'
                          '1. 수집하는 개인정보 항목\n'
                          '- 이메일 주소, 서비스 이용 기록, 접속 로그, 관심 해시태그, 검색 키워드\n\n'
                          '2. 개인정보 수집 및 이용 목적\n'
                          '- 신규 서비스 및 이벤트 정보 안내\n'
                          '- 맞춤형 광고 제공\n'
                          '- 서비스 이용 통계 분석\n'
                          '- 이벤트 및 프로모션 안내\n\n'
                          '3. 개인정보 보유 및 이용 기간\n'
                          '- 마케팅 동의 철회 시 또는 회원 탈퇴 시까지\n\n'
                          '4. 동의 거부권 및 불이익\n'
                          '- 본 마케팅 목적 개인정보 수집 및 이용 동의는 선택사항입니다.\n'
                          '- 동의를 거부하더라도 서비스 이용에 제한이 없습니다.\n'
                          '- 다만, 동의하지 않을 경우 맞춤형 혜택 및 이벤트 정보 제공 등의 서비스를 받지 못할 수 있습니다.\n\n'
                          '※ 마케팅 동의 변경은 설정 메뉴에서 언제든지 변경 가능합니다.',
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
                        ? const CupertinoActivityIndicator(color: AppColors.white)
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