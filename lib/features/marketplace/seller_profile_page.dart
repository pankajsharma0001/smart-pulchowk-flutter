import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';

class SellerProfilePage extends StatefulWidget {
  final String sellerId;
  final String? sellerName;
  final String? sellerImage;

  const SellerProfilePage({
    super.key,
    required this.sellerId,
    this.sellerName,
    this.sellerImage,
  });

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  bool _isLoading = true;
  SellerReputation? _reputation;
  List<BookListing> _listings = [];

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
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getSellerReputation(widget.sellerId),
      _api.getBookListings(
        filters: BookFilters(sellerId: widget.sellerId, limit: 20),
      ),
    ]);

    if (mounted) {
      setState(() {
        _reputation = results[0] as SellerReputation?;
        final response = results[1] as BookListingsResponse?;
        _listings = response?.listings ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark, cs),
          if (_isLoading)
            SliverToBoxAdapter(child: _buildShimmerLoading(isDark, cs))
          else ...[
            SliverToBoxAdapter(child: _buildReputationSummary(isDark, cs)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabDelegate(
                child: Container(
                  color: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: cs.primary,
                    labelColor: cs.primary,
                    unselectedLabelColor: isDark
                        ? Colors.white54
                        : Colors.black54,
                    labelStyle: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: 'Listings'),
                      Tab(text: 'Reviews'),
                    ],
                    onTap: (index) => setState(() {}),
                  ),
                ),
              ),
            ),
            if (_tabController.index == 0)
              _buildListingsGrid(isDark)
            else
              _buildReviewsList(isDark, cs),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark, ColorScheme cs) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Premium background: Subtle accent at the top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: isDark ? 0.3 : 0.1),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.elliptical(150, 20),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Hero(
                  tag: 'seller_avatar_${widget.sellerId}',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SmartImage(
                      imageUrl: widget.sellerImage,
                      width: 72,
                      height: 72,
                      shape: BoxShape.circle,
                      errorWidget: Icon(
                        Icons.person,
                        size: 36,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.sellerName ?? 'Seller Profile',
                  style: AppTextStyles.h5.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Seller',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReputationSummary(bool isDark, ColorScheme cs) {
    final rep = _reputation;
    if (rep == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
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
    );
  }

  Widget _buildListingsGrid(bool isDark) {
    if (_listings.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No active listings found.')),
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
          (context, index) => _BookCard(book: _listings[index], isDark: isDark),
          childCount: _listings.length,
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

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(label, style: AppTextStyles.overline.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatDivider() => Container(
    height: 30,
    width: 1,
    color: Colors.grey.withValues(alpha: 0.2),
  );

  Widget _buildShimmerLoading(bool isDark, ColorScheme cs) {
    return ShimmerWrapper(
      child: Column(
        children: [
          // Reputation Summary Skeleton
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    3,
                    (index) => const Column(
                      children: [
                        Skeleton(height: 16, width: 32),
                        SizedBox(height: 8),
                        Skeleton(height: 10, width: 48),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Skeleton(height: 2, width: double.infinity),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Skeleton(height: 48, width: 48, borderRadius: 24),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(height: 16, width: 120),
                          SizedBox(height: 8),
                          Skeleton(height: 12, width: 200),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab bar skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Skeleton(
                  height: 32,
                  width: 100,
                  borderRadius: 16,
                  margin: const EdgeInsets.only(right: 16),
                ),
                const Skeleton(height: 32, width: 100, borderRadius: 16),
              ],
            ),
          ),

          // Grid skeleton
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 4,
            itemBuilder: (_, _) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Skeleton(borderRadius: 12)),
                SizedBox(height: 12),
                Skeleton(height: 16, width: double.infinity),
                SizedBox(height: 8),
                Skeleton(height: 14, width: 80),
              ],
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

class _SliverTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverTabDelegate({required this.child});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverTabDelegate oldDelegate) => false;
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
