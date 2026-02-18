import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_pulchowk/features/marketplace/sell_book_page.dart';
import 'package:smart_pulchowk/features/marketplace/seller_profile_page.dart';
import 'package:smart_pulchowk/core/widgets/interactive_wrapper.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:smart_pulchowk/features/marketplace/chat_room_page.dart';
import 'package:smart_pulchowk/features/marketplace/marketplace_activity_page.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOOK DETAILS PAGE
// ─────────────────────────────────────────────────────────────────────────────

class BookDetailsPage extends StatefulWidget {
  final BookListing listing;
  const BookDetailsPage({super.key, required this.listing});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  final ApiService _api = ApiService();
  late BookListing _book;
  BookPurchaseRequest? _myRequest;
  SellerReputation? _sellerReputation;
  bool _isSaved = false;
  bool _isLoadingRequest = true;
  bool _didChange = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _book = widget.listing;
    _isSaved = _book.isSaved; // Initialize immediately from passed listing

    // ── Synchronous cache check to avoid loading flicker ─────────────────────

    // 1. Check for detailed book listing in cache
    final cachedBook = ApiService.getCached<BookListing>(
      '${AppConstants.cacheBookDetail}${_book.id}',
    );
    if (cachedBook != null) {
      _book = cachedBook;
      _isSaved = _book.isSaved;
    }

    // 2. Check for purchase request status in cache
    final cachedRequest = ApiService.getCached<BookPurchaseRequest>(
      '${AppConstants.cacheRequestStatus}${_book.id}',
    );
    if (cachedRequest != null) {
      _myRequest = cachedRequest;
      _isLoadingRequest = false;
    }

    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final results = await Future.wait([
      _api.getBookListingById(_book.id),
      _api.getPurchaseRequestStatus(_book.id),
      if (_book.seller?.id != null)
        _api.getSellerReputation(_book.seller!.id.toString())
      else
        Future.value(null),
    ]);

    if (mounted) {
      setState(() {
        if (results[0] != null) _book = results[0] as BookListing;
        _myRequest = results[1] as BookPurchaseRequest?;
        _sellerReputation = results[2] as SellerReputation?;
        _isSaved = _book.isSaved;
        _isLoadingRequest = false;
      });
    }
  }

  Future<void> _toggleSave() async {
    final wasSaved = _isSaved;
    setState(() => _isSaved = !_isSaved);

    final result = wasSaved
        ? await _api.unsaveBook(_book.id)
        : await _api.saveBook(_book.id);

    if (result['success'] == true) {
      _didChange = true;
    } else if (mounted) {
      setState(() => _isSaved = wasSaved);
      _showSnackBar(result['message'] ?? 'Failed to update');
    }
  }

  Future<void> _sendPurchaseRequest() async {
    final message = await _showRequestDialog();
    if (message == null) return;

    final result = await _api.createPurchaseRequest(_book.id, message);
    if (result['success'] == true) {
      _showSnackBar('Request sent!');
      _didChange = true;
      _loadDetails();
    } else {
      _showSnackBar(result['message'] ?? 'Failed to send request');
    }
  }

  Future<String?> _showRequestDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Purchase Request'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add a message for the seller (optional)...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reportListing() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = 'spam';
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Report Listing'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  items: const [
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(value: 'fraud', child: Text('Fraud')),
                    DropdownMenuItem(
                      value: 'inappropriate',
                      child: Text('Inappropriate'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setDialogState(() => selected = v!),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue...',
                    labelText: 'Description',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    Navigator.pop(ctx, '$selected|${controller.text}');
                  }
                },
                child: const Text('Report'),
              ),
            ],
          ),
        );
      },
    );

    if (reason != null && _book.seller != null) {
      final parts = reason.split('|');
      final result = await _api.createMarketplaceReport(
        reportedUserId: _book.seller!.id.toString(),
        listingId: _book.id,
        category: parts[0],
        description: parts[1],
      );
      _showSnackBar(
        result['success'] == true ? 'Report submitted' : 'Failed to report',
      );
    }
  }

  void _shareListing() {
    final text =
        'Check out this book on Smart Pulchowk: \n\n'
        '${_book.title}\n'
        'Price: Rs. ${_book.price}\n'
        'Condition: ${_book.condition.name}\n\n'
        'Download the app to see more!';
    Share.share(text, subject: 'Book Listing: ${_book.title}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _didChange) {
          // Return true to indicate data changed
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── PREMIUM IMAGE GALLERY ──────────────────────────────────────
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              stretch: true,
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              leading: _circleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context, _didChange),
                isDark: isDark,
              ),
              actions: [
                _circleButton(
                  icon: _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onTap: _toggleSave,
                  isDark: isDark,
                  color: _isSaved ? cs.primary : null,
                ),
                _circleButton(
                  icon: Icons.share_rounded,
                  onTap: _shareListing,
                  isDark: isDark,
                ),
                if (!_book.isOwner)
                  _circleButton(
                    icon: Icons.more_vert_rounded,
                    onTap: () => _showMoreMenu(context),
                    isDark: isDark,
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: _buildImageGallery(isDark),
              ),
            ),

            // ── CONTENT SECTION ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Condition Badges
                      Row(
                        children: [
                          _badge(
                            _book.status.label.toUpperCase(),
                            _statusColor(_book.status),
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _badge(
                            _book.condition.displayName.toUpperCase(),
                            Colors.blue,
                            isDark,
                            isOutlined: true,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                size: 14,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_book.viewCount} views',
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title & Price Header
                      Text(
                        _book.title,
                        style: AppTextStyles.h2.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'by ${_book.author}',
                        style: AppTextStyles.h5.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Modern Price display
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Price:',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _book.formattedPrice,
                              style: AppTextStyles.h4.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── SELLER TRUST PROFILE ──────────────────────────────
                      _sectionHeader('Seller Trust Profile', isDark),
                      const SizedBox(height: 12),
                      _buildSellerTrustProfile(
                        context,
                        isDark,
                        cs,
                        _sellerReputation,
                      ),
                      const SizedBox(height: 32),

                      // ── DESCRIPTION ───────────────────────────────────────
                      if (_book.description != null &&
                          _book.description!.isNotEmpty) ...[
                        _sectionHeader('Description', isDark),
                        const SizedBox(height: 12),
                        Text(
                          _book.description!,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ── SPECIFICATIONS ────────────────────────────────────
                      _sectionHeader('Specifications', isDark),
                      const SizedBox(height: 16),
                      _buildSpecificationGrid(isDark),
                      const SizedBox(height: 120), // Extra space for bottom bar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(isDark, cs),
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: AppTextStyles.h4.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _badge(
    String label,
    Color color,
    bool isDark, {
    bool isOutlined = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: isOutlined
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _statusColor(BookStatus status) {
    switch (status) {
      case BookStatus.available:
        return Colors.green;
      case BookStatus.pending:
        return Colors.orange;
      case BookStatus.sold:
        return Colors.red;
      case BookStatus.removed:
        return Colors.grey;
    }
  }

  Widget _buildSellerTrustProfile(
    BuildContext context,
    bool isDark,
    ColorScheme cs,
    SellerReputation? reputation,
  ) {
    final seller = widget.listing.seller;
    if (seller == null) return const SizedBox.shrink();

    if (reputation == null && _isLoadingRequest) {
      return ShimmerWrapper(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  Skeleton(height: 56, width: 56, borderRadius: 28),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(height: 18, width: 120),
                        SizedBox(height: 8),
                        Skeleton(height: 14, width: 180),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Skeleton(height: 1, width: double.infinity),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Skeleton(height: 32, width: 60),
                  Skeleton(height: 32, width: 60),
                  Skeleton(height: 32, width: 60),
                ],
              ),
            ],
          ),
        ),
      );
    }

    void openProfile() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerProfilePage(
            sellerId: seller.id,
            sellerName: seller.name,
            sellerImage: seller.image,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: AppRadius.lgAll,
        boxShadow: isDark ? null : AppShadows.sm,
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: openProfile,
                child: Hero(
                  tag: 'seller_avatar_${seller.id}',
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: seller.image != null
                        ? CachedNetworkImageProvider(seller.image!)
                        : null,
                    child: seller.image == null
                        ? Icon(
                            Icons.person_rounded,
                            color: cs.primary,
                            size: 30,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: openProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            seller.name,
                            style: AppTextStyles.h5.copyWith(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.blue,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verified Seller • Active Member',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InteractiveWrapper(
                onTap: openProfile,
                useInkWell: false, // OutlinedButton has its own ripple
                child: AbsorbPointer(
                  child: OutlinedButton(
                    onPressed: () {}, // Preserving visual state
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 32),
                      side: BorderSide(
                        color: cs.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.fullAll,
                      ),
                    ),
                    child: const Text(
                      'Profile',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _trustMetric(
                  Icons.star_rounded,
                  reputation?.averageRating.toStringAsFixed(1) ?? 'N/A',
                  'Rating',
                  Colors.amber,
                ),
                _verticalDivider(isDark),
                _trustMetric(
                  Icons.reviews_rounded,
                  '${reputation?.totalRatings ?? 0}',
                  'Reviews',
                  Colors.blue,
                ),
                _verticalDivider(isDark),
                _trustMetric(
                  Icons.check_circle_rounded,
                  '${reputation?.soldCount ?? 0}',
                  'Sales',
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustMetric(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              val,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _verticalDivider(bool isDark) => VerticalDivider(
    color: isDark ? Colors.white10 : Colors.black12,
    thickness: 1,
    width: 1,
  );

  Widget _buildSpecificationGrid(bool isDark) {
    final specs = <_SpecItem>[
      if (_book.isbn != null)
        _SpecItem(Icons.qr_code_rounded, 'ISBN', _book.isbn!),
      if (_book.publisher != null)
        _SpecItem(Icons.business_rounded, 'Publisher', _book.publisher!),
      if (_book.edition != null)
        _SpecItem(Icons.bookmarks_rounded, 'Edition', _book.edition!),
      if (_book.publicationYear != null)
        _SpecItem(Icons.event_rounded, 'Year', '${_book.publicationYear}'),
      if (_book.courseCode != null)
        _SpecItem(Icons.school_rounded, 'Course', _book.courseCode!),
      if (_book.category != null)
        _SpecItem(Icons.category_rounded, 'Category', _book.category!.name),
      _SpecItem(Icons.access_time_rounded, 'Listed', _book.formattedDate),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: specs.map((s) => _buildSpecCard(s, isDark)).toList(),
    );
  }

  Widget _buildSpecCard(_SpecItem item, bool isDark) {
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
                Text(
                  item.value,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(bool isDark) {
    final images = _book.images ?? [];
    if (images.isEmpty) {
      return Container(
        color: isDark
            ? AppColors.surfaceContainerDark
            : AppColors.surfaceContainerLight,
        child: Center(
          child: Icon(
            Icons.menu_book_rounded,
            size: 64,
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (_, i) => Stack(
            fit: StackFit.expand,
            children: [
              // Blurred Background
              CachedNetworkImage(
                imageUrl: images[i].imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white).withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
              ),
              // Main Image
              GestureDetector(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(
                        imageUrls: images.map((it) => it.imageUrl).toList(),
                        initialIndex: i,
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: i == 0 ? 'book_image_${_book.id}' : images[i].imageUrl,
                  child: CachedNetworkImage(
                    imageUrl: images[i].imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => Container(
                      color: isDark
                          ? AppColors.surfaceContainerDark
                          : AppColors.surfaceContainerLight,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: isDark
                          ? AppColors.surfaceContainerDark
                          : AppColors.surfaceContainerLight,
                      child: const Icon(Icons.broken_image_rounded, size: 48),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Custom indicator
        if (images.length > 1)
          Positioned(
            bottom: 40, // Lowered to clear the rounded body better
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: AppAnimations.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentImageIndex == i ? 24 : 8,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      if (_currentImageIndex == i)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Image count badge
        Positioned(
          bottom: 40,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentImageIndex + 1}/${images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: _buildMainAction(isDark, cs),
    );
  }

  Widget _buildMainAction(bool isDark, ColorScheme cs) {
    if (_book.status == BookStatus.sold) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: AppRadius.mdAll,
        ),
        child: Text(
          'THIS ITEM IS ALREADY SOLD',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (_isLoadingRequest) {
      return ShimmerWrapper(
        child: Skeleton(
          height: 48,
          width: double.infinity,
          borderRadius: AppRadius.lg,
        ),
      );
    }

    if (_book.isOwner) {
      return FilledButton.icon(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => SellBookPage(existingListing: _book),
            ),
          );
          if (result == true) _loadDetails();
        },
        icon: const Icon(Icons.edit_rounded, size: 20),
        label: const Text('EDIT LISTING'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        ),
      );
    }

    if (_myRequest != null) {
      final status = _myRequest!.status;
      final color = status == RequestStatus.accepted
          ? Colors.green
          : status == RequestStatus.rejected
          ? Colors.red
          : cs.primary;

      if (status == RequestStatus.accepted) {
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _viewContact(_myRequest!),
                icon: const Icon(Icons.contact_support_rounded, size: 20),
                label: const Text('CONTACT SELLER'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rateSeller(_myRequest!),
                icon: const Icon(Icons.star_outline_rounded, size: 20),
                label: const Text('RATE SELLER'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
                ),
              ),
            ),
          ],
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          status == RequestStatus.accepted
              ? '✅ REQUEST ACCEPTED'
              : status == RequestStatus.rejected
              ? '❌ REQUEST DECLINED'
              : '⏳ REQUEST PENDING',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: _sendPurchaseRequest,
      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
      label: const Text('SEND PURCHASE REQUEST'),
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        elevation: 8,
        shadowColor: cs.primary.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InteractiveWrapper(
        onTap: onTap,
        borderRadius: AppRadius.fullAll,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withValues(
              alpha: 0.7,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                color ??
                (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Report Listing'),
              onTap: () {
                Navigator.pop(ctx);
                _reportListing();
              },
            ),
            if (_book.seller != null)
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Block Seller',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Block User?'),
                      content: const Text(
                        'You will no longer see any listings from this user.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Block',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final result = await _api.blockMarketplaceUser(
                      _book.seller!.id.toString(),
                    );
                    if (result['success'] == true) {
                      _showSnackBar('User blocked');
                      _didChange = true;
                      if (context.mounted) Navigator.pop(context, true);
                    } else {
                      _showSnackBar(result['message'] ?? 'Failed to block');
                    }
                  }
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _viewContact(BookPurchaseRequest r) async {
    final seller = r.listing?.seller ?? _book.seller;
    if (seller == null) {
      _showSnackBar('Seller information not available');
      return;
    }

    final res = await _api.getSellerContactInfo(r.listingId);
    if (!mounted) return;

    final contactInfo = (res['success'] == true)
        ? res['data']?.toString()
        : null;
    final hasContactInfo = contactInfo != null && contactInfo.isNotEmpty;

    if (!hasContactInfo) {
      _openChat(r);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
    final seller = r.listing?.seller ?? _book.seller;
    if (seller == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          recipientId: seller.id,
          recipientName: seller.name,
          recipientImage: seller.image,
          listing: r.listing ?? _book,
        ),
      ),
    );
  }

  IconData _getContactIcon(String contactInfo) {
    final lower = contactInfo.toLowerCase();
    if (lower.startsWith('whatsapp')) return Icons.chat_rounded;
    if (lower.startsWith('messenger')) return Icons.facebook_rounded;
    if (lower.startsWith('phone')) return Icons.call_rounded;
    if (lower.startsWith('telegram')) return Icons.telegram_rounded;
    if (lower.startsWith('email')) return Icons.email_rounded;
    return Icons.contact_mail_rounded;
  }

  Color _getContactColor(String contactInfo) {
    final lower = contactInfo.toLowerCase();
    if (lower.startsWith('whatsapp')) return const Color(0xFF25D366);
    if (lower.startsWith('messenger')) return const Color(0xFF0084FF);
    if (lower.startsWith('phone')) return Colors.green;
    if (lower.startsWith('telegram')) return const Color(0xFF0088CC);
    if (lower.startsWith('email')) return Colors.redAccent;
    return AppColors.primary;
  }

  String _getContactMethodName(String contactInfo) {
    if (contactInfo.contains(': ')) {
      return contactInfo.split(': ').first;
    }
    return 'External Contact';
  }

  String _getContactValue(String contactInfo) {
    if (contactInfo.contains(': ')) {
      return contactInfo.split(': ').sublist(1).join(': ');
    }
    return contactInfo;
  }

  void _launchContact(String contactInfo) {
    final value = _getContactValue(contactInfo);
    final method = contactInfo.toLowerCase();
    Uri? uri;

    if (method.startsWith('whatsapp')) {
      final phone = value.replaceAll(RegExp(r'[^\d+]'), '');
      uri = Uri.parse('https://wa.me/$phone');
    } else if (method.startsWith('phone')) {
      uri = Uri.parse('tel:$value');
    } else if (method.startsWith('email')) {
      uri = Uri.parse('mailto:$value');
    } else if (method.startsWith('telegram')) {
      final username = value.replaceAll('@', '');
      uri = Uri.parse('https://t.me/$username');
    } else if (method.startsWith('messenger')) {
      uri = Uri.parse('https://m.me/${Uri.encodeComponent(value)}');
    }

    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Contact: $contactInfo');
    }
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
        _showSnackBar(
          res['success'] == true
              ? 'Rating submitted!'
              : (res['message'] ?? 'Failed to rate'),
        );
      }
    }
  }
}

class _SpecItem {
  final IconData icon;
  final String label;
  final String value;
  _SpecItem(this.icon, this.label, this.value);
}
