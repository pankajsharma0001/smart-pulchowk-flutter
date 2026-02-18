import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
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
    await Future.wait([
      _loadBooks(refresh: true),
      _loadCategories(forceRefresh: true),
    ]);
  }

  void _onSearch(String query) {
    _searchQuery = query.isEmpty ? null : query;
    _loadBooks(refresh: true);
  }

  void _onCategorySelected(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    _loadBooks(refresh: true);
  }

  void _onConditionSelected(BookCondition? condition) {
    setState(() => _selectedCondition = condition);
    _loadBooks(refresh: true);
  }

  void _onPriceRangeChanged(double? min, double? max) {
    setState(() {
      _minPrice = min;
      _maxPrice = max;
    });
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

  void _onSortChanged(String sortBy) {
    setState(() => _sortBy = sortBy);
    _loadBooks(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                categories: _categories,
                selectedCategoryId: _selectedCategoryId,
                onCategorySelected: _onCategorySelected,
                selectedCondition: _selectedCondition,
                onConditionSelected: _onConditionSelected,
                minPrice: _minPrice,
                maxPrice: _maxPrice,
                onPriceRangeChanged: _onPriceRangeChanged,
                onClearAll: _clearFilters,
                sortBy: _sortBy,
                onSortChanged: _onSortChanged,
                isDark: isDark,
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
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 85),
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

class _SearchFilterBar extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode focusNode;
  final ValueChanged<String> onSearch;
  final List<BookCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategorySelected;
  final BookCondition? selectedCondition;
  final ValueChanged<BookCondition?> onConditionSelected;
  final double? minPrice;
  final double? maxPrice;
  final void Function(double? min, double? max) onPriceRangeChanged;
  final VoidCallback onClearAll;
  final String sortBy;
  final ValueChanged<String> onSortChanged;
  final bool isDark;

  const _SearchFilterBar({
    required this.searchController,
    required this.focusNode,
    required this.onSearch,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.selectedCondition,
    required this.onConditionSelected,
    required this.minPrice,
    required this.maxPrice,
    required this.onPriceRangeChanged,
    required this.onClearAll,
    required this.sortBy,
    required this.onSortChanged,
    required this.isDark,
  });

  @override
  State<_SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<_SearchFilterBar> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = widget.isDark;

    return Column(
      children: [
        // ── Search & Toggle ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.focusNode,
                  builder: (context, child) {
                    final hasFocus = widget.focusNode.hasFocus;
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
                        controller: widget.searchController,
                        focusNode: widget.focusNode,
                        onSubmitted: widget.onSearch,
                        cursorColor: cs.primary,
                        decoration: InputDecoration(
                          filled: false,
                          hintText: 'Search books, authors...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMuted.withValues(alpha: 0.7),
                          ),
                          prefixIcon: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: hasFocus
                                  ? cs.primary
                                  : isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMuted,
                            ),
                          ),
                          suffixIcon: ListenableBuilder(
                            listenable: widget.searchController,
                            builder: (context, _) {
                              if (widget.searchController.text.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  widget.searchController.clear();
                                  widget.onSearch('');
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
                isExpanded: _isExpanded,
                onTap: _toggleExpanded,
                isDark: isDark,
                hasActiveFilters:
                    widget.selectedCategoryId != null ||
                    widget.selectedCondition != null ||
                    widget.minPrice != null ||
                    widget.maxPrice != null ||
                    widget.sortBy != 'newest' ||
                    widget.searchController.text.isNotEmpty,
              ),
            ],
          ),
        ),

        // ── Expanded Filters ──────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutQuart,
          child: _isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    // Categories
                    if (widget.categories.isNotEmpty)
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: widget.categories.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _FilterChip(
                                label: 'All',
                                isSelected: widget.selectedCategoryId == null,
                                onTap: () => widget.onCategorySelected(null),
                                isDark: isDark,
                                cs: cs,
                              );
                            }
                            final cat = widget.categories[index - 1];
                            return _FilterChip(
                              label: cat.name,
                              isSelected: widget.selectedCategoryId == cat.id,
                              onTap: () => widget.onCategorySelected(
                                widget.selectedCategoryId == cat.id
                                    ? null
                                    : cat.id,
                              ),
                              isDark: isDark,
                              cs: cs,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Conditions
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _FilterChip(
                            label: 'All Conditions',
                            isSelected: widget.selectedCondition == null,
                            onTap: () => widget.onConditionSelected(null),
                            isDark: isDark,
                            cs: cs,
                          ),
                          ...BookCondition.values.map(
                            (c) => _FilterChip(
                              label: c.displayName,
                              isSelected: widget.selectedCondition == c,
                              onTap: () => widget.onConditionSelected(
                                widget.selectedCondition == c ? null : c,
                              ),
                              isDark: isDark,
                              cs: cs,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Price Ranges
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _FilterChip(
                            label: 'Any Price',
                            isSelected:
                                widget.minPrice == null &&
                                widget.maxPrice == null,
                            onTap: () => widget.onPriceRangeChanged(null, null),
                            isDark: isDark,
                            cs: cs,
                          ),
                          _FilterChip(
                            label: '< 500',
                            isSelected:
                                widget.minPrice == null &&
                                widget.maxPrice == 500,
                            onTap: () => widget.onPriceRangeChanged(null, 500),
                            isDark: isDark,
                            cs: cs,
                          ),
                          _FilterChip(
                            label: '500 - 1500',
                            isSelected:
                                widget.minPrice == 500 &&
                                widget.maxPrice == 1500,
                            onTap: () => widget.onPriceRangeChanged(500, 1500),
                            isDark: isDark,
                            cs: cs,
                          ),
                          _FilterChip(
                            label: '1500 - 3000',
                            isSelected:
                                widget.minPrice == 1500 &&
                                widget.maxPrice == 3000,
                            onTap: () => widget.onPriceRangeChanged(1500, 3000),
                            isDark: isDark,
                            cs: cs,
                          ),
                          _FilterChip(
                            label: '3000+',
                            isSelected:
                                widget.minPrice == 3000 &&
                                widget.maxPrice == null,
                            onTap: () => widget.onPriceRangeChanged(3000, null),
                            isDark: isDark,
                            cs: cs,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Sorting
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sort_rounded,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          const SizedBox(width: 8),
                          _SortChip(
                            label: 'Newest',
                            value: 'newest',
                            currentValue: widget.sortBy,
                            onTap: widget.onSortChanged,
                            isDark: isDark,
                            cs: cs,
                          ),
                          _SortChip(
                            label: 'Price ↑',
                            value: 'price_asc',
                            currentValue: widget.sortBy,
                            onTap: widget.onSortChanged,
                            isDark: isDark,
                            cs: cs,
                          ),
                          _SortChip(
                            label: 'Price ↓',
                            value: 'price_desc',
                            currentValue: widget.sortBy,
                            onTap: widget.onSortChanged,
                            isDark: isDark,
                            cs: cs,
                          ),
                          _SortChip(
                            label: 'Title',
                            value: 'title',
                            currentValue: widget.sortBy,
                            onTap: widget.onSortChanged,
                            isDark: isDark,
                            cs: cs,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Clear All
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            widget.onClearAll();
                            setState(() => _isExpanded = false);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Clear All Filters'),
                          style: TextButton.styleFrom(
                            foregroundColor: cs.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.mdAll,
                              side: BorderSide(
                                color: cs.primary.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Supporting Widgets ──────────────────────────────────────────────

class _FilterToggleButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;
  final bool isDark;
  final bool hasActiveFilters;

  const _FilterToggleButton({
    required this.isExpanded,
    required this.onTap,
    required this.isDark,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InteractiveWrapper(
      onTap: onTap,
      borderRadius: AppRadius.fullAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isExpanded
              ? cs.primary
              : isDark
              ? AppColors.surfaceContainerDark
              : AppColors.surfaceContainerLight,
          shape: BoxShape.circle,
          border: Border.all(
            color: isExpanded
                ? cs.primary
                : isDark
                ? AppColors.borderDark.withValues(alpha: 0.3)
                : AppColors.borderLight.withValues(alpha: 0.5),
          ),
          boxShadow: isExpanded ? AppShadows.glow(cs.primary) : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isExpanded ? Icons.close_rounded : Icons.tune_rounded,
              size: 20,
              color: isExpanded
                  ? Colors.white
                  : isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            if (hasActiveFilters && !isExpanded)
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: cs.primaryContainer,
        labelStyle: AppTextStyles.labelMedium.copyWith(
          color: isSelected
              ? cs.primary
              : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.3)
              : (isDark
                    ? AppColors.borderDark.withValues(alpha: 0.2)
                    : AppColors.borderLight.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final String value;
  final String currentValue;
  final ValueChanged<String> onTap;
  final bool isDark;
  final ColorScheme cs;

  const _SortChip({
    required this.label,
    required this.value,
    required this.currentValue,
    required this.onTap,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == currentValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: AppRadius.fullAll,
            border: Border.all(
              color: isSelected
                  ? cs.primary
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isSelected
                  ? cs.primary
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
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
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => _imagePlaceholder(context),
                            errorWidget: (_, _, _) =>
                                _imagePlaceholder(context),
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
                            backgroundImage: book.seller!.image != null
                                ? CachedNetworkImageProvider(
                                    book.seller!.image!,
                                  )
                                : null,
                            child: book.seller!.image == null
                                ? Icon(
                                    Icons.person,
                                    size: 10,
                                    color: cs.primary,
                                  )
                                : null,
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
