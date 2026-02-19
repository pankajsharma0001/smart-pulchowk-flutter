import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/club.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/clubs/widgets/club_card.dart';
import 'package:smart_pulchowk/features/clubs/widgets/club_editor.dart';

class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;

  bool _isLoading = true;
  List<Club> _allClubs = [];
  List<Club> _filteredClubs = [];
  String? _error;
  String _userRole = 'student';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadClubs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs({bool forceRefresh = false}) async {
    if (!mounted) return;

    if (_allClubs.isEmpty || _error != null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // Sync user role and fetch clubs in parallel on force refresh
      final results = await Future.wait([
        _apiService.getClubs(forceRefresh: forceRefresh),
        _apiService.getUserRole(),
        if (forceRefresh) _apiService.refreshUserRole(),
      ]);

      final clubs = results[0] as List<Club>;
      final role = results[1] as String;
      if (mounted) {
        setState(() {
          _allClubs = clubs;
          _filteredClubs = clubs;
          _userRole = role;
          _isLoading = false;
          _error = null;
        });
        _onSearchChanged(_searchController.text);
        _animationController.reset();
        _animationController.forward();

        if (forceRefresh) {
          _animationController.reset();
          _animationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load clubs. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredClubs = _allClubs;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredClubs = _allClubs.where((club) {
        return club.name.toLowerCase().contains(lowercaseQuery) ||
            (club.description?.toLowerCase().contains(lowercaseQuery) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Clubs')),
        body: RefreshIndicator(
          onRefresh: () => _loadClubs(forceRefresh: true),
          child: Column(
            children: [
              // Search Bar
              _buildSearchBar(isDark),

              // Main Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                    ? _buildErrorState()
                    : _buildClubsGrid(),
              ),
            ],
          ),
        ),
        floatingActionButton: _userRole == 'admin'
            ? Container(
                margin: const EdgeInsets.only(bottom: 80),
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    final result = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const ClubEditor(),
                    );
                    if (result == true) {
                      _loadClubs(forceRefresh: true);
                    }
                  },
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Club'),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search clubs...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildClubsGrid() {
    if (_filteredClubs.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        100, // Bottom padding for navbar
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: _filteredClubs.length,
      itemBuilder: (context, index) {
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            (index / (index + 5) * 0.5).clamp(0.0, 1.0),
            1.0,
            curve: Curves.easeOutQuart,
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 30.0 * (1.0 - animation.value)),
              child: Opacity(
                opacity: animation.value,
                child: ClubCard(club: _filteredClubs[index]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const ShimmerClubCard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _searchController.text.isNotEmpty
                ? 'No clubs match your search'
                : 'No clubs found',
            style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => _loadClubs(forceRefresh: true),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
