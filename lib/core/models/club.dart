import 'dart:convert';
import '../services/api_service.dart';

class Club {
  final int id;
  final String authClubId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? email;
  final bool isActive;
  final DateTime? createdAt;
  final int upcomingEvents;
  final int completedEvents;
  final int totalParticipants;

  Club({
    required this.id,
    required this.authClubId,
    required this.name,
    this.description,
    this.logoUrl,
    this.email,
    this.isActive = true,
    this.createdAt,
    this.upcomingEvents = 0,
    this.completedEvents = 0,
    this.totalParticipants = 0,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    // Handle cases where data might be nested under 'clubData'
    final Map<String, dynamic> data = json['clubData'] is Map<String, dynamic>
        ? json['clubData'] as Map<String, dynamic>
        : json;

    final logo = data['logoUrl']?.toString() ?? json['logoUrl']?.toString();

    return Club(
      id: _parseInt(data['id']),
      authClubId: data['authClubId']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Unknown Club',
      description: data['description']?.toString(),
      logoUrl: ApiService.processImageUrl(logo),
      email: data['email']?.toString(),
      isActive: data['isActive'] == true,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
      upcomingEvents: _parseInt(
        json['upcomingEvents'] ?? data['upcomingEvents'],
      ),
      completedEvents: _parseInt(
        json['completedEvents'] ?? data['completedEvents'],
      ),
      totalParticipants: _parseInt(
        json['totalParticipants'] ?? data['totalParticipants'],
      ),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authClubId': authClubId,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'email': email,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'upcomingEvents': upcomingEvents,
      'completedEvents': completedEvents,
      'totalParticipants': totalParticipants,
    };
  }
}

class ClubProfile {
  final int id;
  final int clubId;
  final String? aboutClub;
  final String? mission;
  final String? vision;
  final String? achievements;
  final String? benefits;
  final String? contactPhone;
  final String? address;
  final String? websiteUrl;
  final Map<String, String>? socialLinks;
  final int? establishedYear;
  final int totalEventHosted;
  final DateTime? updatedAt;

  ClubProfile({
    required this.id,
    required this.clubId,
    this.aboutClub,
    this.mission,
    this.vision,
    this.achievements,
    this.benefits,
    this.contactPhone,
    this.address,
    this.websiteUrl,
    this.socialLinks,
    this.establishedYear,
    this.totalEventHosted = 0,
    this.updatedAt,
  });

  factory ClubProfile.fromJson(Map<String, dynamic> json) {
    Map<String, String>? parsedSocialLinks;
    if (json['socialLinks'] != null) {
      try {
        if (json['socialLinks'] is String) {
          final decoded = jsonDecode(json['socialLinks']);
          parsedSocialLinks = Map<String, String>.from(decoded);
        } else if (json['socialLinks'] is Map) {
          parsedSocialLinks = Map<String, String>.from(json['socialLinks']);
        }
      } catch (e) {
        // Fallback or log error
      }
    }

    return ClubProfile(
      id: Club._parseInt(json['id']),
      clubId: Club._parseInt(json['clubId']),
      aboutClub: json['aboutClub'] as String?,
      mission: json['mission'] as String?,
      vision: json['vision'] as String?,
      achievements: json['achievements'] as String?,
      benefits: json['benefits'] as String?,
      contactPhone: json['contactPhone'] as String?,
      address: json['address'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      socialLinks: parsedSocialLinks,
      establishedYear: Club._parseInt(json['establishedYear']),
      totalEventHosted: Club._parseInt(json['totalEventHosted']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}
