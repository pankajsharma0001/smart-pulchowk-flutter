import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/lost_found/widgets/lost_found_card.dart';
import 'package:smart_pulchowk/features/lost_found/lost_found_details_page.dart';
import 'package:smart_pulchowk/features/lost_found/report_lost_found_page.dart';
import 'package:smart_pulchowk/features/lost_found/my_lost_found_page.dart';

class LostFoundPage extends StatefulWidget {
  const LostFoundPage({super.key});

  @override
  State<LostFoundPage> createState() => _LostFoundPageState();
}

class _LostFoundPageState extends State<LostFoundPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<LostFoundItem> _items = [];
  bool _isLoading = true;
  String? _error;
  LostFoundCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadItems();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _loadItems();
    }
  }

  Future<void> _loadItems({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? type;
      if (_tabController.index == 1) type = 'lost';
      if (_tabController.index == 2) type = 'found';

      final items = await _apiService.getLostFoundItems(
        itemType: type,
        category: _selectedCategory?.name,
        q: _searchQuery.isNotEmpty ? _searchQuery : null,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _items = items;
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lost & Found'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              tooltip: 'My Items',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyLostFoundPage(),
                  ),
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: AppDecorations.input(
                      hint: 'Search items...',
                      prefixIcon: Icons.search_rounded,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _loadItems();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (val) {
                      setState(() => _searchQuery = val);
                      _loadItems();
                    },
                  ),
                ),
                // Tabs
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Lost'),
                    Tab(text: 'Found'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            _buildCategoryFilter(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadItems(forceRefresh: true),
                child: _isLoading && _items.isEmpty
                    ? _buildLoadingState()
                    : _error != null
                    ? _buildErrorState()
                    : _items.isEmpty
                    ? _buildEmptyState()
                    : _buildItemList(),
              ),
            ),
          ],
        ),
        floatingActionButton: MediaQuery.of(context).viewInsets.bottom != 0
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportLostFoundPage(),
                      ),
                    );
                    if (result == true) {
                      _loadItems(forceRefresh: true);
                    }
                  },
                  label: const Text('Report'),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: LostFoundCategory.values.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedCategory == null;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: const Text('All Categories'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = null);
                    _loadItems();
                  }
                },
              ),
            );
          }

          final category = LostFoundCategory.values[index - 1];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(_formatCategoryName(category)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = selected ? category : null);
                _loadItems();
              },
            ),
          );
        },
      ),
    );
  }

  String _formatCategoryName(LostFoundCategory category) {
    if (category == LostFoundCategory.idsCards) return 'IDs & Cards';
    final name = category.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  Widget _buildItemList() {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        100, // Bottom padding for FAB
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return LostFoundCard(
          item: _items[index],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    LostFoundDetailsPage(itemId: _items[index].id),
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
      itemBuilder: (context, index) =>
          const ShimmerClubCard(), // Reusing ShimmerClubCard as it matches the grid layout
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No items found',
            style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try changing your filters or browse all items',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _searchQuery = '';
                _searchController.clear();
              });
              _loadItems();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Failed to load items', style: AppTextStyles.h5),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => _loadItems(forceRefresh: true),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
