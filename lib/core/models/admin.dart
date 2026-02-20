/// Model for admin dashboard statistics
class AdminDashboardStats {
  final int users;
  final int teachers;
  final int admins;
  final int listingsAvailable;
  final int openReports;
  final int activeBlocks;
  final double averageSellerRating;
  final int ratingsCount;

  AdminDashboardStats({
    required this.users,
    required this.teachers,
    required this.admins,
    required this.listingsAvailable,
    required this.openReports,
    required this.activeBlocks,
    required this.averageSellerRating,
    required this.ratingsCount,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      users: _parseInt(json['users']) ?? 0,
      teachers: _parseInt(json['teachers']) ?? 0,
      admins: _parseInt(json['admins']) ?? 0,
      listingsAvailable: _parseInt(json['listingsAvailable']) ?? 0,
      openReports: _parseInt(json['openReports']) ?? 0,
      activeBlocks: _parseInt(json['activeBlocks']) ?? 0,
      averageSellerRating:
          (json['averageSellerRating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: _parseInt(json['ratingsCount']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Model for user management in admin panel
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String? image;
  final String role;
  final bool isVerifiedSeller;
  final DateTime? createdAt;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.image,
    required this.role,
    required this.isVerifiedSeller,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      image: json['image']?.toString(),
      role: json['role']?.toString() ?? 'student',
      isVerifiedSeller:
          json['isVerifiedSeller'] == true || json['verified'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
