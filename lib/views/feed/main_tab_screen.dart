import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart'; 
import '../../../providers/profile_provider.dart';
import '../../../providers/feed_provider.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';
import 'create_post_screen.dart';
import 'hashtag_explore_screen.dart';

// 하단 탭 인덱스를 저장하는 프로바이더
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// UI 새로고침을 위한 프로바이더 (값이 변경될 때마다 UI가 업데이트됨)
final uiRefreshProvider = StateProvider<int>((ref) => 0);

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  @override
  void initState() {
    super.initState();
    // 초기 로드 시 캐시 갱신
    _refreshAllData();
  }
  
  // 모든 관련 데이터 갱신 메소드
  void _refreshAllData() {
    debugPrint('모든 데이터 갱신 중...');
    
    // 현재 인증된 사용자가 있는지 확인
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      if (user != null) {
        // 사용자 정보 갱신
        final refresh1 = ref.refresh(currentUserProvider);
        
        // 사용자 프로필 갱신
        final refresh2 = ref.refresh(getUserProfileProvider(user.uid));
        
        // 사용자 게시물 리스트 갱신
        final refresh3 = ref.refresh(userPostsProvider(user.uid));
        
        // Lint 경고 제거를 위한 사용
        debugPrint('Provider 갱신 완료: ${refresh1.hashCode}, ${refresh2.hashCode}, ${refresh3.hashCode}');
        
        // 프로필 정보 명시적 로딩
        ref.read(profileControllerProvider.notifier).loadProfile(user.uid);
        
        debugPrint('사용자 ${user.uid} 데이터 갱신 완료');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    
    // UI 새로고침 트리거 값 감시
    final _ = ref.watch(uiRefreshProvider);
    
    // 현재 사용자 정보
    final currentUser = ref.watch(currentUserProvider);
    
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: AppColors.cardBackground,
        activeColor: AppColors.primaryPurple,
        inactiveColor: AppColors.textSecondary,
        border: const Border(
          top: BorderSide(color: AppColors.separator, width: 0.5),
        ),
        height: 60, // 탭바 높이 유지
        items: [
          // 홈 탭
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
          ),
          // 탐색 탭
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            activeIcon: Icon(CupertinoIcons.search_circle_fill),
          ),
          // 게시물 작성 탭
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Image.asset(
                  'assets/images/center.png',
                  width: 40,
                  height: 40,
                ),
              ),
            ),
          ),
          // 채팅 탭
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bubble_left),
            activeIcon: Icon(CupertinoIcons.bubble_left_fill),
          ),
          // 프로필 탭
          BottomNavigationBarItem(
            icon: currentUser.when(
              data: (user) {
                if (user?.profileImageUrl != null) {
                  return Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(user!.profileImageUrl!),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(
                        color: currentIndex == 4 
                            ? AppColors.primaryPurple 
                            : CupertinoColors.transparent,
                        width: 2,
                      ),
                    ),
                  );
                }
                return const Icon(CupertinoIcons.person_circle);
              },
              loading: () => const CupertinoActivityIndicator(),
              error: (_, __) => const Icon(CupertinoIcons.person_circle),
            ),
            activeIcon: currentUser.when(
              data: (user) {
                if (user?.profileImageUrl != null) {
                  return Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(user!.profileImageUrl!),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(
                        color: AppColors.primaryPurple,
                        width: 2,
                      ),
                    ),
                  );
                }
                return const Icon(CupertinoIcons.person_circle_fill);
              },
              loading: () => const CupertinoActivityIndicator(),
              error: (_, __) => const Icon(CupertinoIcons.person_circle_fill),
            ),
          ),
        ],
        currentIndex: currentIndex,
        onTap: (index) {
          // 게시 버튼은 모달로 CreatePostScreen 열기
          if (index == 2) {
            showCupertinoModalPopup(
              context: context,
              builder: (_) => const CreatePostScreen(),
            ).then((_) {
              // 게시물 작성 후 데이터 갱신
              _refreshAllData();
              
              // UI 강제 갱신 트리거
              ref.read(uiRefreshProvider.notifier).state += 1;
            });
            return; // 인덱스 변경 없음
          }
          
          // 프로필 탭으로 이동할 때 데이터 갱신
          if (index == 4) {
            _refreshAllData();
            
            // UI 강제 갱신 트리거
            ref.read(uiRefreshProvider.notifier).state += 1;
          }
          
          // 다른 탭은 인덱스 변경
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
      ),
      tabBuilder: (context, index) {
        // 각 탭에 해당하는 화면 반환
        switch (index) {
          case 0:
            return CupertinoTabView(
              builder: (_) => const HomeScreen(),
            );
          case 1:
            return CupertinoTabView(
              builder: (_) => const HashtagExploreScreen(),
            );
          case 2:
            // 실제로는 바텀 탭 onTap에서 모달로 열림
            return CupertinoTabView(
              builder: (_) => const HomeScreen(),
            );
          case 3:
            // 채팅 화면 (임시로 홈 화면 표시)
            return CupertinoTabView(
              builder: (_) => const Center(
                child: Text(
                  '채팅 화면 (개발 중)',
                  style: TextStyle(color: AppColors.white),
                ),
              ),
            );
          case 4:
            return CupertinoTabView(
              builder: (_) => currentUser.when(
                data: (user) => user != null
                    ? ProfileScreen(userId: user.id)
                    : const Center(
                        child: Text(
                          '로그인이 필요합니다',
                          style: TextStyle(color: AppColors.white),
                        ),
                      ),
                loading: () => const Center(
                  child: CupertinoActivityIndicator(),
                ),
                error: (_, __) => const Center(
                  child: Text(
                    '사용자 정보를 불러올 수 없습니다.',
                    style: TextStyle(color: AppColors.white),
                  ),
                ),
              ),
            );
          default:
            return CupertinoTabView(
              builder: (_) => const HomeScreen(),
            );
        }
      },
    );
  }
}