class CommentUser {
  final String id;
  final String mongoId;
  final String googleId;
  final String name;
  final String profilePic;

  const CommentUser({
    required this.id,
    this.mongoId = '',
    this.googleId = '',
    required this.name,
    required this.profilePic,
  });

  factory CommentUser.fromJson(dynamic json) {
    if (json is! Map) {
      return const CommentUser(
        id: '',
        name: 'Vayu User',
        profilePic: '',
      );
    }

    final idStr = (json['id'] ?? json['googleId'] ?? json['_id'] ?? '').toString();
    final mongoIdStr = (json['_id'] ?? '').toString();
    final googleIdStr = (json['googleId'] ?? '').toString();
    final nameStr = (json['name'] ?? 'Vayu User').toString().trim();
    final profilePicStr = (json['profilePic'] ?? '').toString().trim();

    return CommentUser(
      id: idStr.isNotEmpty ? idStr : 'unknown',
      mongoId: mongoIdStr,
      googleId: googleIdStr,
      name: nameStr.isNotEmpty ? nameStr : 'Vayu User',
      profilePic: profilePicStr,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        '_id': mongoId,
        'googleId': googleId,
        'name': name,
        'profilePic': profilePic,
      };
}

class CommentModel {
  final String id;
  final String videoId;
  final String content;
  final CommentUser user;
  int likes;
  bool isLiked;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.videoId,
    required this.content,
    required this.user,
    this.likes = 0,
    this.isLiked = false,
    required this.createdAt,
  });

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'just now';
    }
  }

  String get formattedLikes {
    if (likes <= 0) return '';
    if (likes < 1000) return likes.toString();
    if (likes < 1000000) return '${(likes / 1000).toStringAsFixed(1)}K';
    return '${(likes / 1000000).toStringAsFixed(1)}M';
  }

  CommentModel copyWith({
    String? id,
    String? videoId,
    String? content,
    CommentUser? user,
    int? likes,
    bool? isLiked,
    DateTime? createdAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      content: content ?? this.content,
      user: user ?? this.user,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CommentModel.fromJson(Map<String, dynamic> json, {String? targetVideoId}) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final videoId = (json['targetId'] ?? targetVideoId ?? '').toString();
    final content = (json['content'] ?? '').toString();
    final user = CommentUser.fromJson(json['user']);
    final likes = (json['likes'] is int)
        ? json['likes']
        : int.tryParse(json['likes']?.toString() ?? '0') ?? 0;
    final isLiked = json['isLiked'] == true;
    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();

    return CommentModel(
      id: id,
      videoId: videoId,
      content: content,
      user: user,
      likes: likes,
      isLiked: isLiked,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'id': id,
        'targetId': videoId,
        'content': content,
        'user': user.toJson(),
        'likes': likes,
        'isLiked': isLiked,
        'createdAt': createdAt.toIso8601String(),
      };
}

class CommentPageResult {
  final List<CommentModel> comments;
  final int currentPage;
  final int totalPages;
  final int totalComments;
  final bool hasNextPage;

  const CommentPageResult({
    required this.comments,
    required this.currentPage,
    required this.totalPages,
    required this.totalComments,
    required this.hasNextPage,
  });

  factory CommentPageResult.fromJson(Map<String, dynamic> json, {String? videoId}) {
    final rawComments = json['comments'];
    final List<CommentModel> parsedComments = [];

    if (rawComments is List) {
      for (final item in rawComments) {
        if (item is Map<String, dynamic>) {
          parsedComments.add(CommentModel.fromJson(item, targetVideoId: videoId));
        } else if (item is Map) {
          parsedComments.add(CommentModel.fromJson(
            Map<String, dynamic>.from(item),
            targetVideoId: videoId,
          ));
        }
      }
    }

    final pagination = json['pagination'] as Map<String, dynamic>?;
    final currentPage = (pagination?['currentPage'] is int)
        ? pagination!['currentPage']
        : int.tryParse(pagination?['currentPage']?.toString() ?? '1') ?? 1;
    final totalPages = (pagination?['totalPages'] is int)
        ? pagination!['totalPages']
        : int.tryParse(pagination?['totalPages']?.toString() ?? '1') ?? 1;
    final totalComments = (pagination?['totalComments'] is int)
        ? pagination!['totalComments']
        : int.tryParse(pagination?['totalComments']?.toString() ?? '0') ??
            parsedComments.length;
    final hasNextPage = pagination?['hasNextPage'] == true;

    return CommentPageResult(
      comments: parsedComments,
      currentPage: currentPage,
      totalPages: totalPages,
      totalComments: totalComments,
      hasNextPage: hasNextPage,
    );
  }
}
