import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/models/notice.dart';
import 'package:smart_pulchowk/core/models/search_result.dart';
import 'package:smart_pulchowk/core/services/global_search_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/features/events/event_details_page.dart';
import 'package:smart_pulchowk/features/lost_found/lost_found_details_page.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';
import 'package:smart_pulchowk/core/widgets/pdf_viewer.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:smart_pulchowk/features/map/map_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalSearchService _searchService = GlobalSearchService();
  Timer? _debounce;

  List<SearchResult> _allResults = [];
  bool _isLoading = false;
  String? _lastQuery;
  late TabController _tabController;

  static const List<String> _tabs = [
    'All',
    'Notices',
    'Marketplace',
    'Events',
    'Lost & Found',
    'Map',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query == _lastQuery) return;
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _allResults = [];
          _isLoading = false;
          _lastQuery = query;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await _searchService.searchAll(query);
      if (mounted) {
        setState(() {
          _allResults = results;
          _isLoading = false;
          _lastQuery = query;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SearchResult> _getFilteredResults(int tabIndex) {
    if (tabIndex == 0) return _allResults;
    final type = _getTypeFromTabIndex(tabIndex);
    return _allResults.where((r) => r.type == type).toList();
  }

  SearchResultType? _getTypeFromTabIndex(int index) {
    switch (index) {
      case 1:
        return SearchResultType.notice;
      case 2:
        return SearchResultType.book;
      case 3:
        return SearchResultType.event;
      case 4:
        return SearchResultType.lostFound;
      case 5:
        return SearchResultType.location;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TapRegion(
      onTapOutside: (_) => _searchFocusNode.unfocus(),
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: BackButton(color: isDark ? Colors.white : Colors.black),
          title: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Search anything...',
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          actions: [
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelStyle: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AppTextStyles.labelLarge,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: List.generate(
            _tabs.length,
            (index) => _buildResultList(index, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildResultList(int tabIndex, bool isDark) {
    if (_isLoading) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => const ShimmerWrapper(
          child: Skeleton(height: 80, width: double.infinity, borderRadius: 16),
        ),
      );
    }

    final results = _getFilteredResults(tabIndex);

    if (results.isEmpty) {
      if (_searchController.text.isEmpty) {
        return _buildEmptyState(
          icon: Icons.search_rounded,
          title: 'Start Searching',
          subtitle:
              'Search for notices, events, books, and more across Pulchowk Campus.',
          isDark: isDark,
        );
      }
      return _buildEmptyState(
        icon: Icons.sentiment_dissatisfied_rounded,
        title: 'No results found',
        subtitle:
            'We couldn\'t find anything matching "${_searchController.text}".',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final result = results[index];
        return _ResultCard(result: result, isDark: isDark);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.h4.copyWith(
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SearchResult result;
  final bool isDark;

  const _ResultCard({required this.result, required this.isDark});

  void _onTap(BuildContext context) {
    switch (result.type) {
      case SearchResultType.notice:
        final notice = result.originalObject as Notice;
        if (notice.attachmentUrl != null) {
          if (notice.isPdf) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomPdfViewer(
                  url: notice.attachmentUrl!,
                  title: notice.title,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FullScreenImageViewer(imageUrls: [notice.attachmentUrl!]),
              ),
            );
          }
        }
        break;
      case SearchResultType.event:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EventDetailsPage(event: result.originalObject as ClubEvent),
          ),
        );
        break;
      case SearchResultType.book:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                BookDetailsPage(listing: result.originalObject as BookListing),
          ),
        );
        break;
      case SearchResultType.lostFound:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LostFoundDetailsPage(
              itemId: (result.originalObject as LostFoundItem).id,
            ),
          ),
        );
        break;
      case SearchResultType.location:
        // For locations, we pop and somehow tell the MapPage to show this location
        // For now, let's just go to MapPage (placeholder logic)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MapPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _onTap(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Leading Icon or Image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: result.color.withValues(alpha: 0.12),
              ),
              child: result.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SmartImage(
                        imageUrl: result.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Icon(
                          result.icon,
                          color: result.color,
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(result.icon, color: result.color, size: 24),
            ),
            const SizedBox(width: 16),
            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: result.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          result.subtitle,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
