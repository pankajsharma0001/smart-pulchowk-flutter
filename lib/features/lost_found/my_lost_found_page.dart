import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/features/lost_found/widgets/lost_found_card.dart';
import 'package:smart_pulchowk/features/lost_found/lost_found_details_page.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';

class MyLostFoundPage extends StatefulWidget {
  const MyLostFoundPage({super.key});

  @override
  State<MyLostFoundPage> createState() => _MyLostFoundPageState();
}

class _MyLostFoundPageState extends State<MyLostFoundPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  List<LostFoundItem> _myItems = [];
  List<LostFoundClaim> _myClaims = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.getMyLostFoundItems(forceRefresh: forceRefresh),
        _apiService.getMyLostFoundClaims(forceRefresh: forceRefresh),
      ]);

      if (mounted) {
        setState(() {
          _myItems = results[0] as List<LostFoundItem>;
          _myClaims = results[1] as List<LostFoundClaim>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lost & Found'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Reports'),
            Tab(text: 'My Claims'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildItemsList(), _buildClaimsList()],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_isLoading && _myItems.isEmpty) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_myItems.isEmpty) {
      return _buildEmptyState(
        'No reports found',
        'You haven\'t reported any lost or found items yet.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchMyData(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _myItems.length,
        itemBuilder: (context, index) {
          return LostFoundCard(
            item: _myItems[index],
            type: LostFoundCardType.list,
            showOwner: false,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LostFoundDetailsPage(itemId: _myItems[index].id),
                ),
              );
              _fetchMyData(forceRefresh: true);
            },
          );
        },
      ),
    );
  }

  Widget _buildClaimsList() {
    if (_isLoading && _myClaims.isEmpty) {
      return _buildLoadingState(isClaims: true);
    }
    if (_error != null) return _buildErrorState();
    if (_myClaims.isEmpty) {
      return _buildEmptyState(
        'No claims found',
        'You haven\'t made any claims yet.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchMyData(forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _myClaims.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final claim = _myClaims[index];
          return _buildClaimItem(claim);
        },
      ),
    );
  }

  Widget _buildClaimItem(LostFoundClaim claim) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LostFoundDetailsPage(itemId: claim.itemId),
          ),
        );
        _fetchMyData(forceRefresh: true);
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Item Image
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 60,
                height: 60,
                child: SmartImage(
                  imageUrl:
                      claim.item?.images != null &&
                          claim.item!.images.isNotEmpty
                      ? claim.item!.images.first.imageUrl
                      : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    claim.item?.title ?? 'Item #${claim.itemId}',
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    claim.message,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildClaimStatusBadge(claim.status),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimStatusBadge(LostFoundClaimStatus status) {
    Color color;
    switch (status) {
      case LostFoundClaimStatus.accepted:
        color = AppColors.success;
        break;
      case LostFoundClaimStatus.rejected:
        color = AppColors.error;
        break;
      case LostFoundClaimStatus.cancelled:
        color = AppColors.textMuted;
        break;
      default:
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: AppTextStyles.overline.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoadingState({bool isClaims = false}) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (isClaims) {
          return _buildClaimShimmer(context);
        }
        return _buildItemShimmer(context);
      },
    );
  }

  Widget _buildItemShimmer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _shimmerBox(80, 80, radius: AppRadius.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(double.infinity, 16),
                const SizedBox(height: 8),
                _shimmerBox(160, 12),
                const SizedBox(height: 8),
                _shimmerBox(100, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimShimmer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _shimmerBox(60, 60, radius: AppRadius.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(double.infinity, 14),
                const SizedBox(height: 6),
                _shimmerBox(180, 12),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _shimmerBox(60, 22, radius: 6),
        ],
      ),
    );
  }

  Widget _shimmerBox(double width, double height, {double radius = 4}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.8),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () {
        /* triggers rebuild for pulsing effect */
      },
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.h5),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Something went wrong'),
          TextButton(
            onPressed: () => _fetchMyData(forceRefresh: true),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
