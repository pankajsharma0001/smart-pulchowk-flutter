import 'package:flutter/material.dart';

enum NotificationType {
  bookListed('book_listed'),
  messageReceived('message_received'),
  requestAccepted('request_accepted'),
  requestReceived('request_received'),
  system('system');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }
}

class InAppNotification {
  final int id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  bool isRead;
  final Map<String, dynamic>? data;

  InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: _parseInt(json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String? ?? 'system'),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  IconData get icon {
    switch (type) {
      case NotificationType.bookListed:
        return Icons.auto_stories_rounded;
      case NotificationType.messageReceived:
        return Icons.chat_bubble_rounded;
      case NotificationType.requestAccepted:
        return Icons.check_circle_rounded;
      case NotificationType.requestReceived:
        return Icons.shopping_cart_rounded;
      case NotificationType.system:
        return Icons.notifications_active_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.bookListed:
        return Colors.blue;
      case NotificationType.messageReceived:
        return Colors.green;
      case NotificationType.requestAccepted:
        return Colors.purple;
      case NotificationType.requestReceived:
        return Colors.orange;
      case NotificationType.system:
        return Colors.indigo;
    }
  }
}
