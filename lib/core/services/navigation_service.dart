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
import 'package:smart_pulchowk/features/notices/notices_page.dart';
import 'package:smart_pulchowk/features/lost_found/lost_found_details_page.dart';
import 'package:smart_pulchowk/features/classroom/classroom_page.dart';

class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
    if (t.contains('book') || t.contains('request_response')) {
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
    if (t == 'chat' || t == 'message' || t.contains('chat_message')) {
      final convId = int.tryParse(data['conversationId']?.toString() ?? '');
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

      // Navigate to the Notices tab, pre-filtered to the right category
      // and scrolled to the specific notice
      _navigateToTab(
        8,
        subPage: NoticesPage(
          initialCategory: category,
          initialNoticeId: noticeId,
        ),
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
              urlLower.contains('.webp');
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
    if (t.contains('lost_found') || t.contains('lostfound')) {
      final itemIdStr = data['itemId']?.toString();
      final itemId = int.tryParse(itemIdStr ?? '');
      if (itemId != null) {
        _navigateToTab(
          9, // Lost & Found
          subPage: LostFoundDetailsPage(itemId: itemId),
        );
      } else {
        _navigateToTab(9);
      }
      return;
    }

    // 6. Classroom
    if (t.contains('assignment') || t.contains('grading')) {
      final assignmentId = data['assignmentId']?.toString();
      if (assignmentId != null) {
        _navigateToTab(
          2, // Classroom
          subPage: ClassroomPage(initialAssignmentId: assignmentId),
        );
      } else {
        _navigateToTab(2);
      }
      return;
    }

    // 7. Security & Role Updates
    if (t.contains('security') ||
        t.contains('role') ||
        t == 'system' ||
        t.contains('seller')) {
      _navigateToTab(10); // Settings
      return;
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
