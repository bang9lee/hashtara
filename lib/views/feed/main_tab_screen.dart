import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/profile_provider.dart';
import '../feed/chat_list_screen.dart'; 
import 'create_post_screen.dart';
import 'home_screen.dart';
import 'hashtag_explore_screen.dart';
import '../profile/profile_screen.dart';


// 하단 탭 인덱스를 저장하는 프로바이더
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// UI 새로고침을 위한 프로바이더 (값이 변경될 때마다 UI가 업데이트됨)
final uiRefreshProvider = StateProvider<int>((ref) => 0);

// 홈 탭 내비게이터 키
final homeNavigatorKey = GlobalKey<NavigatorState>();

// 홈 탭 재설정 프로바이더 - 홈 탭 내용을 강제로 리셋하기 위한 용도
final homeResetProvider = StateProvider<int>((ref) => 0);

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  // 각 탭별 네비게이터 키 저장
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    homeNavigatorKey,
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];
  
  @override
  void initState() {
    super.initState();
    // 초기 로드 시 캐시 갱신
    _refreshAllData();
  }
  
  // 모든 관련 데이터 갱신 메소드 - 권한 오류 방지 추가
  void _refreshAllData() {
    debugPrint('모든 데이터 갱신 중...');
    
    // 🔥 강제 로그아웃 상태면 데이터 갱신 중단
    final forceLogout = ref.read(forceLogoutProvider);
    if (forceLogout) {
      debugPrint('🔥 강제 로그아웃 상태 - 데이터 갱신 중단');
      return;
    }
    
    // 현재 인증된 사용자가 있는지 확인
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      if (user != null) {
        try {
          // 사용자 정보 갱신
          final refresh1 = ref.refresh(currentUserProvider);
          
          // 사용자 프로필 갱신 - 
          final refresh2 = ref.refresh(getUserProfileProvider(user.uid));
          
          // 사용자 게시물 리스트 갱신
          final refresh3 = ref.refresh(userPostsProvider(user.uid));
          
          // 채팅 관련 데이터 갱신
          final refresh4 = ref.refresh(userChatsProvider(user.uid));
          final refresh5 = ref.refresh(unreadMessagesCountProvider(user.uid));
          
          // Lint 경고 제거를 위한 사용
          debugPrint('Provider 갱신 완료: ${refresh1.hashCode}, ${refresh2.hashCode}, ${refresh3.hashCode}, ${refresh4.hashCode}, ${refresh5.hashCode}');
          
          // 프로필 정보 명시적 로딩
          ref.read(profileControllerProvider.notifier).loadProfile(user.uid);
          
          debugPrint('사용자 ${user.uid} 데이터 갱신 완료');
        } catch (e) {
          debugPrint('🔥 데이터 갱신 중 오류 (무시): $e');
        }
      } else {
        debugPrint('🔥 로그인된 사용자가 없음 - 데이터 갱신 건너뜀');
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
    
    // 읽지 않은 메시지 수
    final unreadMessagesCount = currentUser.whenData((user) => user != null ? 
      ref.watch(unreadMessagesCountProvider(user.id)) : 
      const AsyncValue<int>.data(0)
    );
    
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
          // 게시물 작성 탭 - 이미지로 변경
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
          _buildChatTabItem(unreadMessagesCount),
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
          
          // 🔥 탭 변경 시 항상 해당 탭의 루트로 이동
          if (currentIndex == index && _navigatorKeys[index].currentState != null) {
            // 같은 탭을 다시 누른 경우: 해당 탭의 루트로 이동
            _navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
            
            // 각 탭별 데이터 갱신
            if (index == 0) {
              // 홈 탭: 피드 데이터 갱신
              // ignore: unused_result
              ref.refresh(feedPostsProvider);
            } else if (index == 1) {
              // 검색 탭: 필요시 검색 데이터 초기화
              // ref.refresh(searchProvider);
            } else if (index == 3) {
              // 채팅 탭: 채팅 목록 갱신
              final user = ref.read(currentUserProvider).valueOrNull;
              if (user != null) {
                // ignore: unused_result
                ref.refresh(userChatsProvider(user.id));
              }
            } else if (index == 4) {
              // 프로필 탭: 프로필 데이터 갱신
              final user = ref.read(currentUserProvider).valueOrNull;
              if (user != null) {
                // ignore: unused_result
                ref.refresh(getUserProfileProvider(user.id));
                // ignore: unused_result
                ref.refresh(userPostsProvider(user.id));
              }
            }
          } else {
            // 다른 탭으로 이동하는 경우
            ref.read(bottomNavIndexProvider.notifier).state = index;
            
            // 🔥 탭 변경 직후 해당 탭의 루트로 이동
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_navigatorKeys[index].currentState != null) {
                _navigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
              }
            });
          }
          
          // 데이터 갱신
          _refreshAllData();
          
          // UI 강제 갱신 트리거
          ref.read(uiRefreshProvider.notifier).state += 1;
        },
      ),
      tabBuilder: (context, index) {
        // 각 탭에 해당하는 화면 반환
        switch (index) {
          case 0:
            return CupertinoTabView(
              navigatorKey: _navigatorKeys[0],
              builder: (_) => const HomeScreen(),
            );
          case 1:
            return CupertinoTabView(
              navigatorKey: _navigatorKeys[1],
              builder: (_) => const HashtagExploreScreen(),
            );
          case 2:
            // 실제로는 바텀 탭 onTap에서 모달로 열림
            return CupertinoTabView(
              navigatorKey: _navigatorKeys[2],
              builder: (_) => const HomeScreen(),
            );
          case 3:
            // 채팅 화면
            return CupertinoTabView(
              navigatorKey: _navigatorKeys[3],
              builder: (_) => const ChatsListScreen(),
            );
          case 4:
            // 프로필 화면 - 로그인된 사용자가 있는 경우 프로필 화면 표시
            return CupertinoTabView(
              navigatorKey: _navigatorKeys[4],
              builder: (context) {
                // 로그인 상태를 확인
                final authState = ref.watch(authStateProvider);
                
                return authState.when(
                  data: (user) {
                    if (user != null) {
                      return ProfileScreen(userId: user.uid);
                    } else {
                      return const Center(
                        child: Text(
                          '로그인이 필요합니다',
                          style: TextStyle(color: AppColors.white),
                        ),
                      );
                    }
                  },
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                  error: (e, stack) => Center(
                    child: Text(
                      '사용자 정보를 불러올 수 없습니다: $e',
                      style: const TextStyle(color: AppColors.white),
                    ),
                  ),
                );
              },
            );
          default:
            return CupertinoTabView(
              builder: (_) => const HomeScreen(),
            );
        }
      },
    );
  }
  
  // 채팅 탭 아이템 위젯 (읽지 않은 메시지 뱃지 표시)
  BottomNavigationBarItem _buildChatTabItem(AsyncValue<AsyncValue<int>> unreadCountAsync) {
    return BottomNavigationBarItem(
      icon: Stack(
        children: [
          const Icon(CupertinoIcons.bubble_left),
          // 읽지 않은 메시지 수
          unreadCountAsync.when(
            data: (unreadCountValue) => unreadCountValue.when(
              data: (count) => count > 0 ? 
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      activeIcon: Stack(
        children: [
          const Icon(CupertinoIcons.bubble_left_fill),
          // 읽지 않은 메시지 수
          unreadCountAsync.when(
            data: (unreadCountValue) => unreadCountValue.when(
              data: (count) => count > 0 ? 
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}