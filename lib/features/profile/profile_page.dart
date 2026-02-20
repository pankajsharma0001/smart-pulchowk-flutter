import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/user.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';
import 'package:smart_pulchowk/features/settings/settings_page.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // 1. Initial Load (Try Cache first for instant feel)
    setState(
      () => _isLoading = _user == null,
    ); // Only show loading if we have NO data at all

    try {
      final results = await Future.wait([
        _api.getCurrentUser(),
        _api.getMyBookListings(),
      ]);

      if (mounted) {
        setState(() {
          _user = results[0] as AppUser?;
          _myListings = results[1] as List<BookListing>? ?? [];
          if (_user != null) _isLoading = false;
        });

        if (_user != null) {
          final rep = await _api.getSellerReputation(_user!.id);
          if (mounted) {
            setState(() {
              _reputation = rep;
              _isLoading = false;
            });
          }
        }
      }

      // 2. Background Refresh (Force refresh from network)
      final refreshResults = await Future.wait([
        _api.getCurrentUser(forceRefresh: true),
        _api.getMyBookListings(forceRefresh: true),
      ]);

      if (mounted) {
        setState(() {
          _user = refreshResults[0] as AppUser? ?? _user;
          _myListings = refreshResults[1] as List<BookListing>? ?? _myListings;
        });

        if (_user != null) {
          final rep = await _api.getSellerReputation(
            _user!.id,
            forceRefresh: true,
          );
          if (mounted) {
            setState(() {
              _reputation = rep ?? _reputation;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        body: _buildShimmerLoading(isDark, cs),
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

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    const double bottomHeight = 48.0;
    const double toolbarHeight = 60.0;
    const double expandedHeight = 320.0;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: expandedHeight,
              toolbarHeight: toolbarHeight,
              backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
              elevation: 0,
              leading: const SizedBox.shrink(), // Remove back button space
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
                  tabs: const [
                    Tab(text: 'My Listings'),
                    Tab(text: 'Reviews'),
                  ],
                  onTap: (index) => setState(() {}),
                ),
              ),
            ),

            // Reputation Summary (Now scrolls away under the pinned appbar)
            SliverToBoxAdapter(child: _buildReputationSummary(isDark, cs)),

            if (_tabController.index == 0)
              _buildListingsGrid(isDark)
            else
              _buildReviewsList(isDark, cs),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlexibleHeader(
    bool isDark,
    ColorScheme cs,
    double progress,
    double statusBarHeight,
  ) {
    // Reuse the logic from the previous ProfileHeaderDelegate.build
    final double avatarSize = 120 - (80 * progress); // 120 -> 40
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
          // Background Gradient
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

          // Scaling Avatar
          Positioned(
            left:
                (screenWidth / 2 - avatarSize / 2) * (1 - progress) +
                (20 * progress),
            top: statusBarHeight + (45 * (1 - progress)) + (10 * progress),
            child: Stack(
              children: [
                Container(
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
              ],
            ),
          ),

          // Name and Info
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
                  ],
                ),
              ),
            ),

          // Compact Title
          if (progress > 0.8)
            Positioned(
              left: 72,
              top: statusBarHeight + 10, // Vertically centered in 60px toolbar
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

          // Settings Button
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

  Widget _buildReputationSummary(bool isDark, ColorScheme cs) {
    final rep = _reputation;
    if (rep == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.cardDark : Colors.white).withValues(
          alpha: 0.8,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Rating',
                rep.averageRating.toStringAsFixed(1),
                Icons.star_rounded,
                Colors.orange,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Sold',
                rep.soldCount.toString(),
                Icons.shopping_bag_rounded,
                cs.primary,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Reviews',
                rep.totalRatings.toString(),
                Icons.reviews_rounded,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Member since ${DateFormat('MMMM yyyy').format(_user!.createdAt)}',
                style: AppTextStyles.caption.copyWith(color: Colors.grey),
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
    return InkWell(
      onTap: () => haptics.selectionClick(),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.overline.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsGrid(bool isDark) {
    if (_myListings.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('You have no active listings.')),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _BookCard(book: _myListings[index], isDark: isDark),
          childCount: _myListings.length,
        ),
      ),
    );
  }

  Widget _buildReviewsList(bool isDark, ColorScheme cs) {
    final reviews = _reputation?.recentRatings ?? [];
    if (reviews.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No reviews yet.')),
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

  Widget _buildStatDivider() => Container(
    height: 30,
    width: 1,
    color: Colors.grey.withValues(alpha: 0.2),
  );

  Widget _buildShimmerLoading(bool isDark, ColorScheme cs) {
    return ShimmerWrapper(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 250,
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Skeleton(height: 88, width: 88, borderRadius: 44),
                  const SizedBox(height: 16),
                  const Skeleton(height: 24, width: 150),
                  const SizedBox(height: 8),
                  const Skeleton(height: 14, width: 200),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: AppRadius.lgAll,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (index) => const Skeleton(height: 40, width: 60),
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
                  const SizedBox(width: 16),
                  Skeleton(height: 30, width: 100, borderRadius: 15),
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

class _ReviewItem extends StatelessWidget {
  final SellerRating rating;
  final bool isDark;

  const _ReviewItem({required this.rating, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
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
            Text(
              rating.review!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
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

class _BookCard extends StatelessWidget {
  final BookListing book;
  final bool isDark;

  const _BookCard({required this.book, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailsPage(listing: book)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: book.primaryImageUrl != null
                  ? SmartImage(
                      imageUrl: book.primaryImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(
                          alpha: isDark ? 0.15 : 0.05,
                        ),
                      ),
                      child: Icon(
                        Icons.library_books_rounded,
                        size: 48,
                        color: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Rs. ${book.price}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
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
  }
}
