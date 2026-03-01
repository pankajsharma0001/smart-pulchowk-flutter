import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:smart_pulchowk/features/search/search.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/models/club.dart';
import 'package:smart_pulchowk/core/models/notice.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/events/event_details_page.dart';
import 'package:smart_pulchowk/core/widgets/app_refresher.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [_MeshBackground(), _HomeContent()]),
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
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AppRefresher(
        onRefresh: _handleRefresh,
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
              _ExploreChips(
                clubsFuture: _clubsFuture,
                eventsFuture: _eventsFuture,
                noticeStatsFuture: _noticeStatsFuture,
                lostFoundFuture: _lostFoundFuture,
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _HeroSection(userCountFuture: _userCountFuture),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _RegisteredEventsSection(enrollmentFuture: _enrollmentFuture),
              const SizedBox(height: AppSpacing.sm),
              _NextEventSection(eventsFuture: _eventsFuture),
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

class _NextEventSection extends StatelessWidget {
  final Future<List<ClubEvent>> eventsFuture;
  const _NextEventSection({required this.eventsFuture});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return FutureBuilder<List<ClubEvent>>(
      initialData: apiService.getCachedEvents(),
      future: eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _NextEventLoader();
        }

        final allEvents = snapshot.data ?? [];
        final upcomingEvents = allEvents.where((e) => e.isUpcoming).toList()
          ..sort((a, b) => a.eventStartTime.compareTo(b.eventStartTime));

        if (upcomingEvents.isEmpty) return const SizedBox.shrink();

        final nextEvent = upcomingEvents.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _SectionLabel(label: 'Next Event'),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _NextEventCard(event: nextEvent),
            ),
          ],
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

class _NextEventLoader extends StatelessWidget {
  const _NextEventLoader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _SectionLabel(label: 'Next Event'),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                        Skeleton(height: 14, width: 180, borderRadius: 6),
                        SizedBox(height: 8),
                        Skeleton(height: 10, width: 120, borderRadius: 5),
                      ],
                    ),
                  ),
                  Skeleton(width: 20, height: 20, borderRadius: 4),
                ],
              ),
            ),
          ),
        ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreChips extends StatelessWidget {
  final Future<List<Club>> clubsFuture;
  final Future<List<ClubEvent>> eventsFuture;
  final Future<NoticeStats?> noticeStatsFuture;
  final Future<List<LostFoundItem>> lostFoundFuture;

  const _ExploreChips({
    required this.clubsFuture,
    required this.eventsFuture,
    required this.noticeStatsFuture,
    required this.lostFoundFuture,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> chips = [
      {
        'label': 'Campus Clubs',
        'icon': '👥',
        'future': clubsFuture,
        'countExtractor': (data) => (data as List).length.toString(),
        'tabIndex': 5,
      },
      {
        'label': 'Events',
        'icon': '📅',
        'future': eventsFuture,
        'countExtractor': (data) => (data as List).length.toString(),
        'tabIndex': 6,
      },
      {
        'label': 'IOE Notices',
        'icon': '📢',
        'future': noticeStatsFuture,
        'countExtractor': (data) =>
            (data as NoticeStats?)?.total.toString() ?? '0',
        'tabIndex': 8,
      },
      {
        'label': 'Lost & Found',
        'icon': '🔍',
        'future': lostFoundFuture,
        'countExtractor': (data) => (data as List).length.toString(),
        'tabIndex': 9,
      },
    ];

    // Wrap in NotificationListener to prevent horizontal scroll from triggering
    // the parent RefreshIndicator (pull-to-refresh)
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => true, // absorb scroll events
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: chips.map((chip) {
            final bool isActive = chip['active'] ?? false;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final Future? future = chip['future'];
            final int? tabIndex = chip['tabIndex'] as int?;

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  haptics.lightImpact();
                  if (tabIndex != null) {
                    MainLayout.of(context)?.setSelectedIndex(tabIndex);
                  }
                },
                borderRadius: BorderRadius.circular(99),
                child: AnimatedContainer(
                  duration: AppAnimations.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: isActive
                      ? BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: AppShadows.glow(
                            AppColors.primary,
                            intensity: 0.2,
                          ),
                        )
                      : isDark
                      ? AppDecorations.glassDark(
                          opacity: 0.05,
                          borderRadius: 99,
                        )
                      : AppDecorations.glass(opacity: 0.03, borderRadius: 99),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(chip['icon'], style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        chip['label'],
                        style: AppTextStyles.labelMedium.copyWith(
                          color: isActive
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      if (future != null)
                        FutureBuilder(
                          future: future,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _buildSmallLoader(isActive, isDark);
                            }
                            final count = chip['countExtractor'](snapshot.data);
                            if (count == '0' || count == null) {
                              return const SizedBox.shrink();
                            }

                            return _buildCountBadge(count, isActive, isDark);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSmallLoader(bool isActive, bool isDark) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(left: 6),
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          isActive
              ? Colors.white70
              : (isDark ? Colors.white30 : Colors.black26),
        ),
      ),
    );
  }

  Widget _buildCountBadge(String count, bool isActive, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.25)
            : (isDark
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(6),
        border: isActive
            ? null
            : Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 0.5,
              ),
      ),
      child: Text(
        count,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isActive
              ? Colors.white
              : (isDark ? AppColors.primaryLight : AppColors.primary),
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final Future<int> userCountFuture;
  const _HeroSection({required this.userCountFuture});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status Chip ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color:
                  (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.borderDark
                          : AppColors.borderLight)
                      .withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _StatusPing(),
              const SizedBox(width: 8),
              FutureBuilder<int>(
                future: userCountFuture,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  final countText =
                      snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData
                      ? '...'
                      : '$count';

                  return RichText(
                    text: TextSpan(
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: '$countText students ',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: 'active on campus'),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // ── Hero Title ──
        Text(
          'Your Campus.',
          style: AppTextStyles.h1.copyWith(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            height: 1.0,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ).createShader(ui.Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          child: Text(
            'Unified.',
            style: AppTextStyles.h1.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.0,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Everything you need for Pulchowk Campus, organized in one place.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // ── Main CTA ──
        StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final isLoggedIn = snapshot.hasData;
            return InkWell(
              onTap: () {
                haptics.mediumImpact();
                if (isLoggedIn) {
                  MainLayout.of(context)?.setSelectedIndex(2);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.glow(AppColors.primary),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isLoggedIn ? 'Open Dashboard' : 'Welcome!',
                      style: AppTextStyles.button.copyWith(color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NextEventCard extends StatelessWidget {
  final ClubEvent event;
  const _NextEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        haptics.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailsPage(event: event),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.venue ?? "TBA"} · ${DateFormat('h:mm a').format(event.eventStartTime)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background Effects ───────────────────────────────────────────────────────

class _MeshBackground extends StatefulWidget {
  const _MeshBackground();

  @override
  State<_MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<_MeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? const Color(0xFF080A10) : const Color(0xFFF1F5F9),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              _MeshBlob(
                color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.2),
                size: 400,
                offset: Offset(
                  size.width * -0.2 +
                      50 * math.sin(_controller.value * 2 * math.pi),
                  size.height * -0.1 +
                      80 * math.cos(_controller.value * math.pi),
                ),
              ),
              _MeshBlob(
                color: AppColors.secondary.withValues(
                  alpha: isDark ? 0.12 : 0.15,
                ),
                size: 350,
                offset: Offset(
                  size.width * 0.6 +
                      60 * math.cos(_controller.value * 2 * math.pi),
                  size.height * 0.1 +
                      40 * math.sin(_controller.value * math.pi),
                ),
              ),
              _MeshBlob(
                color: AppColors.tertiary.withValues(
                  alpha: isDark ? 0.08 : 0.1,
                ),
                size: 450,
                offset: Offset(
                  size.width * -0.1 +
                      70 * math.sin(_controller.value * math.pi),
                  size.height * 0.6 +
                      90 * math.cos(_controller.value * 2 * math.pi),
                ),
              ),
              _MeshBlob(
                color: AppColors.success.withValues(
                  alpha: isDark ? 0.05 : 0.08,
                ),
                size: 300,
                offset: Offset(
                  size.width * 0.7 + 40 * math.cos(_controller.value * math.pi),
                  size.height * 0.8 +
                      60 * math.sin(_controller.value * 2 * math.pi),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MeshBlob extends StatelessWidget {
  final Color color;
  final double size;
  final Offset offset;

  const _MeshBlob({
    required this.color,
    required this.size,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 100, spreadRadius: 50),
          ],
        ),
      ),
    );
  }
}

class _StatusPing extends StatefulWidget {
  const _StatusPing();

  @override
  State<_StatusPing> createState() => _StatusPingState();
}

class _StatusPingState extends State<_StatusPing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 2.5).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: FadeTransition(
            opacity: Tween(begin: 0.6, end: 0.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
