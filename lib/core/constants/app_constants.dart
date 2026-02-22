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

  // ── Lost & Found Endpoints ────────────────────────────────────────────────
  static const String lostFound = '/lost-found';
  static const String myLostFoundItems = '/lost-found/my/items';
  static const String myLostFoundClaims = '/lost-found/my/claims';

  // ── Notice Endpoints ───────────────────────────────────────────────────────
  static const String notices = '/notices';
  static const String noticeStats = '/notices/stats';

  // ── Event Endpoints ────────────────────────────────────────────────────────
  static const String eventsAll = '/events/all-events';
  static const String eventsUpcoming = '/events/get-upcoming-events';
  static const String eventsRegister = '/events/register-event';
  static const String eventsCancelRegistration = '/events/cancel-registration';
  static const String eventsEnrollment = '/events/enrollment';
  static const String clubs = '/events/clubs';
  static const String createNewClub = '/events/create-club';
  static const String createEvent = '/events/create-event';
  static const String clubProfile = '/clubs/club-profile';
  static const String eventDetails = '/clubs/event-details';
  static const String clubEvents = '/events/events';

  // ── Admin Endpoints ────────────────────────────────────────────────────────
  static const String adminOverview = '/admin/overview';
  static const String adminUsers = '/admin/users';
  static const String adminReports = '/admin/reports';
  static const String adminRatings = '/admin/ratings';
  static const String adminBlocks = '/admin/blocks';
  static const String adminAnnouncements = '/admin/announcements';
  static const String chatbotChat = '/chatbot/chat';

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const String dbUserIdKey = 'db_user_id';
  static const String userRoleKey = 'user_role';
  static const String fcmTokenKey = 'fcm_token';
  static const String themeKey = 'theme_mode';
  static const String hapticsKey = 'haptics_enabled';
  static const String recentSearchKey = 'recent_searches_history';

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
  static const String cacheClubsList = 'clubs_list';
  static const String cacheClubProfile = 'clubs_profile_';
  static const String cacheClubEvents = 'clubs_events_';
  // ── Lost & Found Cache Keys ───────────────────────────────────────────────
  static const String cacheLostFoundList = 'lost_found_list';
  static const String cacheMyLostFoundItems = 'lost_found_my_items';
  static const String cacheMyLostFoundClaims = 'lost_found_my_claims';
  static const String cacheLostFoundDetail = 'lost_found_detail_';

  // ── Admin Cache Keys ───────────────────────────────────────────────────
  static const String cacheAdminOverview = 'admin_overview';
  static const String cacheAdminUsers = 'admin_users';
  static const String cacheAdminReports = 'admin_reports';
  static const String cacheAdminBlocks = 'admin_blocks';

  // ── User Cache Keys ────────────────────────────────────────────────────
  static const String cacheUserProfile = 'user_profile';

  // ── Map Cache Keys ───────────────────────────────────────────────────
  static const String cacheMapLocations = 'map_locations';
  static const String cacheMapIconPrefix = 'map_icon_';

  // ── Favorites Cache Keys ───────────────────────────────────────────────
  static const String cacheFavoriteClubs = 'fav_clubs';
  static const String cacheFavoriteEvents = 'fav_events';

  // ── Image Headers ────────────────────────────────────────────────────────
  static const Map<String, String> imageHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  };
}
