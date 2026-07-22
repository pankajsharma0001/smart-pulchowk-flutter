import 'dart:async';

/// Data structure for notice navigation actions.
class NoticeAction {
  final int? noticeId;
  final String? category;

  NoticeAction({this.noticeId, this.category});
}

/// A singleton service that allows other parts of the app to trigger actions
/// on the Notices tab without pushing duplicate pages onto the navigator stack.
class NoticeActionService {
  NoticeActionService._();
  static final NoticeActionService instance = NoticeActionService._();

  final _actionController = StreamController<NoticeAction>.broadcast();

  /// Stream of notice actions to be handled by the NoticesPage.
  Stream<NoticeAction> get actionStream => _actionController.stream;

  String? pendingCategory;
  int? pendingNoticeId;

  /// Emits a new notice action.
  void triggerAction({int? noticeId, String? category}) {
    pendingCategory = category;
    pendingNoticeId = noticeId;
    _actionController.add(NoticeAction(noticeId: noticeId, category: category));
  }

  /// Consumes the pending action if available.
  void consumePendingAction(Function(String? category, int? noticeId) callback) {
    if (pendingCategory != null || pendingNoticeId != null) {
      callback(pendingCategory, pendingNoticeId);
      pendingCategory = null;
      pendingNoticeId = null;
    }
  }

  void dispose() {
    _actionController.close();
  }
}
