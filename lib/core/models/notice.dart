import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';

class Notice {
  final int id;
  final String title;
  final String category;
  final String? level;
  final String? attachmentUrl;
  final String? publishedDate;
  final String? sourceUrl;
  final String? externalRef;
  final DateTime createdAt;
  final DateTime updatedAt;

  Notice({
    required this.id,
    required this.title,
    required this.category,
    this.level,
    this.attachmentUrl,
    this.publishedDate,
    this.sourceUrl,
    this.externalRef,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      level: json['level'] as String?,
      attachmentUrl: ApiService.processImageUrl(
        (json['attachmentUrl'] ?? json['attachment_url']) as String?,
        optimizeCloudinary: false,
      ),
      publishedDate: json['publishedDate'] as String?,
      sourceUrl:
          ApiService.processImageUrl(
            (json['sourceUrl'] ?? json['source_url']) as String?,
            optimizeCloudinary: false,
          ) ??
          (json['sourceUrl'] ?? json['source_url']) as String?,
      externalRef: json['externalRef'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'level': level,
    'attachmentUrl': attachmentUrl,
    'publishedDate': publishedDate,
    'sourceUrl': sourceUrl,
    'externalRef': externalRef,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  IconData get icon {
    switch (category.toLowerCase()) {
      case 'results':
        return Icons.assignment_rounded;
      case 'application_forms':
        return Icons.description_rounded;
      case 'exam_centers':
        return Icons.location_on_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color get color {
    switch (category.toLowerCase()) {
      case 'results':
        return const Color(0xFF10B981); // Emerald
      case 'application_forms':
        return const Color(0xFF6366F1); // Indigo
      case 'exam_centers':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF8B5CF6); // Violet
    }
  }

  String get categoryDisplay {
    switch (category.toLowerCase()) {
      case 'results':
        return 'Results';
      case 'application_forms':
        return 'Forms';
      case 'exam_centers':
        return 'Centers';
      default:
        return 'General';
    }
  }

  bool get isNew {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays <= 7;
  }

  bool get isPdf {
    if (attachmentUrl == null) return false;
    return attachmentUrl!.toLowerCase().contains('.pdf');
  }

  bool get isImage {
    if (attachmentUrl == null) return false;
    final url = attachmentUrl!.toLowerCase();
    return url.contains('.jpg') ||
        url.contains('.jpeg') ||
        url.contains('.png') ||
        url.contains('.webp');
  }
}

class NoticeStats {
  final int total;
  final int newCount;
  final int beResults;
  final int mscResults;
  final int beRoutines;
  final int mscRoutines;
  final int results;
  final int applicationForms;
  final int examCenters;
  final int general;

  NoticeStats({
    required this.total,
    required this.newCount,
    required this.beResults,
    required this.mscResults,
    required this.beRoutines,
    required this.mscRoutines,
    required this.results,
    required this.applicationForms,
    required this.examCenters,
    required this.general,
  });

  factory NoticeStats.fromJson(Map<String, dynamic> json) {
    return NoticeStats(
      total: json['total'] as int? ?? 0,
      newCount: json['newCount'] as int? ?? 0,
      beResults: json['beResults'] as int? ?? 0,
      mscResults: json['mscResults'] as int? ?? 0,
      beRoutines: json['beRoutines'] as int? ?? 0,
      mscRoutines: json['mscRoutines'] as int? ?? 0,
      results: json['results'] as int? ?? 0,
      applicationForms: json['applicationForms'] as int? ?? 0,
      examCenters: json['examCenters'] as int? ?? 0,
      general: json['general'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'newCount': newCount,
    'beResults': beResults,
    'mscResults': mscResults,
    'beRoutines': beRoutines,
    'mscRoutines': mscRoutines,
    'results': results,
    'applicationForms': applicationForms,
    'examCenters': examCenters,
    'general': general,
  };
}
