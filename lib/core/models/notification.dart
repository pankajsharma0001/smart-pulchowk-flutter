import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';

enum NotificationType {
  // Marketplace
  bookListed('book_listed'),
  newBook('new_book'),
  purchaseRequest('purchase_request'),
  requestResponse('request_response'),
  purchaseRequestCancelled('purchase_request_cancelled'),
  purchaseRequestRemoved('purchase_request_removed'),
  // Chat
  chatMessage('chat_message'),
  chatMention('chat_mention'),
  // Events
  newEvent('new_event'),
  eventPublished('event_published'),
  eventReminder('event_reminder'),
  eventUpdated('event_updated'),
  eventRegistered('event_registered'),
  // Notices
  noticeCreated('notice_created'),
  noticeUpdated('notice_updated'),
  noticeDeleted('notice_deleted'),
  // Lost & Found
  lostFoundClaimReceived('lost_found_claim_received'),
  lostFoundClaimAccepted('lost_found_claim_accepted'),
  lostFoundClaimRejected('lost_found_claim_rejected'),
  lostFoundPublished('lost_found_published'),
  // Classroom
  newAssignment('new_assignment'),
  gradingUpdate('grading_update'),
  assignmentDeadline('assignment_deadline'),
  // System / Admin
  roleChanged('role_changed'),
  securityAlert('security_alert'),
  systemAnnouncement('system_announcement'),
  sellerVerified('seller_verified'),
  sellerRevoked('seller_revoked'),
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

  // Enriched fields parsed from [data]
  final String? thumbnailUrl;
  final String? actorAvatarUrl;
  final String? actorName;

  bool get isPdf {
    final titleLower = title.toLowerCase();
    final bodyLower = body.toLowerCase();

    // Check title/body for explicit PDF mentions
    if (titleLower.contains('pdf') || bodyLower.contains('pdf')) return true;

    // Check processed thumbnail URL
    if (thumbnailUrl?.toLowerCase().contains('.pdf') ?? false) return true;

    // Deep scan all data fields for PDF indicators
    if (data != null) {
      for (final entry in data!.entries) {
        final val = entry.value?.toString().toLowerCase() ?? '';
        if (val.isEmpty) continue;

        // Check for extension
        if (val.endsWith('.pdf') || val.contains('.pdf?')) return true;

        // Check for Google Drive PDF indicators (often have "pdf" in metadata or title in data)
        if (val.contains('drive.google.com') &&
            (titleLower.contains('notice') || bodyLower.contains('notice'))) {
          // Heuristic: If it's a notice and has a drive link, it's almost certainly a PDF
          // unless it explicitly looks like an image (which we check for elsewhere)
          return true;
        }

        // Check explicit mime/type flags
        if (entry.key.toLowerCase().contains('type') && val == 'pdf') {
          return true;
        }
      }

      // Heuristic for notices: notice_created usually implies a document/attachment
      if (type == NotificationType.noticeCreated ||
          type == NotificationType.noticeUpdated) {
        final attachment =
            data!['attachmentUrl']?.toString() ?? data!['url']?.toString();
        if (attachment != null && attachment.isNotEmpty) {
          final attLower = attachment.toLowerCase();
          final isImage =
              attLower.contains('.jpg') ||
              attLower.contains('.jpeg') ||
              attLower.contains('.png') ||
              attLower.contains('.webp');
          if (!isImage) {
            return true;
          } // If notice has attachment and it's not an image, assume PDF
        }
      }
    }

    return false;
  }

  InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
    this.thumbnailUrl,
    this.actorAvatarUrl,
    this.actorName,
  });

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;

    final rawThumb =
        data?['thumbnailUrl']?.toString() ??
        data?['bannerUrl']?.toString() ??
        data?['imageUrl']?.toString();
    final rawAvatar =
        data?['actorAvatarUrl']?.toString() ??
        data?['requesterAvatarUrl']?.toString();

    return InAppNotification(
      id: _parseInt(json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String? ?? 'system'),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      data: data,
      thumbnailUrl: ApiService.processImageUrl(rawThumb),
      actorAvatarUrl: ApiService.processImageUrl(rawAvatar),
      actorName:
          data?['actorName']?.toString() ??
          data?['buyerName']?.toString() ??
          data?['requesterName']?.toString() ??
          data?['senderName']?.toString(),
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
      case NotificationType.newBook:
        return Icons.auto_stories_rounded;
      case NotificationType.purchaseRequest:
        return Icons.shopping_cart_rounded;
      case NotificationType.requestResponse:
        return Icons.check_circle_rounded;
      case NotificationType.purchaseRequestCancelled:
      case NotificationType.purchaseRequestRemoved:
        return Icons.remove_shopping_cart_rounded;
      case NotificationType.chatMessage:
      case NotificationType.chatMention:
        return Icons.chat_bubble_rounded;
      case NotificationType.newEvent:
      case NotificationType.eventPublished:
      case NotificationType.eventReminder:
      case NotificationType.eventUpdated:
      case NotificationType.eventRegistered:
        return Icons.event_rounded;
      case NotificationType.noticeCreated:
      case NotificationType.noticeUpdated:
      case NotificationType.noticeDeleted:
        return Icons.campaign_rounded;
      case NotificationType.lostFoundClaimReceived:
      case NotificationType.lostFoundClaimAccepted:
      case NotificationType.lostFoundClaimRejected:
      case NotificationType.lostFoundPublished:
        return Icons.search_rounded;
      case NotificationType.newAssignment:
      case NotificationType.gradingUpdate:
      case NotificationType.assignmentDeadline:
        return Icons.assignment_rounded;
      case NotificationType.roleChanged:
      case NotificationType.securityAlert:
      case NotificationType.sellerRevoked:
        return Icons.shield_rounded;
      case NotificationType.sellerVerified:
        return Icons.verified_user_rounded;
      case NotificationType.systemAnnouncement:
      case NotificationType.system:
        return Icons.notifications_active_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.bookListed:
      case NotificationType.newBook:
        return Colors.blue;
      case NotificationType.purchaseRequest:
        return Colors.orange;
      case NotificationType.requestResponse:
        return Colors.green;
      case NotificationType.purchaseRequestCancelled:
      case NotificationType.purchaseRequestRemoved:
        return Colors.red;
      case NotificationType.chatMessage:
      case NotificationType.chatMention:
        return Colors.teal;
      case NotificationType.newEvent:
      case NotificationType.eventPublished:
      case NotificationType.eventReminder:
      case NotificationType.eventUpdated:
      case NotificationType.eventRegistered:
        return Colors.deepPurple;
      case NotificationType.noticeCreated:
      case NotificationType.noticeUpdated:
      case NotificationType.noticeDeleted:
        return Colors.indigo;
      case NotificationType.lostFoundClaimReceived:
      case NotificationType.lostFoundClaimAccepted:
      case NotificationType.lostFoundClaimRejected:
      case NotificationType.lostFoundPublished:
        return Colors.amber;
      case NotificationType.newAssignment:
      case NotificationType.gradingUpdate:
      case NotificationType.assignmentDeadline:
        return Colors.cyan;
      case NotificationType.roleChanged:
      case NotificationType.securityAlert:
      case NotificationType.sellerRevoked:
        return Colors.red;
      case NotificationType.sellerVerified:
        return Colors.green;
      case NotificationType.systemAnnouncement:
      case NotificationType.system:
        return Colors.blueGrey;
    }
  }
}
