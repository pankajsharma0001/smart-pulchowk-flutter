import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
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

  /// Handle navigation based on notification data payload.
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
    } else if (type == 'lost_found_claim_received') {
      _navigateToTab(9); // Lost & Found tab
    } else if (type == 'notice_created' || type == 'notice_updated') {
      final attachmentUrl = data['attachmentUrl']?.toString();
      final noticeTitle = data['noticeTitle']?.toString() ?? 'Notice';

      if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
        final urlLower = attachmentUrl.toLowerCase();
        final isPdf = urlLower.endsWith('.pdf');
        final isImage =
            urlLower.endsWith('.jpg') ||
            urlLower.endsWith('.jpeg') ||
            urlLower.endsWith('.png') ||
            urlLower.endsWith('.webp');

        if (isPdf) {
          _navigateToTab(
            8, // Notices tab
            subPage: CustomPdfViewer(url: attachmentUrl, title: noticeTitle),
          );
        } else if (isImage) {
          _navigateToTab(
            8, // Notices tab
            subPage: FullScreenImageViewer(imageUrls: [attachmentUrl]),
          );
        } else {
          _navigateToTab(8); // Notices tab fallback
        }
      } else {
        _navigateToTab(8); // Notices tab
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
}
