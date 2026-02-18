import 'package:flutter/material.dart';

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
      attachmentUrl: json['attachmentUrl'] as String?,
      publishedDate: json['publishedDate'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
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
        return Icons.grading_rounded;
      case 'application_forms':
        return Icons.assignment_rounded;
      case 'exam_centers':
        return Icons.place_rounded;
      case 'routines':
        return Icons.calendar_today_rounded;
      default:
        return Icons.notifications_active_rounded;
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
      case 'routines':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF8B5CF6); // Violet
    }
  }

  String get categoryDisplay {
    switch (category.toLowerCase()) {
      case 'results':
        return 'Results';
      case 'application_forms':
        return 'Application Forms';
      case 'exam_centers':
        return 'Exam Centers';
      case 'routines':
        return 'Routines';
      default:
        return 'General';
    }
  }
}

class NoticeStats {
  final int total;
  final int newCount;
  final int beResults;
  final int mscResults;
  final int beRoutines;
  final int mscRoutines;

  NoticeStats({
    required this.total,
    required this.newCount,
    required this.beResults,
    required this.mscResults,
    required this.beRoutines,
    required this.mscRoutines,
  });

  factory NoticeStats.fromJson(Map<String, dynamic> json) {
    return NoticeStats(
      total: json['total'] as int? ?? 0,
      newCount: json['newCount'] as int? ?? 0,
      beResults: json['beResults'] as int? ?? 0,
      mscResults: json['mscResults'] as int? ?? 0,
      beRoutines: json['beRoutines'] as int? ?? 0,
      mscRoutines: json['mscRoutines'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'newCount': newCount,
    'beResults': beResults,
    'mscResults': mscResults,
    'beRoutines': beRoutines,
    'mscRoutines': mscRoutines,
  };
}
