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
import 'package:smart_pulchowk/features/lost_found/lost_found_details_page.dart';
import 'package:smart_pulchowk/core/services/notice_action_service.dart';

class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Whether MainLayout is mounted and can accept tab-navigation commands.
  static bool get isMainLayoutReady =>
      MainLayout.mainLayoutKey.currentState != null;

  /// Handle navigation from an in-app notification tap.
  static void handleInAppNotification(InAppNotification notification) {
    _processAction(
      type: notification.type.name,
      data: notification.data ?? {},
      isPdf: notification.isPdf,
    );
  }

  /// Handle navigation based on push notification data payload.
  static void handleNotificationPayload(Map<String, dynamic> data) {
    debugPrint('Handling notification payload: ${data['type']}');
    _processAction(type: data['type']?.toString() ?? '', data: data);
  }

  /// Unified internal processor for all notification types.
  static void _processAction({
    required String type,
    required Map<String, dynamic> data,
    bool? isPdf,
  }) {
    final t = type.toLowerCase();

    // 1. Marketplace & Books
    if (t.contains('book')) {
      final idStr = data['listingId'] ?? data['bookId'];
      final id = int.tryParse(idStr?.toString() ?? '');
      if (id != null) {
        _navigateToTab(
          3, // Marketplace
          subPage: BookDetailsPage(listing: BookListing.fromId(id)),
        );
      } else {
        _navigateToTab(3);
      }
      return;
    }

    if (t.contains('purchase_request') || t.contains('request_response')) {
      final requestIdStr = data['requestId']?.toString();
      final requestId = int.tryParse(requestIdStr ?? '');
      final isRequestResponse = t.contains('request_response');

      // If it's a response to a request I made, I should look at "Requests" tab (index 2)
      // If it's a new inquiry for my book, I should look at "Inquiries" tab (index 1)
      final tabIndex = isRequestResponse ? 2 : 1;

      _navigateToTab(
        3, // Marketplace
        subPage: MarketplaceActivityPage(
          initialTabIndex: tabIndex,
          initialRequestId: requestId,
        ),
      );
      return;
    }

    // 2. Chat
    if (t == 'chat' ||
        t == 'message' ||
        t.contains('chat_message') ||
        t.contains('chat_mention')) {
      final convId = int.tryParse(
        (data['conversationId'] ?? data['conversation_id'])?.toString() ?? '',
      );
      final senderId = data['senderId']?.toString();
      final senderName = data['senderName']?.toString() ?? 'Chat';
      if (convId != null) {
        _navigateToTab(
          3,
          subPage: ChatRoomPage(
            conversationId: convId,
            recipientId: senderId ?? '',
            recipientName: senderName,
          ),
        );
      }
      return;
    }

    // 3. Events
    if (t.contains('event')) {
      final idStr = data['eventId'];
      final id = int.tryParse(idStr?.toString() ?? '');
      if (id != null) {
        _navigateToTab(
          6, // Events
          subPage: EventDetailsPage(event: ClubEvent.fromId(id)),
        );
      } else {
        _navigateToTab(6);
      }
      return;
    }

    // 4. Notices
    if (t.contains('notice')) {
      final noticeIdStr = data['noticeId']?.toString();
      final noticeId = int.tryParse(noticeIdStr ?? '');
      final category = data['category']?.toString();
      final attachmentUrl = data['attachmentUrl']?.toString();
      final noticeTitle = data['noticeTitle']?.toString() ?? 'Notice';

      // Navigate to the Notices tab via tab switching (index 8)
      _navigateToTab(8);

      // Send the action to the listener in NoticesPage (root of tab 8)
      NoticeActionService.instance.triggerAction(
        noticeId: noticeId,
        category: category,
      );

      // If the notice has an attachment, open it on top
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
        final urlLower = attachmentUrl.toLowerCase();
        final body = data['body']?.toString().toLowerCase() ?? '';
        final title = data['title']?.toString().toLowerCase() ?? '';

        final bool pdf =
            isPdf ??
            (urlLower.endsWith('.pdf') ||
                urlLower.contains('.pdf?') ||
                title.contains('pdf') ||
                body.contains('pdf'));

        if (pdf) {
          Future.delayed(const Duration(milliseconds: 400), () {
            _navigateToRoot(
              CustomPdfViewer(url: attachmentUrl, title: noticeTitle),
            );
          });
        } else {
          final isImg =
              urlLower.contains('.jpg') ||
              urlLower.contains('.jpeg') ||
              urlLower.contains('.png') ||
              urlLower.contains('.webp') ||
              title.contains('image') ||
              body.contains('image');

          if (isImg) {
            Future.delayed(const Duration(milliseconds: 400), () {
              _navigateToRoot(
                FullScreenImageViewer(imageUrls: [attachmentUrl]),
              );
            });
          }
        }
      }
      return;
    }

    // 5. Lost & Found
    if (t.contains('lost') || t.contains('found')) {
      final idStr = data['itemId'];
      final id = int.tryParse(idStr?.toString() ?? '');
      if (id != null) {
        _navigateToTab(
          0, // Home
          subPage: LostFoundDetailsPage(itemId: id),
        );
      }
      return;
    }

    // 6. Classroom
    if (t.contains('class') || t == 'assignment' || t == 'material') {
      _navigateToTab(7); // Classroom index
      return;
    }

    // 7. System / Other
    if (t == 'system' || t == 'broadcast') {
      _navigateToTab(0);
      return;
    }

    debugPrint('Unknown notification type: $type');
  }

  /// Switches the main layout to a specific tab and optionally pushes a sub-page.
  static void _navigateToTab(int index, {Widget? subPage}) {
    final state = MainLayout.mainLayoutKey.currentState;
    if (state != null) {
      state.navigateToTab(index, subPage: subPage);
    }
  }

  /// Pushes a page onto the root navigator (on top of everything).
  static void _navigateToRoot(Widget page) {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => page));
  }
}
