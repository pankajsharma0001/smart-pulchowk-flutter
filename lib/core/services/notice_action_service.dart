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

  /// Emits a new notice action.
  void triggerAction({int? noticeId, String? category}) {
    _actionController.add(NoticeAction(noticeId: noticeId, category: category));
  }

  void dispose() {
    _actionController.close();
  }
}
