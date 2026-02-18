import 'package:flutter/material.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';
import 'package:smart_pulchowk/features/marketplace/seller_profile_page.dart';
import 'package:smart_pulchowk/features/marketplace/sell_book_page.dart';
import 'package:smart_pulchowk/features/marketplace/chat_room_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/core/widgets/interactive_wrapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE ACTIVITY PAGE — Unified Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceActivityPage extends StatefulWidget {
  final int initialTabIndex;
  const MarketplaceActivityPage({super.key, this.initialTabIndex = 0});

  @override
  State<MarketplaceActivityPage> createState() =>
      _MarketplaceActivityPageState();
}

class _MarketplaceActivityPageState extends State<MarketplaceActivityPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('My Marketplace'),
          backgroundColor: isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          elevation: 0,
          bottom: TabBar(
            isScrollable: false,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: AppTextStyles.labelMedium,
            tabs: const [
              Tab(text: 'Selling'),
              Tab(text: 'Inquiries'),
              Tab(text: 'Requests'),
              Tab(text: 'Saved'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SellingView(),
            _InquiriesView(),
            _RequestsView(),
            _SavedView(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. SELLING VIEW (My Listings)
// ─────────────────────────────────────────────────────────────────────────────

class _SellingView extends StatefulWidget {
  const _SellingView();
  @override
  State<_SellingView> createState() => _SellingViewState();
}

class _SellingViewState extends State<_SellingView> {
  final ApiService _api = ApiService();
  List<BookListing> _listings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh && mounted) {
      debugPrint('MarketplaceSellingView: Manual refresh. Syncing role...');
      await MainLayout.of(context)?.refreshUserRole();
      if (!mounted) return;
    }
    setState(() => _isLoading = true);
    final results = await _api.getMyBookListings(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _listings = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return _buildListingSkeleton(isDark);
    if (_listings.isEmpty) {
      return _buildEmptyState(
        context,
        isDark,
        Icons.inventory_2_rounded,
        'No active listings',
        'Sell your first book from the marketplace!',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _listings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ListingCard(
          book: _listings[i],
          isDark: isDark,
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailsPage(listing: _listings[i]),
              ),
            );
            if (changed == true) _load(forceRefresh: true);
          },
          onEdit: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => SellBookPage(existingListing: _listings[i]),
              ),
            );
            if (changed == true) _load(forceRefresh: true);
          },
          onDelete: () => _delete(_listings[i]),
          onMarkSold: _listings[i].status != BookStatus.sold
              ? () => _markSold(_listings[i])
              : null,
        ),
      ),
    );
  }

  Future<void> _delete(BookListing book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text('Remove "${book.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _api.deleteBookListing(book.id);
      if (res['success'] == true) {
        _load(forceRefresh: true);
      } else {
        _snack(res['message'] ?? 'Failed');
      }
    }
  }

  Future<void> _markSold(BookListing book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Sold?'),
        content: Text('Is "${book.title}" sold? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark Sold'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _api.markBookAsSold(book.id);
      if (res['success'] == true) {
        _load(forceRefresh: true);
      } else {
        _snack(res['message'] ?? 'Failed');
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _buildListingSkeleton(bool isDark) {
    return ShimmerWrapper(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 5,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              const Skeleton(height: 96, width: 72, borderRadius: 8),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Skeleton(height: 18, width: 120),
                        const Skeleton(height: 16, width: 50, borderRadius: 12),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Skeleton(height: 16, width: 80),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Skeleton(height: 24, width: 60, borderRadius: 12),
                        const SizedBox(width: 8),
                        const Skeleton(height: 24, width: 60, borderRadius: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildEmptyState(
  BuildContext context,
  bool isDark,
  IconData icon,
  String title,
  String sub,
) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.primaryLight : AppColors.primary)
                  .withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyles.h4.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            sub,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. INQUIRIES VIEW (Incoming Requests)
// ─────────────────────────────────────────────────────────────────────────────

class _InquiriesView extends StatefulWidget {
  const _InquiriesView();
  @override
  State<_InquiriesView> createState() => _InquiriesViewState();
}

class _InquiriesViewState extends State<_InquiriesView> {
  final ApiService _api = ApiService();
  List<BookPurchaseRequest> _requests = [];
  bool _isLoading = true;
  final Set<int> _selectedIds = {};

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh && mounted) {
      debugPrint('MarketplaceInquiriesView: Manual refresh. Syncing role...');
      await MainLayout.of(context)?.refreshUserRole();
      if (!mounted) return;
    }
    setState(() => _isLoading = true);
    final results = await _api.getIncomingPurchaseRequests(
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _requests = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _respond(int requestId, bool accept, {int? listingId}) async {
    final res = await _api.respondToPurchaseRequest(
      requestId,
      accept,
      listingId: listingId,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      _load(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Accepted request' : 'Rejected request'),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed')));
    }
  }

  Widget _buildInquirySkeleton(bool isDark) {
    return ShimmerWrapper(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Skeleton(height: 32, width: 32, borderRadius: 16),
                  const SizedBox(width: 10),
                  const Skeleton(height: 16, width: 100),
                  const Spacer(),
                  const Skeleton(height: 16, width: 60, borderRadius: 10),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Skeleton(height: 64, width: 48, borderRadius: 4),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Skeleton(height: 16, width: 140),
                        const SizedBox(height: 8),
                        const Skeleton(height: 14, width: 100),
                        const SizedBox(height: 4),
                        const Skeleton(height: 12, width: 80),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Skeleton(height: 36, borderRadius: 8)),
                  SizedBox(width: 12),
                  Expanded(child: Skeleton(height: 36, borderRadius: 8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bulkDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inquiries'),
        content: Text('Permanently remove ${_selectedIds.length} inquiries?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _api.deleteMultiplePurchaseRequests(
        _selectedIds.toList(),
      );
      if (res['success'] == true) {
        _snack('Deleted ${res['deletedCount']} inquiries');
        setState(() => _selectedIds.clear());
        _load();
      } else {
        _snack(res['message'] ?? 'Failed to delete');
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return _buildInquirySkeleton(isDark);
    if (_requests.isEmpty) {
      return _buildEmptyState(
        context,
        isDark,
        Icons.question_answer_rounded,
        'No inquiries yet',
        'Incoming requests for your books will appear here.',
      );
    }

    return Column(
      children: [
        if (_isSelectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                Text(
                  '${_selectedIds.length} selected',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedIds.clear()),
                  child: const Text('Clear'),
                ),
                IconButton(
                  onPressed: _bulkDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final r = _requests[i];
                final isSelected = _selectedIds.contains(r.id);
                return _InquiryCard(
                  request: r,
                  isDark: isDark,
                  isSelected: isSelected,
                  onAccept: _isSelectionMode
                      ? null
                      : () => _respond(r.id, true, listingId: r.listingId),
                  onReject: _isSelectionMode
                      ? null
                      : () => _respond(r.id, false, listingId: r.listingId),
                  onLongPress: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(r.id);
                      } else {
                        _selectedIds.add(r.id);
                      }
                    });
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(r.id);
                        } else {
                          _selectedIds.add(r.id);
                        }
                      });
                    }
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _InquiryCard extends StatelessWidget {
  final BookPurchaseRequest request;
  final bool isDark;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _InquiryCard({
    required this.request,
    required this.isDark,
    this.onAccept,
    this.onReject,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final book = request.listing;
    final buyer = request.buyer;
    final dateStr = DateFormat('MMM d, h:mm a').format(request.createdAt);

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                GestureDetector(
                  onTap: () {
                    if (buyer != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerProfilePage(
                            sellerId: buyer.id,
                            sellerName: buyer.name,
                            sellerImage: buyer.image,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: buyer?.image != null
                            ? CachedNetworkImageProvider(buyer!.image!)
                            : null,
                        child: buyer?.image == null
                            ? Icon(Icons.person, size: 16, color: cs.primary)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        buyer?.name ?? 'Anonymous',
                        style: AppTextStyles.labelLarge,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _StatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                if (book != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailsPage(listing: book),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: SizedBox(
                      width: 48,
                      height: 64,
                      child: book?.primaryImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: book!.primaryImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color:
                                    (isDark ? cs.primary : cs.primaryContainer)
                                        .withValues(alpha: 0.1),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: (isDark ? cs.primary : cs.primaryContainer)
                                  .withValues(alpha: 0.1),
                              child: Center(
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color:
                                      (isDark
                                              ? cs.primary
                                              : cs.primaryContainer)
                                          .withValues(alpha: 0.5),
                                  size: 24,
                                ),
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
                          book?.title ?? 'Unknown Book',
                          style: AppTextStyles.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Inquiry for Rs. ${book?.price ?? 'N/A'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: AppTextStyles.overline.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  '"${request.message}"',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (request.status == RequestStatus.pending && !isSelected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. REQUESTS VIEW (Outgoing)
// ─────────────────────────────────────────────────────────────────────────────
// Refactored from book_requests_page.dart

class _RequestsView extends StatefulWidget {
  const _RequestsView();
  @override
  State<_RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends State<_RequestsView> {
  final ApiService _api = ApiService();
  List<BookPurchaseRequest> _requests = [];
  bool _isLoading = true;
  final Set<int> _selectedIds = {};

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh && mounted) {
      debugPrint('MarketplaceRequestsView: Manual refresh. Syncing role...');
      await MainLayout.of(context)?.refreshUserRole();
      if (!mounted) return;
    }
    setState(() => _isLoading = true);
    final results = await _api.getMyPurchaseRequests(
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _requests = results;
        _isLoading = false;
        _selectedIds.clear();
      });
    }
  }

  Future<void> _cancel(BookPurchaseRequest r) async {
    final res = await _api.cancelPurchaseRequest(r.id);
    if (res['success'] == true) _load(forceRefresh: true);
  }

  Future<void> _delete(BookPurchaseRequest r) async {
    final res = await _api.deletePurchaseRequest(r.id);
    if (res['success'] == true) _load(forceRefresh: true);
  }

  void _viewContact(BookPurchaseRequest r) async {
    final seller = r.listing?.seller;
    if (seller == null) {
      _snack('Seller information not available');
      return;
    }

    final res = await _api.getSellerContactInfo(r.listingId);
    if (!mounted) return;

    final contactInfo = (res['success'] == true)
        ? res['data'] as Map<String, dynamic>?
        : null;
    final hasContactInfo = contactInfo != null && contactInfo.isNotEmpty;

    if (!hasContactInfo) {
      // No external contact info — go straight to in-app chat
      _openChat(r);
      return;
    }

    // Show bottom sheet with both options
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Contact ${seller.name}',
                style: AppTextStyles.h5.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // External contact option
              _contactOption(
                isDark: isDark,
                cs: cs,
                icon: _getContactIcon(contactInfo),
                iconColor: _getContactColor(contactInfo),
                title: _getContactMethodName(contactInfo),
                subtitle: _getContactValue(contactInfo),
                onTap: () {
                  Navigator.pop(ctx);
                  _launchContact(contactInfo);
                },
              ),
              const SizedBox(height: 10),
              // In-app message option
              _contactOption(
                isDark: isDark,
                cs: cs,
                icon: Icons.chat_bubble_rounded,
                iconColor: cs.primary,
                title: 'In-App Message',
                subtitle: 'Chat within the app',
                onTap: () {
                  Navigator.pop(ctx);
                  _openChat(r);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactOption({
    required bool isDark,
    required ColorScheme cs,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge),
                    Text(
                      subtitle,
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
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(BookPurchaseRequest r) {
    final seller = r.listing?.seller;
    if (seller == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          recipientId: seller.id,
          recipientName: seller.name,
          recipientImage: seller.image,
          listing: r.listing,
        ),
      ),
    );
  }

  IconData _getContactIcon(Map<String, dynamic> info) {
    final method = info['primaryContactMethod']?.toString().toLowerCase() ?? '';
    if (method.contains('whatsapp')) return Icons.chat_rounded;
    if (method.contains('messenger')) return Icons.facebook_rounded;
    if (method.contains('phone')) return Icons.call_rounded;
    if (method.contains('telegram')) return Icons.telegram_rounded;
    if (method.contains('email')) return Icons.email_rounded;
    return Icons.contact_mail_rounded;
  }

  Color _getContactColor(Map<String, dynamic> info) {
    final method = info['primaryContactMethod']?.toString().toLowerCase() ?? '';
    if (method.contains('whatsapp')) return const Color(0xFF25D366);
    if (method.contains('messenger')) return const Color(0xFF0084FF);
    if (method.contains('phone')) return Colors.green;
    if (method.contains('telegram')) return const Color(0xFF0088CC);
    if (method.contains('email')) return Colors.redAccent;
    return AppColors.primary;
  }

  String _getContactMethodName(Map<String, dynamic> info) {
    final method = info['primaryContactMethod']?.toString().toLowerCase() ?? '';
    if (method.contains('whatsapp')) return 'WhatsApp';
    if (method.contains('messenger')) return 'Messenger';
    if (method.contains('phone')) return 'Phone Call';
    if (method.contains('telegram')) return 'Telegram';
    if (method.contains('email')) return 'Email';
    return 'External Contact';
  }

  String _getContactValue(Map<String, dynamic> info) {
    final method = info['primaryContactMethod']?.toString().toLowerCase() ?? '';
    if (method.contains('whatsapp')) return info['whatsapp']?.toString() ?? '';
    if (method.contains('messenger')) {
      return info['facebookMessenger']?.toString() ?? '';
    }
    if (method.contains('phone')) return info['phoneNumber']?.toString() ?? '';
    if (method.contains('telegram')) {
      return info['telegramUsername']?.toString() ?? '';
    }
    if (method.contains('email')) return info['email']?.toString() ?? '';
    return info['otherContactDetails']?.toString() ?? '';
  }

  void _launchContact(Map<String, dynamic> info) {
    final method = info['primaryContactMethod']?.toString().toLowerCase() ?? '';
    final value = _getContactValue(info);
    if (value.isEmpty) return;

    Uri? uri;
    if (method.contains('whatsapp')) {
      final phone = value.replaceAll(RegExp(r'[^\d]'), '');
      uri = Uri.parse('https://wa.me/$phone');
    } else if (method.contains('phone')) {
      uri = Uri.parse('tel:$value');
    } else if (method.contains('email')) {
      uri = Uri.parse('mailto:$value');
    } else if (method.contains('telegram')) {
      final username = value.replaceAll('@', '');
      uri = Uri.parse('https://t.me/$username');
    } else if (method.contains('messenger')) {
      uri = Uri.parse('https://m.me/${Uri.encodeComponent(value)}');
    } else {
      _snack('Contact Info: $value');
      return;
    }

    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _rateSeller(BookPurchaseRequest r) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) =>
          RatingDialog(sellerName: r.listing?.seller?.name ?? 'Seller'),
    );

    if (result != null && mounted) {
      final res = await _api.rateSeller(
        sellerId: r.listing?.sellerId ?? '',
        listingId: r.listingId,
        rating: result['rating'] as int,
        review: result['review'] as String?,
      );

      if (mounted) {
        _snack(
          res['success'] == true
              ? 'Rating submitted!'
              : (res['message'] ?? 'Failed to rate'),
        );
      }
    }
  }

  Future<void> _bulkDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Requests'),
        content: Text('Remove ${_selectedIds.length} requests?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _api.deleteMultiplePurchaseRequests(
        _selectedIds.toList(),
      );
      if (res['success'] == true) {
        _snack('Deleted ${res['deletedCount']} requests');
        setState(() => _selectedIds.clear());
        _load();
      } else {
        _snack(res['message'] ?? 'Failed to delete');
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _buildRequestSkeleton(bool isDark) {
    return ShimmerWrapper(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Skeleton(height: 72, width: 56, borderRadius: 4),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Skeleton(height: 16, width: 120),
                                  const SizedBox(height: 6),
                                  const Skeleton(height: 14, width: 100),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Skeleton(height: 14, width: 80),
                                const SizedBox(height: 6),
                                const Skeleton(
                                  height: 16,
                                  width: 60,
                                  borderRadius: 10,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Skeleton(height: 16, width: 70),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Skeleton(height: 24, width: 120),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return _buildRequestSkeleton(isDark);
    if (_requests.isEmpty) {
      return _buildEmptyState(
        context,
        isDark,
        Icons.outbox_rounded,
        'No requests sent',
        'Books you requested to buy will show up here.',
      );
    }

    return Column(
      children: [
        if (_isSelectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                Text(
                  '${_selectedIds.length} selected',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedIds.clear()),
                  child: const Text('Clear'),
                ),
                IconButton(
                  onPressed: _bulkDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final r = _requests[i];
                final isSelected = _selectedIds.contains(r.id);
                return _RequestCard(
                  request: r,
                  isDark: isDark,
                  isSelected: isSelected,
                  onCancel:
                      (_isSelectionMode || r.status != RequestStatus.pending)
                      ? null
                      : () => _cancel(r),
                  onDelete: _isSelectionMode ? null : () => _delete(r),
                  onViewContact: _isSelectionMode
                      ? null
                      : () => _viewContact(r),
                  onRateSeller:
                      _isSelectionMode || r.status != RequestStatus.accepted
                      ? null
                      : () => _rateSeller(r),
                  onLongPress: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(r.id);
                      } else {
                        _selectedIds.add(r.id);
                      }
                    });
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(r.id);
                        } else {
                          _selectedIds.add(r.id);
                        }
                      });
                    }
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. SAVED VIEW (Saved Books)
// ─────────────────────────────────────────────────────────────────────────────
// Refactored from saved_books_page.dart

class _SavedView extends StatefulWidget {
  const _SavedView();
  @override
  State<_SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends State<_SavedView> {
  final ApiService _api = ApiService();
  List<SavedBook> _saved = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh && mounted) {
      debugPrint('MarketplaceSavedView: Manual refresh. Syncing role...');
      await MainLayout.of(context)?.refreshUserRole();
      if (!mounted) return;
    }
    setState(() => _isLoading = true);
    final results = await _api.getSavedBooks(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _saved = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return _buildSavedSkeleton(isDark);
    if (_saved.isEmpty) {
      return _buildEmptyState(
        context,
        isDark,
        Icons.bookmark_border_rounded,
        'Nothing saved',
        'Save books to access them later!',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: _saved.length,
        itemBuilder: (_, i) {
          final book = _saved[i].listing;
          if (book == null) return const SizedBox();
          return _SavedBookCard(
            book: book,
            isDark: isDark,
            onUnsave: () async {
              final messenger = ScaffoldMessenger.of(context);
              final res = await _api.unsaveBook(book.id);
              if (res['success'] == true) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Removed from saved')),
                );
                _load();
              }
            },
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookDetailsPage(listing: book)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedSkeleton(bool isDark) {
    return ShimmerWrapper(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Skeleton(
                  height: double.infinity,
                  width: double.infinity,
                  borderRadius: 0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton(height: 16, width: 120),
                    const SizedBox(height: 4),
                    const Skeleton(height: 14, width: 60),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Skeleton(height: 12, width: 80),
                        Skeleton(height: 18, width: 18, borderRadius: 9),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER COMPONENTS (Shared/Refactored)
// ─────────────────────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final BookListing book;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMarkSold;

  const _ListingCard({
    required this.book,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onMarkSold,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = book.primaryImageUrl;
    final isSold = book.status == BookStatus.sold;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: SizedBox(
                width: 72,
                height: 96,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color:
                              (isDark
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer)
                                  .withValues(alpha: 0.1),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    : Container(
                        color:
                            (isDark
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer)
                                .withValues(alpha: 0.1),
                        child: Center(
                          child: Icon(
                            Icons.menu_book_rounded,
                            color:
                                (isDark
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer)
                                    .withValues(alpha: 0.5),
                            size: 32,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          style: AppTextStyles.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isSold
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: AppRadius.fullAll,
                        ),
                        child: Text(
                          isSold ? 'SOLD' : 'ACTIVE',
                          style: TextStyle(
                            color: isSold ? Colors.red : Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${book.price}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InteractiveWrapper(
                        onTap: onEdit,
                        borderRadius: AppRadius.fullAll,
                        child: _actionBtn(
                          'Edit',
                          Icons.edit,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (onMarkSold != null)
                        InteractiveWrapper(
                          onTap: onMarkSold!,
                          borderRadius: AppRadius.fullAll,
                          child: _actionBtn('Sold', Icons.check, Colors.green),
                        ),
                      const Spacer(),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red,
                        ),
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

  Widget _actionBtn(String l, IconData i, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.1),
      borderRadius: AppRadius.fullAll,
    ),
    child: Row(
      children: [
        Icon(i, size: 12, color: c),
        const SizedBox(width: 4),
        Text(
          l,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final RequestStatus status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color c = AppColors.info;
    if (status == RequestStatus.accepted) c = Colors.green;
    if (status == RequestStatus.rejected) c = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SavedBookCard extends StatelessWidget {
  final BookListing book;
  final bool isDark;
  final VoidCallback onUnsave;
  final VoidCallback onTap;

  const _SavedBookCard({
    required this.book,
    required this.isDark,
    required this.onUnsave,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                  ? CachedNetworkImage(
                      imageUrl: book.primaryImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(color: Colors.grey[300]),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTextStyles.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Rs. ${book.price}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.seller?.name ?? 'Unknown',
                          style: AppTextStyles.overline,
                          maxLines: 1,
                        ),
                      ),
                      InteractiveWrapper(
                        onTap: onUnsave,
                        useInkWell: false, // IconButton has its own ripple
                        child: AbsorbPointer(
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.bookmark_remove_rounded,
                              size: 18,
                              color: Colors.grey,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
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
}

class _RequestCard extends StatelessWidget {
  final BookPurchaseRequest request;
  final bool isDark;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onViewContact;
  final VoidCallback? onRateSeller;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _RequestCard({
    required this.request,
    required this.isDark,
    this.onCancel,
    this.onDelete,
    this.onViewContact,
    this.onRateSeller,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final book = request.listing;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 8, top: 20),
                    child: Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (book != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailsPage(listing: book),
                          ),
                        );
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.smAll,
                              child: SizedBox(
                                width: 56,
                                height: 72,
                                child: book?.primaryImageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: book!.primaryImageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color:
                                              (isDark
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .primaryContainer)
                                                  .withValues(alpha: 0.1),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color:
                                            (isDark
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .primaryContainer)
                                                .withValues(alpha: 0.1),
                                        child: Center(
                                          child: Icon(
                                            Icons.menu_book_rounded,
                                            color:
                                                (isDark
                                                        ? Theme.of(
                                                            context,
                                                          ).colorScheme.primary
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .primaryContainer)
                                                    .withValues(alpha: 0.5),
                                            size: 28,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            if (book?.status == BookStatus.sold)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                  ),
                                  child: const Text(
                                    'SOLD',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book?.title ?? 'Unknown',
                                          style: AppTextStyles.labelLarge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'by ${book?.author ?? 'Unknown Author'}',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: isDark
                                                    ? AppColors.textMutedDark
                                                    : AppColors.textMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          final seller = book?.seller;
                                          if (seller != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    SellerProfilePage(
                                                      sellerId: seller.id,
                                                      sellerName: seller.name,
                                                      sellerImage: seller.image,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Text(
                                          book?.seller?.name ??
                                              'Unknown Seller',
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _StatusBadge(status: request.status),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Requested ${DateFormat('MMM d, yyyy').format(request.createdAt)}',
                                        style: AppTextStyles.overline.copyWith(
                                          fontSize: 10,
                                          color: isDark
                                              ? AppColors.textMutedDark
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    'Rs. ${book?.price ?? '0'}',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (book?.condition != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.xs,
                                        ),
                                      ),
                                      child: Text(
                                        book!.condition.displayName
                                            .toUpperCase(),
                                        style: AppTextStyles.overline.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  '"${request.message}"',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            if (!isSelected) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (request.status == RequestStatus.accepted) ...[
                    TextButton.icon(
                      onPressed: onViewContact,
                      icon: const Icon(Icons.mail_outline, size: 16),
                      label: Text(
                        'View Contact Info',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onRateSeller,
                      icon: const Icon(
                        Icons.star_outline_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      label: Text(
                        'Rate Seller',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RatingDialog extends StatefulWidget {
  final String sellerName;

  const RatingDialog({super.key, required this.sellerName});

  @override
  State<RatingDialog> createState() => RatingDialogState();
}

class RatingDialogState extends State<RatingDialog> {
  int _rating = 5;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.sellerName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How was your experience?'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    i < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 36,
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional review...',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'rating': _rating,
            'review': _reviewController.text.trim(),
          }),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
