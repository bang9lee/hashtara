import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/hashtag_channel_provider.dart';
import '../../../models/hashtag_channel_model.dart';
import '../../../models/post_model.dart';
import '../widgets/post_card.dart';

// 네비게이션 안전성을 위한 프로바이더
final channelDetailNavLockProvider = StateProvider<bool>((ref) => false);

class HashtagChannelDetailScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String channelName;

  const HashtagChannelDetailScreen({
    Key? key,
    required this.channelId,
    required this.channelName,
  }) : super(key: key);

  @override
  ConsumerState<HashtagChannelDetailScreen> createState() => _HashtagChannelDetailScreenState();
}

class _HashtagChannelDetailScreenState extends ConsumerState<HashtagChannelDetailScreen> {
  List<PostModel> _posts = []; 
  bool _isLoadingPosts = true;
  String? _errorMessage;
  bool _isSubscriptionLoading = false;
  bool _isNavigating = false; // 네비게이션 상태 추적을 위한 변수
  
  @override
  void initState() {
    super.initState();
    _loadPosts();
    
    // 화면 진입 시 채널 게시물 수 업데이트 및 네비게이션 락 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateChannelPostsCount();
      // 네비게이션 락 초기화
      ref.read(channelDetailNavLockProvider.notifier).state = false;
      setState(() {
        _isNavigating = false;
      });
    });
  }
  
  // 채널 게시물 수 업데이트 
  Future<void> _updateChannelPostsCount() async {
    try {
      await ref.read(hashtagChannelControllerProvider.notifier)
          .updateChannelPostsCount(widget.channelName);
    } catch (e) {
      debugPrint('게시물 수 업데이트 실패: $e');
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoadingPosts = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final hashtagToSearch = '#${widget.channelName}';

      final postsSnapshot = await firestore
          .collection('posts')
          .where('hashtags', arrayContains: hashtagToSearch)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      // Firestore 문서를 PostModel로 변환
      final posts = postsSnapshot.docs.map((doc) {
        try {
          return PostModel.fromFirestore(doc);
        } catch (e) {
          debugPrint('게시물 파싱 오류: $e');
          return null;
        }
      }).where((post) => post != null).cast<PostModel>().toList();

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoadingPosts = false;
          
          // 게시물 수 업데이트
          if (_posts.isNotEmpty) {
            _updateChannelPostsCount();
          }
        });
      }
    } catch (e) {
      debugPrint('게시물 로드 오류: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '게시물을 불러오는 중 오류가 발생했습니다.';
          _isLoadingPosts = false;
        });
      }
    }
  }

  // 구독 버튼 클릭 핸들러
  Future<void> _handleSubscription() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      // 로그인 안 된 경우 처리
      _showLoginRequiredDialog();
      return;
    }

    // 중복 클릭 방지
    if (_isSubscriptionLoading) return;

    setState(() {
      _isSubscriptionLoading = true;
    });

    try {
      // 구독 상태에 따라 다른 메서드 호출
      final subKey = '$user.uid:${widget.channelId}';
      final isSubscribed = ref.read(channelSubscriptionProvider(subKey)).valueOrNull ?? false;
      
      final channelController = ref.read(hashtagChannelControllerProvider.notifier);
      
      if (isSubscribed) {
        await channelController.unsubscribeFromChannel(user.uid, widget.channelId);
      } else {
        await channelController.subscribeToChannel(user.uid, widget.channelId);
      }
    } catch (e) {
      debugPrint('구독 처리 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubscriptionLoading = false;
        });
      }
    }
  }

  // 로그인 필요 다이얼로그
  void _showLoginRequiredDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('로그인 필요'),
        content: const Text('채널을 구독하려면 로그인이 필요합니다.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 채널 정보 
    final channelAsync = ref.watch(hashtagChannelProvider(widget.channelId));
    // 현재 사용자
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    // 네비게이션 잠금 상태
    final isLocalNavLocked = ref.watch(channelDetailNavLockProvider);
    final isNavLocked = isLocalNavLocked || _isNavigating;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.darkBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryPurple,
        border: const Border(bottom: BorderSide(color: AppColors.separator)),
        middle: Text(
          '#${widget.channelName}',
          style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: isNavLocked 
            ? null 
            : () {
              // 네비게이션 락 설정 (중복 네비게이션 방지)
              setState(() { _isNavigating = true; });
              ref.read(channelDetailNavLockProvider.notifier).state = true;
              Navigator.pop(context);
            },
          child: const Icon(CupertinoIcons.back, color: AppColors.white),
        ),
        trailing: currentUser != null
            ? _buildSubscriptionButton(currentUser.id)
            : null,
      ),
      child: SafeArea(
        child: channelAsync.when(
          data: (channel) {
            if (channel == null) {
              return const Center(child: Text('채널을 찾을 수 없습니다.', style: TextStyle(color: AppColors.textEmphasis)));
            }
            
            return Column(
              children: [
                _buildChannelHeader(channel, currentUser?.id, isNavLocked),
                Expanded(
                  child: _isLoadingPosts
                      ? const Center(child: CupertinoActivityIndicator())
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: AppColors.textSecondary),
                                  const SizedBox(height: 16),
                                  Text(_errorMessage!, style: const TextStyle(color: AppColors.textEmphasis), textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  CupertinoButton(
                                    onPressed: isNavLocked ? null : _loadPosts, 
                                    child: const Text('다시 시도')
                                  ),
                                ],
                              ),
                            )
                          : _posts.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.photo, size: 60, color: AppColors.textSecondary),
                                      SizedBox(height: 16),
                                      Text('이 채널에는 아직 게시물이 없습니다.\n첫 번째 게시물을 작성해보세요!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textEmphasis, fontSize: 16)),
                                    ],
                                  ),
                                )
                              : Material( 
                                  color: Colors.transparent,
                                  child: RefreshIndicator(
                                    onRefresh: () async {
                                      if (!isNavLocked) {
                                        await _loadPosts();
                                        await _updateChannelPostsCount(); 
                                      }
                                    },
                                    color: AppColors.primaryPurple,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16.0),
                                      itemCount: _posts.length,
                                      itemBuilder: (context, index) {
                                        final post = _posts[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 16.0),
                                          child: isNavLocked
                                            ? Opacity(
                                                opacity: 0.7,
                                                child: PostCard(
                                                  post: post,
                                                  showFullCaption: false,
                                                ),
                                              )
                                            : PostCard(
                                                post: post,
                                                showFullCaption: false,
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(child: Text('채널 정보를 불러오는 중 오류가 발생했습니다: $error', style: const TextStyle(color: AppColors.textEmphasis))),
        ),
      ),
    );
  }

  Widget _buildSubscriptionButton(String userId) {
    // 문자열 키로 구독 상태 조회
    final subKey = '$userId:${widget.channelId}';
    final subscriptionState = ref.watch(channelSubscriptionProvider(subKey));
    
    // 채널 구독 컨트롤러
    final channelController = ref.watch(hashtagChannelControllerProvider);
    
    // 컨트롤러의 상태와 구독 상태 모두 고려하여 로딩 상태 결정
    final isLoading = subscriptionState.isLoading || channelController.isLoading || _isSubscriptionLoading;
    final isNavLocked = ref.watch(channelDetailNavLockProvider) || _isNavigating;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: (isLoading || isNavLocked) 
        ? null 
        : () {
          // 네비게이션 잠금 상태에서는 작동하지 않음
          if (isNavLocked) return;
          
          // 로딩 중이면 중복 클릭 방지
          if (isLoading) return;
          
          _handleSubscription();
        },
      child: subscriptionState.when(
        data: (isSubscribed) {
          return Icon(
            isSubscribed ? CupertinoIcons.bell_fill : CupertinoIcons.bell, 
            color: isSubscribed ? CupertinoColors.systemYellow : AppColors.white
          );
        },
        loading: () => const CupertinoActivityIndicator(radius: 12),
        error: (_, __) => const Icon(CupertinoIcons.bell_slash, color: AppColors.white),
      ),
    );
  }

  Widget _buildChannelHeader(HashtagChannelModel channel, String? userId, bool isNavLocked) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground, 
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple, 
                  shape: BoxShape.circle
                ),
                child: const Center(
                  child: Icon(CupertinoIcons.number, color: AppColors.white, size: 20)
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${channel.name}', 
                      style: const TextStyle(
                        color: AppColors.white, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_2_fill, 
                          color: AppColors.textSecondary, 
                          size: 14
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '구독자 ${_formatCount(channel.followersCount)}명', 
                          style: const TextStyle(
                            color: AppColors.textSecondary, 
                            fontSize: 12
                          )
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          CupertinoIcons.chat_bubble_2_fill, 
                          color: AppColors.textSecondary, 
                          size: 14
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '게시물 ${_formatCount(channel.postsCount)}개', 
                          style: const TextStyle(
                            color: AppColors.textSecondary, 
                            fontSize: 12
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (channel.description != null && channel.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              channel.description!, 
              style: const TextStyle(
                color: AppColors.textEmphasis, 
                fontSize: 14
              )
            ),
          ],
          const SizedBox(height: 16),
          if (userId != null)
            _buildSubscribeButton(userId, channel.id, isNavLocked)
        ],
      ),
    );
  }
  
  Widget _buildSubscribeButton(String userId, String channelId, bool isNavLocked) {
    // 구독 상태 조회를 위한 키
    final subKey = '$userId:$channelId';
    
    // 구독 상태
    final subscriptionState = ref.watch(channelSubscriptionProvider(subKey));
    final channelController = ref.watch(hashtagChannelControllerProvider);
    
    final isLoading = subscriptionState.isLoading || channelController.isLoading || _isSubscriptionLoading;
    
    return subscriptionState.when(
      data: (isSubscribed) {
        return SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: isSubscribed ? AppColors.cardBackground : AppColors.primaryPurple,
            borderRadius: BorderRadius.circular(12),
            onPressed: (isLoading || isNavLocked) ? null : _handleSubscription,
            child: isLoading 
              ? const CupertinoActivityIndicator(radius: 10)
              : Text(
                  isSubscribed ? '구독해제' : '구독하기',
                  style: TextStyle(
                    color: isSubscribed ? AppColors.primaryPurple : AppColors.white,
                    fontSize: 15, 
                    fontWeight: FontWeight.w600
                  ),
                ),
          ),
        );
      },
      loading: () => SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: AppColors.cardBackground, 
          disabledColor: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12), 
          onPressed: null,
          child: const CupertinoActivityIndicator(radius: 10),
        ),
      ),
      error: (_, __) => SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(12),
          onPressed: isNavLocked ? null : _handleSubscription,
          child: const Text(
            '구독하기', 
            style: TextStyle(
              color: AppColors.white, 
              fontSize: 15, 
              fontWeight: FontWeight.w600
            )
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}