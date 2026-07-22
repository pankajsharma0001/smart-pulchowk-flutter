import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:smart_pulchowk/features/search/search.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/models/club.dart';
import 'package:smart_pulchowk/core/models/notice.dart';
import 'package:smart_pulchowk/core/models/user.dart';
import 'package:smart_pulchowk/core/models/classroom.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/events/event_details_page.dart';

import 'package:smart_pulchowk/core/widgets/pdf_viewer.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:smart_pulchowk/core/services/notice_action_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_pulchowk/features/calendar/calendar.dart';
import 'package:smart_pulchowk/features/settings/help_center_page.dart';
import 'package:smart_pulchowk/features/notices/notice_editor.dart';
import 'package:smart_pulchowk/features/events/widgets/event_editor.dart';
import 'package:smart_pulchowk/features/marketplace/marketplace_activity_page.dart';
import 'package:smart_pulchowk/features/admin/admin_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: _HomeContent(),
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  late Future<List<EventRegistration>> _enrollmentFuture;
  late Future<List<ClubEvent>> _eventsFuture;
  late Future<int> _userCountFuture;
  late Future<List<Club>> _clubsFuture;
  late Future<NoticeStats?> _noticeStatsFuture;
  late Future<List<LostFoundItem>> _lostFoundFuture;
  late Future<AppUser?> _userFuture;
  late Future<StudentProfile?> _studentProfileFuture;
  late Future<List<Notice>> _noticesFuture;

  @override
  void initState() {
    super.initState();
    _loadData(forceRefresh: false);
  }

  void _loadData({required bool forceRefresh}) {
    final api = ApiService();
    // Use cached fetch with optional force refresh
    _enrollmentFuture = api.getStudentEnrollment(forceRefresh: forceRefresh);
    _eventsFuture = api.getAllEvents(forceRefresh: forceRefresh);
    _clubsFuture = api.getClubs(forceRefresh: forceRefresh);
    _noticeStatsFuture = api.getNoticeStats(forceRefresh: forceRefresh);
    _lostFoundFuture = api.getLostFoundItems(forceRefresh: forceRefresh);

    // User count is never cached per user request
    _userCountFuture = api.getActiveUserCount(forceRefresh: true);
    _userFuture = api.getCurrentUser(forceRefresh: forceRefresh);
    _studentProfileFuture = api.getStudentProfile();
    _noticesFuture = api.getNotices(limit: 50, forceRefresh: forceRefresh);
  }

  Future<void> _handleRefresh() async {
    // Sync user role from backend on pull-to-refresh
    MainLayout.of(context)?.refreshUserRole();

    if (mounted) {
      setState(() {
        _loadData(forceRefresh: true);
      });
    }
    // Wait for all data to finish loading before hiding the indicator
    await Future.wait([
      _enrollmentFuture.catchError((_) => <EventRegistration>[]),
      _eventsFuture.catchError((_) => <ClubEvent>[]),
      _clubsFuture.catchError((_) => <Club>[]),
      _noticeStatsFuture.catchError((_) => null),
      _lostFoundFuture.catchError((_) => <LostFoundItem>[]),
      _userCountFuture.catchError((_) => 0),
      _userFuture.catchError((_) => null),
      _studentProfileFuture.catchError((_) => null),
      _noticesFuture.catchError((_) => <Notice>[]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final userRole = MainLayout.of(context)?.userRole ?? 'student';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(
            bottom: 120, // Space for bottom nav and floating button
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _HomeSearchBar(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _WelcomeBanner(
                  userCountFuture: _userCountFuture,
                  userFuture: _userFuture,
                  noticesFuture: _noticesFuture,
                  eventsFuture: _eventsFuture,
                  userRole: userRole,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _QuickAccessGrid(userRole: userRole),
              const SizedBox(height: AppSpacing.xl),
              _RecentNoticesSection(
                noticesFuture: _noticesFuture,
                studentProfileFuture: _studentProfileFuture,
              ),
              const SizedBox(height: AppSpacing.xl),
              _RegisteredEventsSection(enrollmentFuture: _enrollmentFuture),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sections ─────────────────────────────────────────────────────────────────

class _RegisteredEventsSection extends StatelessWidget {
  final Future<List<EventRegistration>> enrollmentFuture;
  const _RegisteredEventsSection({required this.enrollmentFuture});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (!authSnapshot.hasData) return const SizedBox.shrink();

        return FutureBuilder<List<EventRegistration>>(
          initialData: apiService.getCachedEnrollment(),
          future: enrollmentFuture,
          builder: (context, snapshot) {
            // Show loader only if we have NO data at all (neither cached nor fresh)
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _RegisteredEventsLoader();
            }

            final registrations = snapshot.data ?? [];
            if (registrations.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: _SectionLabel(label: 'Your Registrations'),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: registrations.length,
                    itemBuilder: (context, index) {
                      final event = registrations[index].event;
                      if (event == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _RegisteredEventMiniCard(event: event),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Components ───────────────────────────────────────────────────────────────

class _RegisteredEventMiniCard extends StatelessWidget {
  final ClubEvent event;
  const _RegisteredEventMiniCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        haptics.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailsPage(event: event),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width:
            MediaQuery.of(context).size.width *
            0.8, // Take up most of the screen width
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                .withValues(alpha: 0.5),
          ),
          boxShadow: AppShadows.xs,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('d').format(event.eventStartTime),
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.primary,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'MMM',
                    ).format(event.eventStartTime).toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.venue ?? "TBA"} · ${DateFormat('h:mm a').format(event.eventStartTime)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisteredEventsLoader extends StatelessWidget {
  const _RegisteredEventsLoader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _SectionLabel(label: 'Your Registrations'),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: 2,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        (isDark ? AppColors.borderDark : AppColors.borderLight)
                            .withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: const ShimmerWrapper(
                  child: Row(
                    children: [
                      Skeleton(width: 48, height: 48, borderRadius: 14),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Skeleton(height: 14, width: 140, borderRadius: 6),
                            SizedBox(height: 8),
                            Skeleton(height: 10, width: 100, borderRadius: 5),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.overline.copyWith(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.textMutedDark
            : AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        haptics.selectionClick();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, _) => const SearchPage(),
            transitionsBuilder: (_, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
                child: SlideTransition(
                  position: animation.drive(
                    Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic)),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 200),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search campus, events, clubs, books...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatefulWidget {
  final Future<int> userCountFuture;
  final Future<AppUser?> userFuture;
  final Future<List<Notice>> noticesFuture;
  final Future<List<ClubEvent>> eventsFuture;
  final String userRole;

  const _WelcomeBanner({
    required this.userCountFuture,
    required this.userFuture,
    required this.noticesFuture,
    required this.eventsFuture,
    required this.userRole,
  });

  @override
  State<_WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<_WelcomeBanner> {
  static const int _slideCount = 3;
  // Large virtual count centred at midpoint → seamless circular loop
  static const int _kVirtualCount = 30000;
  static const int _kInitialPage = _kVirtualCount ~/ 2;

  late final PageController _pageController = PageController(
    initialPage: _kInitialPage,
  );
  int _currentPageIndex = 0;



  void _onHorizontalDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (velocity < -300) {
      _pageController.nextPage(
        duration: AppAnimations.normal,
        curve: AppAnimations.defaultCurve,
      );
    } else if (velocity > 300) {
      _pageController.previousPage(
        duration: AppAnimations.normal,
        curve: AppAnimations.defaultCurve,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fixed height card: image is static on the left, PageView slides on the right.
    // The right column uses the full available height so Expanded(PageView) works.
    const double cardHeight = 160;
    const double imgSize =
        cardHeight - 32; // card height minus top+bottom padding

    return Container(
      width: double.infinity,
      height: cardHeight,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.borderDark : AppColors.borderLight)
              .withValues(alpha: 0.5),
        ),
        boxShadow: isDark ? [] : AppShadows.xs,
      ),
      padding: const EdgeInsets.all(16),
      // GestureDetector covers the entire card (including image) for swipe detection
      child: GestureDetector(
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Campus Image — always static, centred vertically
            Align(
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/pulchowk_campus.png',
                  width: imgSize,
                  height: imgSize,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: imgSize,
                      height: imgSize,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.school_rounded,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right: circular PageView slides + indicator row at bottom
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _kVirtualCount, // effectively infinite
                      onPageChanged: (virtualIndex) {
                        setState(
                          () => _currentPageIndex = virtualIndex % _slideCount,
                        );
                      },
                      itemBuilder: (context, virtualIndex) {
                        switch (virtualIndex % _slideCount) {
                          case 0:
                            return _buildWelcomeSlide(isDark);
                          case 1:
                            return _buildNoticeSlide(isDark);
                          case 2:
                            return _buildEventSlide(isDark);
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Bottom row: dot indicators + active user count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dot indicators — tap to jump to that logical slide
                      Row(
                        children: List.generate(_slideCount, (index) {
                          final isActive = index == _currentPageIndex;
                          return GestureDetector(
                            onTap: () {
                              // Jump to nearest virtual page for this logical index
                              final currentVirtual =
                                  _pageController.page?.round() ??
                                  _kInitialPage;
                              final currentLogical =
                                  currentVirtual % _slideCount;
                              final delta = index - currentLogical;
                              _pageController.animateToPage(
                                currentVirtual + delta,
                                duration: AppAnimations.normal,
                                curve: AppAnimations.defaultCurve,
                              );
                            },
                            child: AnimatedContainer(
                              duration: AppAnimations.fast,
                              width: isActive ? 14 : 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary
                                    : (isDark
                                          ? Colors.white30
                                          : Colors.black12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),
                      FutureBuilder<int>(
                        future: widget.userCountFuture,
                        builder: (context, snapshot) {
                          final countText =
                              snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData
                              ? '...'
                              : '${snapshot.data ?? 0}';
                          final isAdmin = widget.userRole == 'admin';
                          final badge = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$countText active',
                                style: AppTextStyles.overline.copyWith(
                                  color: isAdmin
                                      ? AppColors.primary
                                      : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondary),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                  decoration: isAdmin
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                ),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 10,
                                  color: AppColors.primary,
                                ),
                              ],
                            ],
                          );
                          if (!isAdmin) return badge;
                          return GestureDetector(
                            onTap: () {
                              haptics.lightImpact();
                              _showActiveUsersSheet(context, countText, isDark);
                            },
                            child: badge,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActiveUsersSheet(BuildContext ctx, String countText, bool isDark) {
    showModalBottomSheet(
      context: ctx,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? AppColors.surfaceContainerDark : Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Green pulsing dot + count
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$countText Users Active Now',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Users who have been active on the platform recently.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // View all users button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => const AdminPage(initialTabIndex: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  label: const Text('View All Users'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSlide(bool isDark) {
    return FutureBuilder<AppUser?>(
      future: widget.userFuture,
      builder: (context, snapshot) {
        final userName = snapshot.data?.name.split(' ').first ?? 'Student';
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Welcome '),
                      TextSpan(
                        text: userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.primaryLight
                              : AppColors.primary,
                        ),
                      ),
                      const TextSpan(text: ' to'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Smart Pulchowk',
                  style: AppTextStyles.h4.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All the campus information you need, in one place.',
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoticeSlide(bool isDark) {
    return FutureBuilder<List<Notice>>(
      future: widget.noticesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final notices = snapshot.data ?? [];
        if (notices.isEmpty) {
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'LATEST UPDATE',
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.primary,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No new announcements today.',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        final latestNotice = notices.first;
        final date = DateFormat('MMM d').format(latestNotice.displayDate);

        return InkWell(
          onTap: () {
            haptics.lightImpact();
            if (latestNotice.attachmentUrl != null &&
                latestNotice.attachmentUrl!.isNotEmpty) {
              if (latestNotice.isPdf) {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => CustomPdfViewer(
                      url: latestNotice.attachmentUrl!,
                      title: latestNotice.title,
                    ),
                  ),
                );
              } else if (latestNotice.isImage) {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => FullScreenImageViewer(
                      imageUrls: [latestNotice.attachmentUrl!],
                    ),
                  ),
                );
              } else {
                try {
                  final uri = Uri.parse(latestNotice.attachmentUrl!.trim());
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint(
                    'Could not launch ${latestNotice.attachmentUrl}: $e',
                  );
                }
              }
            } else {
              NoticeActionService.instance.triggerAction(
                noticeId: latestNotice.id,
              );
              MainLayout.of(context)?.setSelectedIndex(8);
            }
          },
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'LATEST UPDATE',
                        style: AppTextStyles.overline.copyWith(
                          color: latestNotice.color,
                          fontSize: 9,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· $date',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  latestNotice.title,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to open announcement details',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventSlide(bool isDark) {
    return FutureBuilder<List<ClubEvent>>(
      future: widget.eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final allEvents = snapshot.data ?? [];
        final upcomingEvents = allEvents.where((e) => e.isUpcoming).toList()
          ..sort((a, b) => a.eventStartTime.compareTo(b.eventStartTime));

        if (upcomingEvents.isEmpty) {
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'UPCOMING EVENT',
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.primary,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No events scheduled soon.',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        final nextEvent = upcomingEvents.first;
        final date = DateFormat(
          'MMM d, h:mm a',
        ).format(nextEvent.eventStartTime);

        return InkWell(
          onTap: () {
            haptics.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailsPage(event: nextEvent),
              ),
            );
          },
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'UPCOMING EVENT',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.secondary,
                          fontSize: 9,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· $date',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  nextEvent.title,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  nextEvent.venue ?? 'Venue: Pulchowk Campus',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMuted,
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickAccessItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });
}

class _QuickAccessGrid extends StatelessWidget {
  final String userRole;

  const _QuickAccessGrid({required this.userRole});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<_QuickAccessItem> items = _getItems(context, userRole);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'Quick Access',
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _QuickAccessCard(item: item, isDark: isDark);
          },
        ),
      ],
    );
  }

  List<_QuickAccessItem> _getItems(BuildContext context, String role) {
    final r = role.toLowerCase().trim();
    if (r == 'admin') {
      return [
        _QuickAccessItem(
          icon: Icons.dashboard_customize_rounded,
          label: 'Admin Panel',
          color: const Color(0xFFEF4444),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(7),
        ),
        _QuickAccessItem(
          icon: Icons.note_add_rounded,
          label: 'Create Notice',
          color: const Color(0xFFF59E0B),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NoticeEditor()),
            );
          },
        ),
        _QuickAccessItem(
          icon: Icons.add_box_rounded,
          label: 'Create Event',
          color: const Color(0xFFEC4899),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EventEditor()),
            );
          },
        ),
        _QuickAccessItem(
          icon: Icons.groups_rounded,
          label: 'Clubs Info',
          color: const Color(0xFF10B981),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(5),
        ),
        _QuickAccessItem(
          icon: Icons.search_rounded,
          label: 'Lost & Found',
          color: const Color(0xFF8B5CF6),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(9),
        ),
        _QuickAccessItem(
          icon: Icons.wifi_rounded,
          label: 'WiFi Manager',
          color: const Color(0xFF06B6D4),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(12),
        ),
        _QuickAccessItem(
          icon: Icons.calendar_month_rounded,
          label: 'Event Calendar',
          color: const Color(0xFF6366F1),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CalendarPage()),
            );
          },
        ),
        _QuickAccessItem(
          icon: Icons.auto_stories_rounded,
          label: 'Marketplace',
          color: const Color(0xFFF97316),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(3),
        ),
        _QuickAccessItem(
          icon: Icons.settings_rounded,
          label: 'Settings',
          color: const Color(0xFF64748B),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(10),
        ),
      ];
    } else if (r == 'notice_manager') {
      return [
        _QuickAccessItem(
          icon: Icons.note_add_rounded,
          label: 'Create Notice',
          color: const Color(0xFFF59E0B),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NoticeEditor()),
            );
          },
        ),
        _QuickAccessItem(
          icon: Icons.campaign_rounded,
          label: 'Notices List',
          color: const Color(0xFF0EA5E9),
          onTap: () {
            NoticeActionService.instance.triggerAction(category: null);
            MainLayout.of(context)?.setSelectedIndex(8);
          },
        ),
        _QuickAccessItem(
          icon: Icons.schedule_rounded,
          label: 'Class Routine',
          color: const Color(0xFF6366F1),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(2),
        ),
        _QuickAccessItem(
          icon: Icons.quiz_rounded,
          label: 'Exam Routine',
          color: const Color(0xFFEF4444),
          onTap: () {
            NoticeActionService.instance.triggerAction(
              category: 'exam_routines',
            );
            MainLayout.of(context)?.setSelectedIndex(8);
          },
        ),
        _QuickAccessItem(
          icon: Icons.add_box_rounded,
          label: 'Create Event',
          color: const Color(0xFFEC4899),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EventEditor()),
            );
          },
        ),
        _QuickAccessItem(
          icon: Icons.wifi_rounded,
          label: 'WiFi Login',
          color: const Color(0xFF06B6D4),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(12),
        ),
        _QuickAccessItem(
          icon: Icons.calendar_month_rounded,
          label: 'Event Calendar',
          color: const Color(0xFF10B981),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CalendarPage()),
            );
          },
        ),
        _QuickAccessItem(
          icon: Icons.auto_stories_rounded,
          label: 'Book Market',
          color: const Color(0xFFF97316),
          onTap: () => MainLayout.of(context)?.setSelectedIndex(3),
        ),
        _QuickAccessItem(
          icon: Icons.support_agent_rounded,
          label: 'Support Desk',
          color: const Color(0xFF64748B),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpCenterPage()),
            );
          },
        ),
      ];
    } else {
      // Default: student
      return [
        _QuickAccessItem(
          icon: Icons.schedule_rounded,
          label: 'Class Routine',
          color: const Color(0xFF6366F1),
          onTap: () {
            haptics.selectionClick();
            MainLayout.of(context)?.setSelectedIndex(2);
          },
        ),
        _QuickAccessItem(
          icon: Icons.assignment_rounded,
          label: 'Assignments',
          color: const Color(0xFF10B981),
          onTap: () {
            haptics.selectionClick();
            MainLayout.of(context)?.setSelectedIndex(2);
          },
        ),
        _QuickAccessItem(
          icon: Icons.menu_book_rounded,
          label: 'My Subjects',
          color: const Color(0xFF0EA5E9),
          onTap: () {
            haptics.selectionClick();
            MainLayout.of(context)?.setSelectedIndex(2);
          },
        ),
        _QuickAccessItem(
          icon: Icons.quiz_rounded,
          label: 'Exam Routine',
          color: const Color(0xFFF59E0B),
          onTap: () {
            haptics.selectionClick();
            NoticeActionService.instance.triggerAction(
              category: 'exam_routines',
            );
            MainLayout.of(context)?.setSelectedIndex(8);
          },
        ),
        _QuickAccessItem(
          icon: Icons.assessment_rounded,
          label: 'Results',
          color: const Color(0xFF8B5CF6),
          onTap: () {
            haptics.selectionClick();
            NoticeActionService.instance.triggerAction(category: 'results');
            MainLayout.of(context)?.setSelectedIndex(8);
          },
        ),
        _QuickAccessItem(
          icon: Icons.calendar_month_rounded,
          label: 'Event Calendar',
          color: const Color(0xFFEC4899),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CalendarPage()),
            );
          },
        ),
        _QuickAccessItem(
          icon: Icons.wifi_rounded,
          label: 'WiFi Login',
          color: const Color(0xFF06B6D4),
          onTap: () {
            haptics.selectionClick();
            MainLayout.of(context)?.setSelectedIndex(12);
          },
        ),
        _QuickAccessItem(
          icon: Icons.bookmark_added_rounded,
          label: 'Saved Books',
          color: const Color(0xFFF97316),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const MarketplaceActivityPage(initialTabIndex: 3),
              ),
            );
          },
        ),
        _QuickAccessItem(
          icon: Icons.support_agent_rounded,
          label: 'Help & Support',
          color: const Color(0xFF64748B),
          onTap: () {
            haptics.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpCenterPage()),
            );
          },
        ),
      ];
    }
  }
}

class _QuickAccessCard extends StatelessWidget {
  final _QuickAccessItem item;
  final bool isDark;

  const _QuickAccessCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        haptics.lightImpact();
        item.onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withValues(alpha: 0.3)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                .withValues(alpha: 0.4),
          ),
          boxShadow: isDark ? [] : AppShadows.xs,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentNoticesSection extends StatelessWidget {
  final Future<List<Notice>> noticesFuture;
  final Future<StudentProfile?> studentProfileFuture;

  const _RecentNoticesSection({
    required this.noticesFuture,
    required this.studentProfileFuture,
  });

  bool _isRelevantToSemester(String text, int semester) {
    final t = text.toLowerCase();
    // Normalize text by removing spaces, commas, dots, dashes, and slashes
    // This allows matching variations like "III year / I part" seamlessly
    final normalizedText = t.replaceAll(RegExp(r'[\s,\.\-/]'), '');

    final ordinals = {
      1: '1st',
      2: '2nd',
      3: '3rd',
      4: '4th',
      5: '5th',
      6: '6th',
      7: '7th',
      8: '8th',
    };
    final ordinal = ordinals[semester] ?? '${semester}th';

    // Calculate year and part
    final int yearNum = ((semester - 1) ~/ 2) + 1;
    final int partNum = ((semester - 1) % 2) + 1;
    final yearOrdinal = ordinals[yearNum] ?? '${yearNum}th';
    final partOrdinal = ordinals[partNum] ?? '${partNum}th';
    final yearPartNumStr = '${yearOrdinal}year${partOrdinal}part';

    String notation = '';
    String yearPartRoman = '';
    switch (semester) {
      case 1:
        notation = 'i/i';
        yearPartRoman = 'iyearipart';
        break;
      case 2:
        notation = 'i/ii';
        yearPartRoman = 'iyeariipart';
        break;
      case 3:
        notation = 'ii/i';
        yearPartRoman = 'iiyearipart';
        break;
      case 4:
        notation = 'ii/ii';
        yearPartRoman = 'iiyeariipart';
        break;
      case 5:
        notation = 'iii/i';
        yearPartRoman = 'iiiyearipart';
        break;
      case 6:
        notation = 'iii/ii';
        yearPartRoman = 'iiiyeariipart';
        break;
      case 7:
        notation = 'iv/i';
        yearPartRoman = 'ivyearipart';
        break;
      case 8:
        notation = 'iv/ii';
        yearPartRoman = 'ivyeariipart';
        break;
    }

    return t.contains(ordinal) ||
        (notation.isNotEmpty && t.contains(notation)) ||
        t.contains('sem $semester') ||
        t.contains('semester $semester') ||
        (yearPartRoman.isNotEmpty && normalizedText.contains(yearPartRoman)) ||
        normalizedText.contains(yearPartNumStr);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([noticesFuture, studentProfileFuture]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final notices = (snapshot.data?[0] as List<Notice>?) ?? [];
        final profile = snapshot.data?[1] as StudentProfile?;
        final currentSemester = profile?.currentSemester;

        final relevantNotices = notices.where((n) {
          if (!n.isNew) return false;

          final t = n.title.toLowerCase();
          final l = n.level?.toLowerCase() ?? '';
          final isUrgent =
              t.contains('urgent') ||
              t.contains('important') ||
              l.contains('urgent');

          if (currentSemester == null) return isUrgent;

          final isForSem =
              _isRelevantToSemester(t, currentSemester) ||
              _isRelevantToSemester(l, currentSemester);
          return isUrgent || isForSem;
        }).toList();

        if (relevantNotices.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _SectionLabel(label: 'Relevant Notices'),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: relevantNotices.length,
                itemBuilder: (context, index) {
                  final notice = relevantNotices[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _RecentNoticeCard(notice: notice, isDark: isDark),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentNoticeCard extends StatelessWidget {
  final Notice notice;
  final bool isDark;

  const _RecentNoticeCard({required this.notice, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMMd().format(notice.displayDate);
    return Container(
      width: MediaQuery.of(context).size.width * 0.75,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.borderDark : AppColors.borderLight)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            haptics.lightImpact();
            if (notice.attachmentUrl != null &&
                notice.attachmentUrl!.isNotEmpty) {
              if (notice.isPdf) {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => CustomPdfViewer(
                      url: notice.attachmentUrl!,
                      title: notice.title,
                    ),
                  ),
                );
              } else if (notice.isImage) {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => FullScreenImageViewer(
                      imageUrls: [notice.attachmentUrl!],
                    ),
                  ),
                );
              } else {
                try {
                  final uri = Uri.parse(notice.attachmentUrl!.trim());
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Could not launch ${notice.attachmentUrl}: $e');
                }
              }
            } else {
              NoticeActionService.instance.triggerAction(noticeId: notice.id);
              MainLayout.of(context)?.setSelectedIndex(8);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: notice.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(notice.icon, size: 16, color: notice.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notice.categoryDisplay,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: notice.color,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      date,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notice.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
