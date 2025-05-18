import 'package:cloud_firestore/cloud_firestore.dart';

class HashtagChannelModel {
  final String id;
  final String name; // 해시태그 이름 (# 제외)
  final String? description;
  int followersCount;
  int postsCount;
  final DateTime createdAt;
  final String? coverImageUrl;
  
  HashtagChannelModel({
    required this.id,
    required this.name,
    this.description,
    this.followersCount = 0,
    this.postsCount = 0,
    required this.createdAt,
    this.coverImageUrl,
  });
  
  factory HashtagChannelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HashtagChannelModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      followersCount: data['followersCount'] ?? 0,
      postsCount: data['postsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      coverImageUrl: data['coverImageUrl'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'followersCount': followersCount,
      'postsCount': postsCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'coverImageUrl': coverImageUrl,
    };
  }
  
  // 게시물 수 업데이트 메서드 (추가된 부분)
  void updatePostsCount(int newCount) {
    postsCount = newCount;
  }
  
  // 해시태그 포맷팅 메서드 (# 추가)
  String get formattedName => '#$name';
  
  // 해시태그 처리용 유틸리티 메서드 추가
  static List<String> extractHashtags(String text) {
    if (text.isEmpty) return [];
    
    // 해시태그 정규표현식: #으로 시작하고 공백이나 특수문자로 끝나지 않는 문자열
    final regex = RegExp(r'#([a-zA-Z0-9가-힣_]+)');
    final matches = regex.allMatches(text);
    
    // 결과 반환 (#없이 소문자로 변환)
    final tags = matches
        .map((match) => match.group(1))
        .where((tag) => tag != null && tag.isNotEmpty)
        .map((tag) => tag!.toLowerCase())
        .toList();
    
    // 중복 제거
    return tags.toSet().toList();
  }
  
  // 해시태그 목록을 포맷팅하는 메서드 (# 추가)
  static List<String> formatHashtags(List<String> tags) {
    return tags.map((tag) => '#$tag').toList();
  }

  @override
  String toString() {
    return 'HashtagChannelModel(id: $id, name: $name, followersCount: $followersCount, postsCount: $postsCount)';
  }
}