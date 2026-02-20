import 'package:smart_pulchowk/core/services/api_service.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? image;
  final bool isVerifiedSeller;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.image,
    required this.isVerifiedSeller,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      image: ApiService.processImageUrl(json['image']?.toString()),
      isVerifiedSeller: json['isVerifiedSeller'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'image': image,
      'isVerifiedSeller': isVerifiedSeller,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
