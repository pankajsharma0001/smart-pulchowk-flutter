import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/user.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:smart_pulchowk/core/models/classroom.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';
import 'package:smart_pulchowk/features/settings/settings_page.dart';
import 'package:smart_pulchowk/features/favorites/favorites_page.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'dart:ui' as ui;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  bool _isLoading = true;
  AppUser? _user;
  SellerReputation? _reputation;
  List<BookListing> _myListings = [];
  List<SavedBook> _savedBooks = [];
  List<BookPurchaseRequest> _sentRequests = [];
  List<BookPurchaseRequest> _incomingRequests = [];
  List<MarketplaceReport> _myReports = [];
  StudentProfile? _studentProfile;
  List<Subject> _classroomSubjects = [];
  bool _isStudent = false;

  static const _allTabs = [
    'My Listings',
    'Activity',
    'Saved',
    'Classroom',
    'Reviews',
  ];

  List<String> get _activeTabs =>
      _isStudent ? _allTabs : _allTabs.where((t) => t != 'Classroom').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _activeTabs.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = _user == null);

    try {
      final results = await Future.wait([
        _api.getCurrentUser(forceRefresh: forceRefresh),
        _api.getMyBookListings(forceRefresh: forceRefresh),
        _api.getSavedBooks(forceRefresh: forceRefresh),
        _api.getMyPurchaseRequests(forceRefresh: forceRefresh),
        _api.getIncomingPurchaseRequests(forceRefresh: forceRefresh),
        _api.getStudentProfile(),
      ]);

      // getMyMarketplaceReports returns non-nullable List — fetch separately
      final myReports = await _api.getMyMarketplaceReports();

      if (!mounted) return;

      final user = results[0] as AppUser?;
      final studentProfile = results[5] as StudentProfile?;
      final isStudent = studentProfile != null;

      // getMyClassroomSubjects returns Map<String,dynamic>, parse manually
      List<Subject> classroomSubjects = [];
      if (isStudent) {
        try {
          final subjectsMap = await _api.getMyClassroomSubjects(
            forceRefresh: forceRefresh,
          );
          if (subjectsMap['success'] == true && subjectsMap['data'] != null) {
            final data = subjectsMap['data'] as Map<String, dynamic>?;
            final subjectsList = data?['subjects'] as List? ?? [];
            classroomSubjects = subjectsList
                .map((e) => Subject.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          debugPrint('Error parsing classroom subjects: $e');
        }
      }

      if (!mounted) return;

      final oldTabCount = _tabController.length;
      final newTabCount = isStudent ? _allTabs.length : _allTabs.length - 1;

      setState(() {
        _user = user;
        _myListings = results[1] as List<BookListing>? ?? [];
        _savedBooks = results[2] as List<SavedBook>? ?? [];
        _sentRequests = results[3] as List<BookPurchaseRequest>? ?? [];
        _incomingRequests = results[4] as List<BookPurchaseRequest>? ?? [];
        _myReports = myReports;
        _studentProfile = studentProfile;
        _classroomSubjects = classroomSubjects;
        _isStudent = isStudent;
        _isLoading = false;

        if (oldTabCount != newTabCount) {
          _tabController.dispose();
          _tabController = TabController(length: newTabCount, vsync: this);
        }
      });

      if (user != null) {
        final rep = await _api.getSellerReputation(
          user.id,
          forceRefresh: forceRefresh,
        );
        if (mounted) setState(() => _reputation = rep);
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: _buildShimmerLoading(isDark),
      );
    }

    if (_user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text('Failed to load profile.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final tabs = _activeTabs;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    const double toolbarHeight = 60.0;
    const double bottomHeight = 48.0;
    const double expandedHeight = 320.0;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: expandedHeight,
              toolbarHeight: toolbarHeight,
              backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
              elevation: 0,
              leading: const SizedBox.shrink(),
              leadingWidth: 0,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final double progress =
                      ((expandedHeight +
                                  statusBarHeight -
                                  constraints.maxHeight) /
                              (expandedHeight - toolbarHeight - bottomHeight))
                          .clamp(0.0, 1.0);
                  return _buildFlexibleHeader(
                    isDark,
                    cs,
                    progress,
                    statusBarHeight,
                  );
                },
              ),
              bottom: _GlassTabBar(
                isDark: isDark,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: cs.primary,
                  indicatorWeight: 3,
                  labelColor: cs.primary,
                  unselectedLabelColor: isDark
                      ? Colors.white54
                      : Colors.black54,
                  labelStyle: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  isScrollable: _isStudent,
                  tabAlignment: _isStudent
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  tabs: tabs.map((t) => Tab(text: t)).toList(),
                  onTap: (index) => setState(() {}),
                ),
              ),
            ),

            // Reputation / stats card
            SliverToBoxAdapter(child: _buildStatsCard(isDark, cs)),

            // Tab content
            _buildTabContent(isDark, cs),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isDark, ColorScheme cs) {
    final idx = _tabController.index;
    final tab = _activeTabs[idx];

    switch (tab) {
      case 'My Listings':
        return _buildListingsGrid(isDark);
      case 'Activity':
        return _buildActivityTab(isDark, cs);
      case 'Saved':
        return _buildSavedBooksGrid(isDark);
      case 'Classroom':
        return _buildClassroomTab(isDark, cs);
      case 'Reviews':
        return _buildReviewsList(isDark, cs);
      default:
        return _buildListingsGrid(isDark);
    }
  }

  // ─────────────── Header ───────────────────────────────────────────────────

  Widget _buildFlexibleHeader(
    bool isDark,
    ColorScheme cs,
    double progress,
    double statusBarHeight,
  ) {
    final double avatarSize = 120 - (80 * progress);
    final double infoOpacity = (1 - (progress * 2.5)).clamp(0.0, 1.0);
    final double bgOpacity = (progress > 0.8)
        ? 1.0
        : (progress * 1.2).clamp(0.0, 1.0);
    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      color: (isDark ? AppColors.backgroundDark : Colors.white).withValues(
        alpha: bgOpacity,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: (1 - progress).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: isDark ? 0.4 : 0.15),
                    cs.primary.withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Avatar
          Positioned(
            left:
                (screenWidth / 2 - avatarSize / 2) * (1 - progress) +
                (20 * progress),
            top: statusBarHeight + (45 * (1 - progress)) + (10 * progress),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2 + (2 * (1 - progress)),
                ),
              ),
              child: SmartImage(
                imageUrl: _user!.image,
                width: avatarSize,
                height: avatarSize,
                shape: BoxShape.circle,
                errorWidget: Icon(
                  Icons.person,
                  size: avatarSize / 2,
                  color: cs.primary,
                ),
              ),
            ),
          ),

          // Expanded name + email
          if (infoOpacity > 0)
            Positioned(
              top: statusBarHeight + 120 + 55,
              left: 20,
              right: 20,
              child: Opacity(
                opacity: infoOpacity,
                child: Column(
                  children: [
                    Text(
                      _user!.name,
                      style: AppTextStyles.h4.copyWith(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      _user!.email,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _user!.role.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Compact collapsed title
          if (progress > 0.8)
            Positioned(
              left: 72,
              top: statusBarHeight + 10,
              child: Opacity(
                opacity: ((progress - 0.8) / 0.2).clamp(0.0, 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _user!.name,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _user!.role.toUpperCase(),
                      style: AppTextStyles.overline.copyWith(
                        color: cs.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Favorites button
          Positioned(
            top: statusBarHeight,
            right: 48,
            child: IconButton(
              icon: const Icon(Icons.favorite_border_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesPage()),
              ),
            ),
          ),

          // Settings button
          Positioned(
            top: statusBarHeight,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Stats Card ───────────────────────────────────────────────

  Widget _buildStatsCard(bool isDark, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.cardDark : Colors.white).withValues(
          alpha: 0.9,
        ),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 4-stat row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Rating',
                _reputation?.averageRating.toStringAsFixed(1) ?? '—',
                Icons.star_rounded,
                Colors.orange,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Sold',
                _reputation?.soldCount.toString() ?? '0',
                Icons.shopping_bag_rounded,
                cs.primary,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Listings',
                _myListings.length.toString(),
                Icons.library_books_rounded,
                Colors.teal,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Saved',
                _savedBooks.length.toString(),
                Icons.bookmark_rounded,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 12),

          // Member since + reports quick-access row
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                'Member since ${DateFormat('MMMM yyyy').format(_user!.createdAt)}',
                style: AppTextStyles.caption.copyWith(color: Colors.grey),
              ),
              const Spacer(),
              if (_myReports.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    haptics.selectionClick();
                    // Switch to the currently visible tab by index
                    // For now just show a snack
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_myReports.length} report${_myReports.length == 1 ? '' : 's'} filed',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 12,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_myReports.length} report${_myReports.length == 1 ? '' : 's'}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.overline.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(
    height: 30,
    width: 1,
    color: Colors.grey.withValues(alpha: 0.2),
  );

  // ─────────────── My Listings Tab ──────────────────────────────────────────

  Widget _buildListingsGrid(bool isDark) {
    if (_myListings.isEmpty) {
      return _buildEmptySliver(
        Icons.library_books_rounded,
        'No listings yet',
        'Sell your books to see them here.',
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HorizontalBookCard(
              book: _myListings[index],
              isDark: isDark,
            ),
          ),
          childCount: _myListings.length,
        ),
      ),
    );
  }

  // ─────────────── Activity Tab ─────────────────────────────────────────────

  Widget _buildActivityTab(bool isDark, ColorScheme cs) {
    final hasSent = _sentRequests.isNotEmpty;
    final hasIncoming = _incomingRequests.isNotEmpty;

    if (!hasSent && !hasIncoming) {
      return _buildEmptySliver(
        Icons.swap_horiz_rounded,
        'No activity yet',
        'Your purchase requests and incoming offers will appear here.',
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (hasSent) ...[
            _buildSubheader('Sent Requests', Icons.send_rounded, cs.primary),
            const SizedBox(height: 8),
            ..._sentRequests.map(
              (r) => _PurchaseRequestCard(
                request: r,
                isDark: isDark,
                showBuyer: false,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (hasIncoming) ...[
            _buildSubheader(
              'Incoming Offers',
              Icons.inbox_rounded,
              Colors.green,
            ),
            const SizedBox(height: 8),
            ..._incomingRequests.map(
              (r) => _PurchaseRequestCard(
                request: r,
                isDark: isDark,
                showBuyer: true,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ─────────────── Saved Books Tab ──────────────────────────────────────────

  Widget _buildSavedBooksGrid(bool isDark) {
    if (_savedBooks.isEmpty) {
      return _buildEmptySliver(
        Icons.bookmark_border_rounded,
        'No saved books',
        'Bookmark books you\'re interested in and they\'ll appear here.',
      );
    }
    final books = _savedBooks.where((s) => s.listing != null).toList();
    if (books.isEmpty) {
      return _buildEmptySliver(
        Icons.bookmark_border_rounded,
        'No saved books',
        'Bookmark books you\'re interested in and they\'ll appear here.',
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HorizontalBookCard(
              book: books[index].listing!,
              isDark: isDark,
            ),
          ),
          childCount: books.length,
        ),
      ),
    );
  }

  // ─────────────── Classroom Tab ────────────────────────────────────────────

  Widget _buildClassroomTab(bool isDark, ColorScheme cs) {
    if (_studentProfile == null) {
      return _buildEmptySliver(
        Icons.school_rounded,
        'No classroom profile',
        'Set up your student profile in the Classroom section.',
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Student profile info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: cs.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _studentProfile!.faculty?.name ?? 'Unknown Faculty',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Semester ${_studentProfile!.currentSemester}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Sem ${_studentProfile!.currentSemester}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_studentProfile!.semesterEndDate != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Semester ends ${DateFormat('MMMM d, yyyy').format(_studentProfile!.semesterEndDate!)}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Subjects
          if (_classroomSubjects.isNotEmpty) ...[
            _buildSubheader('Current Subjects', Icons.book_rounded, cs.primary),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classroomSubjects.map((subject) {
                final hasAssignments =
                    (subject.assignments?.isNotEmpty ?? false);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasAssignments
                          ? cs.primary.withValues(alpha: 0.4)
                          : (isDark
                                ? Colors.white12
                                : Colors.black.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (subject.code != null) ...[
                        Text(
                          subject.code!,
                          style: AppTextStyles.caption.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 1,
                          height: 12,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        subject.title,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subject.isElective) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Elective',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.orange,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else
            _buildInlineEmpty('No subjects found for this semester.'),
        ]),
      ),
    );
  }

  // ─────────────── Reviews Tab ──────────────────────────────────────────────

  Widget _buildReviewsList(bool isDark, ColorScheme cs) {
    final reviews = _reputation?.recentRatings ?? [];
    if (reviews.isEmpty) {
      return _buildEmptySliver(
        Icons.reviews_rounded,
        'No reviews yet',
        'Sell books and earn reviews from buyers.',
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _ReviewItem(rating: reviews[index], isDark: isDark),
          childCount: reviews.length,
        ),
      ),
    );
  }

  // ─────────────── Helpers ──────────────────────────────────────────────────

  Widget _buildSubheader(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildInlineEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptySliver(IconData icon, String title, String subtitle) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return ShimmerWrapper(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 250,
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Skeleton(height: 88, width: 88, borderRadius: 44),
                  SizedBox(height: 16),
                  Skeleton(height: 24, width: 150),
                  SizedBox(height: 8),
                  Skeleton(height: 14, width: 200),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: AppRadius.lgAll,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                  (index) => const Skeleton(height: 50, width: 55),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Skeleton(height: 30, width: 100, borderRadius: 15),
                  const SizedBox(width: 8),
                  Skeleton(height: 30, width: 80, borderRadius: 15),
                  const SizedBox(width: 8),
                  Skeleton(height: 30, width: 60, borderRadius: 15),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const Skeleton(borderRadius: 12),
                childCount: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widget: Purchase Request Card
// ═══════════════════════════════════════════════════════════════════════════

class _PurchaseRequestCard extends StatelessWidget {
  final BookPurchaseRequest request;
  final bool isDark;
  final bool showBuyer;

  const _PurchaseRequestCard({
    required this.request,
    required this.isDark,
    required this.showBuyer,
  });

  Color _statusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.accepted:
        return Colors.green;
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        return Colors.red;
      case RequestStatus.pending:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final listing = request.listing;
    final statusColor = _statusColor(request.status);

    return GestureDetector(
      onTap: listing != null
          ? () {
              haptics.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookDetailsPage(listing: listing),
                ),
              );
            }
          : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            // Book thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 68,
                child: listing?.primaryImageUrl != null
                    ? SmartImage(
                        imageUrl: listing!.primaryImageUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: cs.primary.withValues(alpha: 0.08),
                        child: Icon(
                          Icons.book_rounded,
                          color: cs.primary.withValues(alpha: 0.3),
                          size: 28,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing?.title ?? 'Unknown Book',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showBuyer && request.buyer != null)
                    Text(
                      'From: ${request.buyer!.name}',
                      style: AppTextStyles.caption.copyWith(color: Colors.grey),
                    )
                  else if (!showBuyer && listing?.seller != null)
                    Text(
                      'Seller: ${listing!.seller!.name}',
                      style: AppTextStyles.caption.copyWith(color: Colors.grey),
                    ),
                  if (request.message != null &&
                      request.message!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '"${request.message}"',
                      style: AppTextStyles.caption.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    request.status.label,
                    style: AppTextStyles.caption.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d').format(request.createdAt),
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widget: Review Item (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

class _ReviewItem extends StatelessWidget {
  final SellerRating rating;
  final bool isDark;

  const _ReviewItem({required this.rating, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SmartImage(
                imageUrl: rating.rater?.image,
                width: 24,
                height: 24,
                shape: BoxShape.circle,
                errorWidget: Icon(Icons.person, size: 12, color: cs.primary),
              ),
              const SizedBox(width: 8),
              ...List.generate(
                5,
                (i) => Icon(
                  i < rating.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 14,
                  color: Colors.orange,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM d, yyyy').format(rating.createdAt),
                style: AppTextStyles.overline.copyWith(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (rating.review != null && rating.review!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(rating.review!, style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'by ${rating.rater?.name ?? 'Verified Buyer'}',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              if (rating.listing != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '• ${rating.listing!.title}',
                    style: AppTextStyles.overline.copyWith(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widget: Glass Tab Bar
// ═══════════════════════════════════════════════════════════════════════════

class _GlassTabBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;
  final bool isDark;

  const _GlassTabBar({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
              .withValues(alpha: 0.7),
          child: child,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widget: Book Card
// ═══════════════════════════════════════════════════════════════════════════
// Private widget: Horizontal Book Card for Profile Page
// ═══════════════════════════════════════════════════════════════════════════

class _HorizontalBookCard extends StatelessWidget {
  final BookListing book;
  final bool isDark;

  const _HorizontalBookCard({required this.book, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailsPage(listing: book)),
      ),
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: isDark ? null : AppShadows.xs,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Image
            SizedBox(
              width: 90,
              height: double.infinity,
              child: book.primaryImageUrl != null
                  ? SmartImage(
                      imageUrl: book.primaryImageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: cs.primary.withValues(alpha: 0.05),
                      child: Icon(
                        Icons.library_books_rounded,
                        color: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rs. ${book.price}',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _infoBadge(
                          book.condition.displayName,
                          Colors.purple,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        if (book.status == BookStatus.sold)
                          _infoBadge('Sold', Colors.red, isDark)
                        else
                          _infoBadge('Active', Colors.green, isDark),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
