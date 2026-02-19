import 'package:flutter/material.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:flutter/services.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';
import 'package:smart_pulchowk/features/marketplace/sell_book_page.dart';
import 'package:smart_pulchowk/features/marketplace/marketplace_activity_page.dart';
import 'package:smart_pulchowk/features/marketplace/chat_list_page.dart';
import 'package:smart_pulchowk/core/widgets/interactive_wrapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOOK MARKETPLACE PAGE
// ─────────────────────────────────────────────────────────────────────────────

class BookMarketplacePage extends StatefulWidget {
  const BookMarketplacePage({super.key});

  @override
  State<BookMarketplacePage> createState() => _BookMarketplacePageState();
}

class _BookMarketplacePageState extends State<BookMarketplacePage>
    with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<BookListing> _books = [];
  List<BookCategory> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int? _selectedCategoryId;
  String? _searchQuery;
  BookCondition? _selectedCondition;
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'newest';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadBooks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreBooks();
    }
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    final categories = await _api.getBookCategories(forceRefresh: forceRefresh);
    if (mounted) setState(() => _categories = categories);
  }

  Future<void> _loadBooks({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
      });
    }

    final filters = BookFilters(
      page: _currentPage,
      limit: 12,
      search: _searchQuery,
      categoryId: _selectedCategoryId,
      condition: _selectedCondition?.value,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      sortBy: _sortBy,
    );

    final response = await _api.getBookListings(
      filters: filters,
      forceRefresh: refresh,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response != null) {
          _books = response.listings;
          _hasMore = response.pagination.hasMore;
        }
      });
    }
  }

  Future<void> _loadMoreBooks() async {
    setState(() => _isLoadingMore = true);
    _currentPage++;

    final filters = BookFilters(
      page: _currentPage,
      limit: 12,
      search: _searchQuery,
      categoryId: _selectedCategoryId,
      condition: _selectedCondition?.value,
      sortBy: _sortBy,
    );

    final response = await _api.getBookListings(filters: filters);

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        if (response != null) {
          _books.addAll(response.listings);
          _hasMore = response.pagination.hasMore;
        }
      });
    }
  }

  Future<void> _onRefresh() async {
    if (mounted) {
      debugPrint('BookMarketplacePage: Manual refresh. Syncing role...');
      await MainLayout.of(context)?.refreshUserRole();
      if (!mounted) return;
    }
    await Future.wait([
      _loadBooks(refresh: true),
      _loadCategories(forceRefresh: true),
    ]);
  }

  void _onSearch(String query) {
    _searchQuery = query.isEmpty ? null : query;
    _loadBooks(refresh: true);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = null;
      _searchController.clear();
      _selectedCategoryId = null;
      _selectedCondition = null;
      _minPrice = null;
      _maxPrice = null;
      _sortBy = 'newest';
    });
    _loadBooks(refresh: true);
  }

  void _showFilterBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) => _FilterBottomSheet(
        isDark: isDark,
        categories: _categories,
        initialCategoryId: _selectedCategoryId,
        initialCondition: _selectedCondition,
        initialMinPrice: _minPrice,
        initialMaxPrice: _maxPrice,
        initialSortBy: _sortBy,
        totalResults: _books.length, // Should ideally be from pagination total
        onApply: (catId, condition, min, max, sort) {
          setState(() {
            _selectedCategoryId = catId;
            _selectedCondition = condition;
            _minPrice = min;
            _maxPrice = max;
            _sortBy = sort;
          });
          _loadBooks(refresh: true);
        },
        onClear: () {
          _clearFilters();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: isDark
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              surfaceTintColor: Colors.transparent,
              expandedHeight: 68,
              toolbarHeight: 68,
              title: Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: cs.primary, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Book Market',
                    style: AppTextStyles.h3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Messages',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListPage()),
                  ),
                ),
                _ActionButton(
                  icon: Icons.dashboard_customize_rounded,
                  tooltip: 'My Activity',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MarketplaceActivityPage(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            // Move Search + Filters into header so they scroll with the sliver header
            SliverToBoxAdapter(
              child: _SearchFilterBar(
                searchController: _searchController,
                focusNode: _searchFocusNode,
                onSearch: _onSearch,
                isDark: isDark,
                hasActiveFilters:
                    _selectedCategoryId != null ||
                    _selectedCondition != null ||
                    _minPrice != null ||
                    _maxPrice != null ||
                    _sortBy != 'newest',
                onFilterTap: () => _showFilterBottomSheet(isDark),
              ),
            ),
            // Category Quick Filters
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: _CategoryQuickFilters(
                  categories: _categories,
                  selectedId: _selectedCategoryId,
                  onSelect: (id) {
                    setState(() => _selectedCategoryId = id);
                    _loadBooks(refresh: true);
                  },
                  isDark: isDark,
                  cs: cs,
                ),
              ),
          ],
          body: _isLoading
              ? _buildShimmerGrid(isDark)
              : _books.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: cs.primary,
                  edgeOffset: 0, // Align with the top of the body
                  child: _buildBookGrid(isDark),
                ),
        ),
        floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: 65),
                child: _buildFAB(cs),
              ),
      ),
    );
  }

  Widget _buildFAB(ColorScheme cs) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const SellBookPage()),
        );
        if (result == true) _onRefresh();
      },
      backgroundColor: cs.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Sell'),
    );
  }

  Widget _buildBookGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: _books.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _books.length) {
          return _ShimmerCard(isDark: isDark);
        }
        return _BookCard(
          book: _books[index],
          isDark: isDark,
          onTap: () => _openBookDetails(_books[index]),
        );
      },
    );
  }

  void _openBookDetails(BookListing book) async {
    final didChange = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BookDetailsPage(listing: book)),
    );
    if (didChange == true) _onRefresh();
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceContainerDark
                    : AppColors.surfaceContainerLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 48,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No books found',
              style: AppTextStyles.h4.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search terms.\n'
              'Or be the first to sell a book!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => _ShimmerCard(isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BUTTON (APP BAR)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH + FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode focusNode;
  final ValueChanged<String> onSearch;
  final bool hasActiveFilters;
  final VoidCallback onFilterTap;
  final bool isDark;

  const _SearchFilterBar({
    required this.searchController,
    required this.focusNode,
    required this.onSearch,
    required this.hasActiveFilters,
    required this.onFilterTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: focusNode,
              builder: (context, child) {
                final hasFocus = focusNode.hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceContainerDark
                        : AppColors.surfaceContainerLight,
                    borderRadius: AppRadius.fullAll,
                    border: Border.all(
                      color: hasFocus
                          ? cs.primary
                          : isDark
                          ? AppColors.borderDark.withValues(alpha: 0.3)
                          : AppColors.borderLight.withValues(alpha: 0.5),
                      width: hasFocus ? 1.5 : 1,
                    ),
                    boxShadow: hasFocus
                        ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: searchController,
                    focusNode: focusNode,
                    onSubmitted: onSearch,
                    cursorColor: cs.primary,
                    decoration: InputDecoration(
                      filled: false,
                      hintText: 'Search books, authors...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: hasFocus
                            ? cs.primary
                            : isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMuted,
                      ),
                      suffixIcon: ListenableBuilder(
                        listenable: searchController,
                        builder: (context, _) {
                          if (searchController.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              searchController.clear();
                              onSearch('');
                            },
                          );
                        },
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          _FilterToggleButton(
            onTap: onFilterTap,
            isDark: isDark,
            hasActiveFilters: hasActiveFilters,
          ),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ──────────────────────────────────────────────

class _FilterToggleButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final bool hasActiveFilters;

  const _FilterToggleButton({
    required this.onTap,
    required this.isDark,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveWrapper(
      onTap: onTap,
      borderRadius: AppRadius.fullAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceContainerDark
              : AppColors.surfaceContainerLight,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? AppColors.borderDark.withValues(alpha: 0.3)
                : AppColors.borderLight.withValues(alpha: 0.5),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            if (hasActiveFilters)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOK CARD
// ─────────────────────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final BookListing book;
  final bool isDark;
  final VoidCallback onTap;

  const _BookCard({
    required this.book,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = book.images?.isNotEmpty == true
        ? book.images!.first.imageUrl
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isDark
                ? AppColors.borderDark.withValues(alpha: 0.3)
                : AppColors.borderLight.withValues(alpha: 0.6),
          ),
          boxShadow: isDark ? null : AppShadows.xs,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ────────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'book_image_${book.id}',
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? SmartImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: _imagePlaceholder(context),
                          )
                        : _imagePlaceholder(context),
                  ),

                  // Image Gradient Overlay for better badge contrast
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Price badge
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: AppRadius.fullAll,
                        boxShadow: AppShadows.glow(cs.primary, intensity: 0.2),
                      ),
                      child: Text(
                        book.formattedPrice,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // Condition badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _conditionColor(
                          book.condition,
                        ).withValues(alpha: 0.95),
                        borderRadius: AppRadius.fullAll,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        book.condition.displayName.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                  // Sold overlay
                  if (book.status == BookStatus.sold)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: AppRadius.fullAll,
                            boxShadow: AppShadows.glow(AppColors.error),
                          ),
                          child: Text(
                            'SOLD',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info ─────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (book.seller != null)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: cs.primaryContainer,
                            child: SmartImage(
                              imageUrl: book.seller!.image,
                              shape: BoxShape.circle,
                              fit: BoxFit.cover,
                              errorWidget: Icon(
                                Icons.person,
                                size: 10,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              book.seller!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.overline.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
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

  Widget _imagePlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceContainerLight,
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 40,
          color: (isDark ? cs.primary : cs.primary).withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Color _conditionColor(BookCondition condition) {
    switch (condition) {
      case BookCondition.newBook:
        return AppColors.success;
      case BookCondition.likeNew:
        return const Color(0xFF0EA5E9);
      case BookCondition.good:
        return AppColors.primary;
      case BookCondition.fair:
        return AppColors.warning;
      case BookCondition.poor:
        return AppColors.error;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER / LOADING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  final bool isDark;
  const _ShimmerCard({required this.isDark});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerColor = widget.isDark
            ? AppColors.surfaceContainerHighDark
            : AppColors.surfaceContainerHighLight;
        final baseColor = widget.isDark
            ? AppColors.surfaceContainerDark
            : AppColors.surfaceContainerLight;

        return Container(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: widget.isDark
                  ? AppColors.borderDark.withValues(alpha: 0.2)
                  : AppColors.borderLight.withValues(alpha: 0.4),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      baseColor,
                      shimmerColor,
                      (0.5 + 0.5 * (_controller.value * 2 - 1).abs()),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 30,
                      color: shimmerColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            baseColor,
                            shimmerColor,
                            (0.3 + 0.5 * (_controller.value * 2 - 1).abs()),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            baseColor,
                            shimmerColor,
                            (0.2 + 0.5 * (_controller.value * 2 - 1).abs()),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            height: 18,
                            width: 18,
                            decoration: BoxDecoration(
                              color: shimmerColor.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 10,
                            width: 50,
                            decoration: BoxDecoration(
                              color: shimmerColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// FILTER BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBottomSheet extends StatefulWidget {
  final bool isDark;
  final List<BookCategory> categories;
  final int? initialCategoryId;
  final BookCondition? initialCondition;
  final double? initialMinPrice;
  final double? initialMaxPrice;
  final String initialSortBy;
  final int totalResults;
  final void Function(int?, BookCondition?, double?, double?, String) onApply;
  final VoidCallback onClear;

  const _FilterBottomSheet({
    required this.isDark,
    required this.categories,
    required this.initialCategoryId,
    required this.initialCondition,
    required this.initialMinPrice,
    required this.initialMaxPrice,
    required this.initialSortBy,
    required this.totalResults,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  int? _selectedCategoryId;
  BookCondition? _selectedCondition;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCondition = widget.initialCondition;
    _minPriceController = TextEditingController(
      text: widget.initialMinPrice?.toString() ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initialMaxPrice?.toString() ?? '',
    );
    _sortBy = widget.initialSortBy;
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedCategoryId != null) count++;
    if (_selectedCondition != null) count++;
    if (_minPriceController.text.isNotEmpty) count++;
    if (_maxPriceController.text.isNotEmpty) count++;
    if (_sortBy != 'newest') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemPadding = MediaQuery.of(context).padding.bottom;

    // Buffer for the custom bottom navbar which is approx 85px to clear the floating button
    final navbarOffset = bottomInset > 0 ? 12.0 : 40.0;

    return Container(
      padding: EdgeInsets.only(
        bottom: bottomInset + systemPadding + navbarOffset,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                if (_activeFiltersCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_activeFiltersCount active',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Section
                  _SectionHeader(title: 'CATEGORY', isDark: isDark),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterToggle(
                        label: 'All',
                        isSelected: _selectedCategoryId == null,
                        onTap: () => setState(() => _selectedCategoryId = null),
                        isDark: isDark,
                        cs: cs,
                      ),
                      ...widget.categories.map(
                        (cat) => _FilterToggle(
                          label: cat.name,
                          isSelected: _selectedCategoryId == cat.id,
                          onTap: () =>
                              setState(() => _selectedCategoryId = cat.id),
                          isDark: isDark,
                          cs: cs,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Condition Section
                  _SectionHeader(title: 'CONDITION', isDark: isDark),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterToggle(
                        label: 'All',
                        isSelected: _selectedCondition == null,
                        onTap: () => setState(() => _selectedCondition = null),
                        isDark: isDark,
                        cs: cs,
                      ),
                      ...BookCondition.values.map(
                        (c) => _FilterToggle(
                          label: c.displayName,
                          isSelected: _selectedCondition == c,
                          onTap: () => setState(() => _selectedCondition = c),
                          isDark: isDark,
                          cs: cs,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Price Range Section
                  _SectionHeader(title: 'PRICE RANGE', isDark: isDark),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceField(
                          controller: _minPriceController,
                          hint: 'Min',
                          isDark: isDark,
                          cs: cs,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PriceField(
                          controller: _maxPriceController,
                          hint: 'Max',
                          isDark: isDark,
                          cs: cs,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Sort Section
                  _SectionHeader(title: 'SORT BY', isDark: isDark),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterToggle(
                        label: 'Newest',
                        isSelected: _sortBy == 'newest',
                        onTap: () => setState(() => _sortBy = 'newest'),
                        isDark: isDark,
                        cs: cs,
                      ),
                      _FilterToggle(
                        label: 'Price: Low to High',
                        isSelected: _sortBy == 'price_asc',
                        onTap: () => setState(() => _sortBy = 'price_asc'),
                        isDark: isDark,
                        cs: cs,
                      ),
                      _FilterToggle(
                        label: 'Price: High to Low',
                        isSelected: _sortBy == 'price_desc',
                        onTap: () => setState(() => _sortBy = 'price_desc'),
                        isDark: isDark,
                        cs: cs,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Footer (Cleaned up, no top border to avoid 'two bars' issue)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.black12).withValues(
                    alpha: 0.1,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onClear();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                    ),
                    child: Text(
                      'Clear All',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primary,
                          cs.primary.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.glow(cs.primary, intensity: 0.25),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        final min = double.tryParse(_minPriceController.text);
                        final max = double.tryParse(_maxPriceController.text);
                        widget.onApply(
                          _selectedCategoryId,
                          _selectedCondition,
                          min,
                          max,
                          _sortBy,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Show Results',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.overline.copyWith(
          color: isDark ? Colors.white54 : Colors.black45,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;

  const _FilterToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.1)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? cs.primary
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected
                    ? cs.primary
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY QUICK FILTERS
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryQuickFilters extends StatelessWidget {
  final List<BookCategory> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final bool isDark;
  final ColorScheme cs;

  const _CategoryQuickFilters({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.isDark,
    required this.cs,
  });

  String _getEmoji(String name) {
    name = name.toLowerCase();
    if (name.contains('all')) return '✨';
    if (name.contains('text')) return '📖';
    if (name.contains('note')) return '📝';
    if (name.contains('insight')) return '💡';
    if (name.contains('manual')) return '📗';
    if (name.contains('entrance') || name.contains('prepar')) return '🎓';
    if (name.contains('reference')) return '📚';
    if (name.contains('novel') || name.contains('fiction')) return '📕';
    if (name.contains('career') || name.contains('job')) return '💼';
    return '📦';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44, // Reduced from 48
      margin: const EdgeInsets.only(bottom: 12, top: 2),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : categories[index - 1];
          final id = category?.id;
          final isSelected = selectedId == id;
          final label = isAll ? 'All' : category!.name;

          return _QuickFilterChip(
            label: label,
            emoji: _getEmoji(label),
            isSelected: isSelected,
            isDark: isDark,
            cs: cs,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(id);
            },
          );
        },
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveWrapper(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ), // Reduced from 16, 8
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.15)
              : (isDark
                    ? AppColors.surfaceContainerDark
                    : AppColors.surfaceContainerLight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? cs.primary
                : (isDark
                      ? AppColors.borderDark.withValues(alpha: 0.5)
                      : AppColors.borderLight.withValues(alpha: 0.8)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 13),
            ), // Reduced from 14
            const SizedBox(width: 6), // Reduced from 8
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected
                    ? cs.primary
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11.5, // Added explicit slightly smaller font
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final ColorScheme cs;

  const _PriceField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      cursorColor: cs.primary,
      style: AppTextStyles.bodyMedium.copyWith(
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}
