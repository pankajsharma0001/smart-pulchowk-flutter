/// Seller rating/review from a buyer
class SellerRating {
  final int id;
  final String sellerId;
  final String raterId;
  final int listingId;
  final int rating;
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RaterInfo? rater;
  final ListingInfo? listing;

  SellerRating({
    required this.id,
    required this.sellerId,
    required this.raterId,
    required this.listingId,
    required this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
    this.rater,
    this.listing,
  });

  factory SellerRating.fromJson(Map<String, dynamic> json) {
    return SellerRating(
      id: _parseInt(json['id']) ?? 0,
      sellerId: json['sellerId'] as String? ?? '',
      raterId: json['raterId'] as String? ?? '',
      listingId: _parseInt(json['listingId']) ?? 0,
      rating: _parseInt(json['rating']) ?? 0,
      review: json['review'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      rater: json['rater'] != null
          ? RaterInfo.fromJson(json['rater'] as Map<String, dynamic>)
          : null,
      listing: json['listing'] != null
          ? ListingInfo.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Basic rater information
class RaterInfo {
  final String id;
  final String name;
  final String? image;

  RaterInfo({required this.id, required this.name, this.image});

  factory RaterInfo.fromJson(Map<String, dynamic> json) {
    return RaterInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      image: json['image'] as String?,
    );
  }
}

/// Basic listing information for ratings
class ListingInfo {
  final int id;
  final String title;

  ListingInfo({required this.id, required this.title});

  factory ListingInfo.fromJson(Map<String, dynamic> json) {
    return ListingInfo(
      id: SellerRating._parseInt(json['id']) ?? 0,
      title: json['title'] as String? ?? '',
    );
  }
}

/// Seller reputation summary
class SellerReputation {
  final double averageRating;
  final int totalRatings;
  final int soldCount;
  final Map<int, int> distribution; // star count -> number of ratings
  final List<SellerRating> recentRatings;

  SellerReputation({
    required this.averageRating,
    required this.totalRatings,
    required this.soldCount,
    required this.distribution,
    required this.recentRatings,
  });

  factory SellerReputation.fromJson(Map<String, dynamic> json) {
    Map<int, int> dist = {};
    if (json['distribution'] != null) {
      final distMap = json['distribution'] as Map<String, dynamic>;
      distMap.forEach((key, value) {
        final star = int.tryParse(key);
        if (star != null && value is int) {
          dist[star] = value;
        }
      });
    }

    return SellerReputation(
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      soldCount: (json['soldCount'] as num?)?.toInt() ?? 0,
      distribution: dist,
      recentRatings:
          (json['recentRatings'] as List?)
              ?.map((e) => SellerRating.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Get a display string for the rating
  String get displayRating {
    if (totalRatings == 0) return 'No ratings yet';
    return '${averageRating.toStringAsFixed(1)} ($totalRatings ${totalRatings == 1 ? 'review' : 'reviews'})';
  }
}

/// Blocked user information
class BlockedUser {
  final int id;
  final String blockerId;
  final String blockedUserId;
  final String? reason;
  final DateTime createdAt;
  final BlockedUserInfo? blockedUser;

  BlockedUser({
    required this.id,
    required this.blockerId,
    required this.blockedUserId,
    this.reason,
    required this.createdAt,
    this.blockedUser,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: SellerRating._parseInt(json['id']) ?? 0,
      blockerId: json['blockerId'] as String? ?? '',
      blockedUserId: json['blockedUserId'] as String? ?? '',
      reason: json['reason'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      blockedUser: json['blockedUser'] != null
          ? BlockedUserInfo.fromJson(
              json['blockedUser'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Basic blocked user info
class BlockedUserInfo {
  final String id;
  final String name;
  final String email;
  final String? image;

  BlockedUserInfo({
    required this.id,
    required this.name,
    required this.email,
    this.image,
  });

  factory BlockedUserInfo.fromJson(Map<String, dynamic> json) {
    return BlockedUserInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      image: json['image'] as String?,
    );
  }
}

/// Marketplace report
class MarketplaceReport {
  final int id;
  final String reporterId;
  final String reportedUserId;
  final int? listingId;
  final ReportCategory category;
  final String description;
  final ReportStatus status;
  final String? resolutionNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReportUserInfo? reporter;
  final ReportUserInfo? reportedUser;
  final ReportUserInfo? reviewer;
  final ListingInfo? listing;

  MarketplaceReport({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    this.listingId,
    required this.category,
    required this.description,
    required this.status,
    this.resolutionNotes,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.reporter,
    this.reportedUser,
    this.reviewer,
    this.listing,
  });

  factory MarketplaceReport.fromJson(Map<String, dynamic> json) {
    return MarketplaceReport(
      id: SellerRating._parseInt(json['id']) ?? 0,
      reporterId: json['reporterId'] as String? ?? '',
      reportedUserId: json['reportedUserId'] as String? ?? '',
      listingId: SellerRating._parseInt(json['listingId']),
      category: ReportCategory.fromString(
        json['category'] as String? ?? 'other',
      ),
      description: json['description'] as String? ?? '',
      status: ReportStatus.fromString(json['status'] as String? ?? 'open'),
      resolutionNotes: json['resolutionNotes'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'] as String)
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      reporter: json['reporter'] != null
          ? ReportUserInfo.fromJson(json['reporter'] as Map<String, dynamic>)
          : null,
      reportedUser: json['reportedUser'] != null
          ? ReportUserInfo.fromJson(
              json['reportedUser'] as Map<String, dynamic>,
            )
          : null,
      reviewer: json['reviewer'] != null
          ? ReportUserInfo.fromJson(json['reviewer'] as Map<String, dynamic>)
          : null,
      listing: json['listing'] != null
          ? ListingInfo.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// User info in reports
class ReportUserInfo {
  final String id;
  final String name;
  final String? email;

  ReportUserInfo({required this.id, required this.name, this.email});

  factory ReportUserInfo.fromJson(Map<String, dynamic> json) {
    return ReportUserInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

/// Report category enum
enum ReportCategory {
  spam('spam'),
  fraud('fraud'),
  abusive('abusive'),
  fakeListing('fake_listing'),
  suspiciousPayment('suspicious_payment'),
  other('other');

  final String value;
  const ReportCategory(this.value);

  static ReportCategory fromString(String value) {
    return ReportCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportCategory.other,
    );
  }

  String get displayName {
    switch (this) {
      case ReportCategory.spam:
        return 'Spam';
      case ReportCategory.fraud:
        return 'Fraud';
      case ReportCategory.abusive:
        return 'Abusive Behavior';
      case ReportCategory.fakeListing:
        return 'Fake Listing';
      case ReportCategory.suspiciousPayment:
        return 'Suspicious Payment';
      case ReportCategory.other:
        return 'Other';
    }
  }
}

/// Report status enum
enum ReportStatus {
  open('open'),
  inReview('in_review'),
  resolved('resolved'),
  rejected('rejected');

  final String value;
  const ReportStatus(this.value);

  static ReportStatus fromString(String value) {
    return ReportStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportStatus.open,
    );
  }

  String get displayName {
    switch (this) {
      case ReportStatus.open:
        return 'Open';
      case ReportStatus.inReview:
        return 'In Review';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.rejected:
        return 'Rejected';
    }
  }
}
