import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';
import 'package:smart_pulchowk/features/marketplace/chat_room_page.dart';
import 'package:smart_pulchowk/features/marketplace/marketplace_activity_page.dart';

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
          _navigateToPage(BookDetailsPage(listing: BookListing.fromId(id)));
        }
      }
    } else if (type == 'new_purchase_request' ||
        type == 'purchase_request_cancelled') {
      // 0: Selling, 1: Inquiries, 2: Requests, 3: Saved
      _navigateToPage(const MarketplaceActivityPage(initialTabIndex: 1));
    } else if (type == 'chat' || type == 'message') {
      final conversationId = int.tryParse(
        data['conversationId']?.toString() ?? '',
      );
      final senderId = data['senderId']?.toString();
      final senderName = data['senderName']?.toString() ?? 'Chat';

      if (conversationId != null) {
        _navigateToPage(
          ChatRoomPage(
            conversationId: conversationId,
            recipientId: senderId ?? '',
            recipientName: senderName,
          ),
        );
      }
    } else if (type == 'lost_found_claim_received') {
      // Future: Navigate to lost found details or activity
    }
  }

  static void _navigateToPage(Widget page) {
    // Basic navigation - push the new page onto the stack.
    // In a more complex app, you might want to switch tabs in the root layout first.
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => page));
  }
}
