import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/notification.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:smart_pulchowk/core/widgets/pdf_viewer.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';
import 'package:smart_pulchowk/features/marketplace/chat_room_page.dart';
import 'package:smart_pulchowk/features/marketplace/marketplace_activity_page.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/features/events/event_details_page.dart';

class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Handle navigation from an in-app notification tap.
  static void handleInAppNotification(InAppNotification notification) {
    final data = notification.data ?? {};
    final type = notification.type;

    switch (type) {
      case NotificationType.bookListed:
      case NotificationType.newBook:
      case NotificationType.requestResponse:
        final idStr = data['listingId'] ?? data['bookId'];
        final id = int.tryParse(idStr?.toString() ?? '');
        if (id != null) {
          _navigateToTab(
            3,
            subPage: BookDetailsPage(listing: BookListing.fromId(id)),
          );
        } else {
          _navigateToTab(3);
        }

      case NotificationType.purchaseRequest:
      case NotificationType.purchaseRequestCancelled:
      case NotificationType.purchaseRequestRemoved:
        _navigateToTab(
          3,
          subPage: const MarketplaceActivityPage(initialTabIndex: 1),
        );

      case NotificationType.chatMessage:
      case NotificationType.chatMention:
        final conversationId = int.tryParse(
          data['conversationId']?.toString() ?? '',
        );
        final senderId = data['senderId']?.toString();
        final senderName = data['senderName']?.toString() ?? 'Chat';
        if (conversationId != null) {
          _navigateToTab(
            3,
            subPage: ChatRoomPage(
              conversationId: conversationId,
              recipientId: senderId ?? '',
              recipientName: senderName,
            ),
          );
        }

      case NotificationType.newEvent:
      case NotificationType.eventPublished:
      case NotificationType.eventReminder:
      case NotificationType.eventUpdated:
      case NotificationType.eventRegistered:
        final eventId = int.tryParse(data['eventId']?.toString() ?? '');
        if (eventId != null) {
          _navigateToTab(
            6,
            subPage: EventDetailsPage(event: ClubEvent.fromId(eventId)),
          );
        } else {
          _navigateToTab(6);
        }

      case NotificationType.noticeCreated:
      case NotificationType.noticeUpdated:
      case NotificationType.noticeDeleted:
        final attachmentUrl = data['attachmentUrl']?.toString();
        final noticeTitle = data['noticeTitle']?.toString() ?? 'Notice';

        // Always switch to notices tab first so the user is in the right context
        _navigateToTab(8);

        if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
          if (notification.isPdf) {
            _navigateToRoot(
              CustomPdfViewer(url: attachmentUrl, title: noticeTitle),
            );
          } else {
            final urlLower = attachmentUrl.toLowerCase();
            final isImage =
                urlLower.contains('.jpg') ||
                urlLower.contains('.jpeg') ||
                urlLower.contains('.png') ||
                urlLower.contains('.webp');
            if (isImage) {
              _navigateToRoot(
                FullScreenImageViewer(imageUrls: [attachmentUrl]),
              );
            }
          }
        }

      case NotificationType.lostFoundClaimReceived:
      case NotificationType.lostFoundClaimAccepted:
      case NotificationType.lostFoundClaimRejected:
      case NotificationType.lostFoundPublished:
        _navigateToTab(9);

      case NotificationType.newAssignment:
      case NotificationType.gradingUpdate:
      case NotificationType.assignmentDeadline:
        _navigateToTab(2); // Classroom/Admin role tab

      case NotificationType.roleChanged:
      case NotificationType.securityAlert:
      case NotificationType.systemAnnouncement:
      case NotificationType.system:
        break; // No specific navigation
    }
  }

  /// Handle navigation based on push notification data payload.
  static void handleNotificationPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    debugPrint('Handling notification payload: $type');

    if (type == 'new_book' || type == 'request_response') {
      final listingIdIdStr = data['listingId'] ?? data['bookId'];
      if (listingIdIdStr != null) {
        final id = int.tryParse(listingIdIdStr.toString());
        if (id != null) {
          _navigateToTab(
            3, // Marketplace tab
            subPage: BookDetailsPage(listing: BookListing.fromId(id)),
          );
        }
      }
    } else if (type == 'new_purchase_request' ||
        type == 'purchase_request_cancelled') {
      _navigateToTab(
        3, // Marketplace tab
        subPage: const MarketplaceActivityPage(initialTabIndex: 1),
      );
    } else if (type == 'chat' || type == 'message') {
      final conversationId = int.tryParse(
        data['conversationId']?.toString() ?? '',
      );
      final senderId = data['senderId']?.toString();
      final senderName = data['senderName']?.toString() ?? 'Chat';

      if (conversationId != null) {
        _navigateToTab(
          3, // Marketplace tab (assuming chat is linked to marketplace activity)
          subPage: ChatRoomPage(
            conversationId: conversationId,
            recipientId: senderId ?? '',
            recipientName: senderName,
          ),
        );
      }
    } else if (type == 'lost_found_claim_received' ||
        type == 'lost_found_claim_accepted' ||
        type == 'lost_found_claim_rejected' ||
        type == 'lost_found_published') {
      _navigateToTab(9); // Lost & Found tab
    } else if (type == 'notice_created' || type == 'notice_updated') {
      final attachmentUrl = data['attachmentUrl']?.toString();
      final noticeTitle = data['noticeTitle']?.toString() ?? 'Notice';
      final body = data['body']?.toString().toLowerCase() ?? '';
      final title = data['title']?.toString().toLowerCase() ?? '';

      _navigateToTab(8);

      if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
        final urlLower = attachmentUrl.toLowerCase();

        // Robust PDF check for push payload
        final isPdf =
            urlLower.endsWith('.pdf') ||
            urlLower.contains('.pdf?') ||
            title.contains('pdf') ||
            body.contains('pdf') ||
            (urlLower.contains('drive.google.com') &&
                (title.contains('notice') || body.contains('notice')));

        final isImage =
            urlLower.endsWith('.jpg') ||
            urlLower.endsWith('.jpeg') ||
            urlLower.endsWith('.png') ||
            urlLower.endsWith('.webp');

        if (isPdf) {
          _navigateToRoot(
            CustomPdfViewer(url: attachmentUrl, title: noticeTitle),
          );
        } else if (isImage) {
          _navigateToRoot(FullScreenImageViewer(imageUrls: [attachmentUrl]));
        }
      }
    } else if (type == 'new_event' || type == 'event_reminder') {
      final eventIdStr = data['eventId'];
      if (eventIdStr != null) {
        final id = int.tryParse(eventIdStr.toString());
        if (id != null) {
          _navigateToTab(
            6, // Events tab
            subPage: EventDetailsPage(event: ClubEvent.fromId(id)),
          );
        }
      } else {
        _navigateToTab(6); // Events tab
      }
    }
  }

  static void _navigateToTab(int index, {Widget? subPage}) {
    // Navigate using MainLayout's programmatic tab switching
    MainLayout.mainLayoutKey.currentState?.navigateToTab(
      index,
      subPage: subPage,
    );
  }

  static void _navigateToRoot(Widget page) {
    // Push onto root navigator to hide the top/bottom bars
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => page));
  }
}
