class AppConstants {
  AppConstants._();

  // ── API Configuration ─────────────────────────────────────────────────────
  static const String baseUrl =
      'https://smart-pulchowk.vercel.app'; // Production URL
  // static const String baseUrl = 'http://10.0.2.2:3000'; // Local Emulator URL

  static const String apiPrefix = '/api';
  static const String fullApiUrl = '$baseUrl$apiPrefix';

  // ── Auth & User Endpoints ──────────────────────────────────────────────────
  static const String syncUser = '/users/sync-user';
  static const String userProfile = '/users/me';
  static const String clearFcmToken = '/users/clear-fcm-token';
  static const String updateFcmToken = '/users/update-fcm-token';
  static const String studentProfile = '/classroom/me';

  // ── Book Marketplace Endpoints ────────────────────────────────────────────
  static const String books = '/books';
  static const String bookCategories = '/books/categories';
  static const String savedBooks = '/books/saved';
  static const String myPurchaseRequests = '/books/my-requests';
  static const String trustBlockedUsers = '/books/trust/blocked-users';
  static const String trustReports = '/books/trust/reports';
  static const String trustMyReports = '/books/trust/reports/my';

  // ── Classroom Endpoints ────────────────────────────────────────────────────
  static const String classroomFaculties = '/classroom/faculties';
  static const String classroomSubjects = '/classroom/subjects';
  static const String classroomMySubjects = '/classroom/me/subjects';
  static const String classroomAssignments = '/classroom/assignments';

  // ── Notice Endpoints ───────────────────────────────────────────────────────
  static const String notices = '/notices';
  static const String noticeStats = '/notices/stats';

  // ── Event Endpoints ────────────────────────────────────────────────────────
  static const String eventsAll = '/events/all-events';
  static const String eventsUpcoming = '/events/get-upcoming-events';
  static const String eventsRegister = '/events/register-event';
  static const String eventsCancelRegistration = '/events/cancel-registration';
  static const String eventsEnrollment = '/events/enrollment';

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const String dbUserIdKey = 'db_user_id';
  static const String userRoleKey = 'user_role';
  static const String fcmTokenKey = 'fcm_token';
  static const String themeKey = 'theme_mode';
  static const String hapticsKey = 'haptics_enabled';

  // ── Hive Boxes ────────────────────────────────────────────────────────────
  static const String apiCacheBox = 'api_cache';

  // ── Network Timeout ───────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // ── Assets ────────────────────────────────────────────────────────────────
  static const String logoPath = 'assets/icons/logo.png';

  // ── Cache Durations ───────────────────────────────────────────────────────
  static const Duration cacheExpiry = Duration(minutes: 5);
  static const Duration longCacheExpiry = Duration(hours: 1);
  static const Duration shortCacheExpiry = Duration(minutes: 2);

  // ── Marketplace Cache Keys ─────────────────────────────────────────────
  static const String cacheBookCategories = 'mkt_book_categories';
  static const String cacheBookListings = 'mkt_book_listings';
  static const String cacheMyListings = 'mkt_my_listings';
  static const String cacheSavedBooks = 'mkt_saved_books';
  static const String cacheMyRequests = 'mkt_my_requests';
  static const String cacheIncomingRequests = 'mkt_incoming_requests';
  static const String cacheConversations = 'mkt_conversations';
  static const String cacheSellerReputation = 'mkt_seller_rep_';
  static const String cacheBookDetail = 'mkt_book_detail_';
  static const String cacheRequestStatus = 'mkt_request_status_';
  static const String cacheMessages = 'mkt_messages_';

  // ── Classroom Cache Keys ───────────────────────────────────────────────
  static const String cacheClassroomFaculties = 'cls_faculties';
  static const String cacheClassroomMySubjects = 'cls_my_subjects';
  static const String cacheClassroomSubjectDetails = 'cls_subject_';
  static const String cacheClassroomAssignments = 'cls_assignments_';

  // ── Notices Cache Keys ─────────────────────────────────────────────────
  static const String cacheNoticesList = 'notices_list';
  static const String cacheNoticeStats = 'notices_stats';

  // ── Events Cache Keys ──────────────────────────────────────────────────
  static const String cacheEventsList = 'events_list';
  static const String cacheEventsUpcoming = 'events_upcoming';
  static const String cacheEventsEnrollment = 'events_enrollment';
}
