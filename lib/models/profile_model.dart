class ProfileModel {
  final String userId;
  final String? bio;
  final List<String>? interests;
  final String? location;
  final int postCount;
  final int followersCount;
  final int followingCount;
  final List<String>? favoriteHashtags; // 좋아하는 해시태그 필드 추가

  ProfileModel({
    required this.userId,
    this.bio,
    this.interests,
    this.location,
    this.postCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.favoriteHashtags, // 신규 필드
  });

  // 파이어스토어 문서에서 객체 생성
  factory ProfileModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return ProfileModel(
      userId: docId,
      bio: data['bio'],
      interests: data['interests'] != null ? List<String>.from(data['interests']) : null,
      location: data['location'],
      postCount: data['postCount'] ?? 0,
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      // 좋아하는 해시태그 데이터 파싱
      favoriteHashtags: data['favoriteHashtags'] != null ? List<String>.from(data['favoriteHashtags']) : [],
    );
  }

  // 객체를 파이어스토어 문서로 변환 (toMap => toFirestore로 메소드명 변경)
  Map<String, dynamic> toFirestore() {
    return {
      'bio': bio,
      'interests': interests,
      'location': location,
      'postCount': postCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'favoriteHashtags': favoriteHashtags, // 좋아하는 해시태그 저장
    };
  }

  // 기존의 toMap 메소드도 유지 (하위 호환성)
  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  // 복사본 생성 (데이터 갱신 시 유용함)
  ProfileModel copyWith({
    String? userId,
    String? bio,
    List<String>? interests,
    String? location,
    int? postCount,
    int? followersCount,
    int? followingCount,
    List<String>? favoriteHashtags, // 새로운 필드 포함
  }) {
    return ProfileModel(
      userId: userId ?? this.userId,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      location: location ?? this.location,
      postCount: postCount ?? this.postCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      favoriteHashtags: favoriteHashtags ?? this.favoriteHashtags, // 새로운 필드 추가
    );
  }
}