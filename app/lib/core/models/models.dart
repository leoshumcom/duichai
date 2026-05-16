/// 用户模型
class User {
  final String id;
  final String email;
  final String nickname;
  final String? phone;
  final String? avatar;
  final String role;
  final int level;
  final int chaihuoBalance;
  final int totalChaihuoEarned;
  final String? inviteCode;
  final String createdAt;

  User({
    required this.id,
    required this.email,
    required this.nickname,
    this.phone,
    this.avatar,
    this.role = 'user',
    this.level = 1,
    this.chaihuoBalance = 1,
    this.totalChaihuoEarned = 0,
    this.inviteCode,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['user_id'] ?? '',
      email: json['email'] ?? '',
      nickname: json['nickname'] ?? '',
      phone: json['phone'],
      avatar: json['avatar'],
      role: json['role'] ?? 'user',
      level: json['level'] ?? 1,
      chaihuoBalance: json['chaihuo_balance'] ?? 1,
      totalChaihuoEarned: json['total_chaihuo_earned'] ?? 0,
      inviteCode: json['invite_code'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'nickname': nickname,
    'phone': phone,
    'avatar': avatar,
    'role': role,
    'level': level,
    'chaihuo_balance': chaihuoBalance,
    'total_chaihuo_earned': totalChaihuoEarned,
    'invite_code': inviteCode,
    'created_at': createdAt,
  };
}

/// 场地模型
class Venue {
  final String id;
  final String name;
  final String type;
  final String? description;
  final double latitude;
  final double longitude;
  final String? address;
  final List<String> photos;
  final List<String> videos;
  final String publisherId;
  final String? publisherName;
  final String? publisherAvatar;
  final bool isFree;
  final String? priceInfo;
  final String? openHours;
  final int chaihuoTotal;
  final String status;
  final String createdAt;
  final List<Map<String, dynamic>>? topTippers;

  Venue({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    required this.latitude,
    required this.longitude,
    this.address,
    this.photos = const [],
    this.videos = const [],
    required this.publisherId,
    this.publisherName,
    this.publisherAvatar,
    this.isFree = true,
    this.priceInfo,
    this.openHours,
    this.chaihuoTotal = 0,
    this.status = 'pending',
    required this.createdAt,
    this.topTippers,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      description: json['description'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      address: json['address'],
      photos: (json['photos'] as List?)?.cast<String>() ?? [],
      videos: (json['videos'] as List?)?.cast<String>() ?? [],
      publisherId: json['publisher_id'] ?? '',
      publisherName: json['publisher_name'],
      publisherAvatar: json['publisher_avatar'],
      isFree: json['is_free'] == 1 || json['is_free'] == true,
      priceInfo: json['price_info'],
      openHours: json['open_hours'],
      chaihuoTotal: json['chaihuo_total'] ?? 0,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
      topTippers: (json['top_tippers'] as List?)?.cast<Map<String, dynamic>>(),
    );
  }
}

/// 俱乐部模型
class Club {
  final String id;
  final String name;
  final String? avatar;
  final String? banner;
  final String? description;
  final String? slogan;
  final int memberCount;
  final int chaihuoTotal;
  final bool isCertified;
  final String creatorId;
  final String createdAt;

  Club({
    required this.id,
    required this.name,
    this.avatar,
    this.banner,
    this.description,
    this.slogan,
    this.memberCount = 1,
    this.chaihuoTotal = 0,
    this.isCertified = false,
    required this.creatorId,
    required this.createdAt,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      banner: json['banner'],
      description: json['description'],
      slogan: json['slogan'],
      memberCount: json['member_count'] ?? 1,
      chaihuoTotal: json['chaihuo_total'] ?? 0,
      isCertified: json['is_certified'] == 1 || json['is_certified'] == true,
      creatorId: json['creator_id'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
