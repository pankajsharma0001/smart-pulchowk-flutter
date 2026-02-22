import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/favorites_provider.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/models/club.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/features/clubs/widgets/club_card.dart';
import 'package:smart_pulchowk/features/events/widgets/event_card.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  List<Club> _favoriteClubs = [];
  List<ClubEvent> _favoriteEvents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading &&
        _favoriteClubs.isEmpty &&
        _favoriteEvents.isEmpty &&
        _error == null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final favorites = FavoritesProvider.of(context);

      // Load clubs and events in parallel
      final results = await Future.wait([
        _loadClubs(favorites.favoriteClubIds),
        _loadEvents(favorites.favoriteEventIds),
      ]);

      if (mounted) {
        setState(() {
          _favoriteClubs = results[0] as List<Club>;
          _favoriteEvents = results[1] as List<ClubEvent>;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading favorites: $e\n$st');
      if (mounted) {
        setState(() {
          _error = 'Failed to load favorites';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Club>> _loadClubs(Set<int> ids) async {
    if (ids.isEmpty) return [];
    List<Club> clubs = [];
    for (final id in ids) {
      final club = await _apiService.getClub(id);
      if (club != null) clubs.add(club);
    }
    return clubs;
  }

  Future<List<ClubEvent>> _loadEvents(Set<int> ids) async {
    if (ids.isEmpty) return [];
    // For events, we might need a specific endpoint or fetch individually
    // For now, let's assume we fetch them individually or from all events
    final allEvents = await _apiService.getAllEvents();
    return allEvents.where((e) => ids.contains(e.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Mesh/Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0F172A),
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A),
                        ]
                      : [
                          const Color(0xFFF8FAFC),
                          const Color(0xFFF1F5F9),
                          const Color(0xFFE2E8F0),
                        ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                _buildTabs(isDark),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.primary,
                        child: _buildClubsList(isDark),
                      ),
                      RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.primary,
                        child: _buildEventsList(isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
            splashRadius: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Favorites',
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Quick access to your preferred clubs and events',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark
            ? AppColors.textMutedDark
            : AppColors.textMuted,
        labelStyle: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'Clubs'),
          Tab(text: 'Events'),
        ],
      ),
    );
  }

  Widget _buildClubsList(bool isDark) {
    if (_isLoading) return _buildShimmerList(isClubsTab: true);
    if (_error != null) return _buildErrorState();
    if (_favoriteClubs.isEmpty) {
      return _buildEmptyState(
        'No favorite clubs yet',
        'Browse clubs and tap the heart icon to add them here.',
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _favoriteClubs.length,
      itemBuilder: (context, index) {
        return ClubCard(club: _favoriteClubs[index]);
      },
    );
  }

  Widget _buildEventsList(bool isDark) {
    if (_isLoading) return _buildShimmerList(isClubsTab: false);
    if (_error != null) return _buildErrorState();
    if (_favoriteEvents.isEmpty) {
      return _buildEmptyState(
        'No favorite events yet',
        'Browse events and tap the heart icon to add them here.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: _favoriteEvents.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EventCard(
            event: _favoriteEvents[index],
            type: EventCardType.list,
          ),
        );
      },
    );
  }

  Widget _buildShimmerList({required bool isClubsTab}) {
    if (isClubsTab) {
      return GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const ShimmerInfoCard(height: 200),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: ShimmerInfoCard(height: 120),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(title, style: AppTextStyles.h4),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(_error ?? 'An error occurred', style: AppTextStyles.h5),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
