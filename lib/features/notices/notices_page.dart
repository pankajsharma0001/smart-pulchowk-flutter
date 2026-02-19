import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/models/notice.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/core/widgets/staggered_scale_fade.dart';
import 'package:smart_pulchowk/core/widgets/pdf_viewer.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:smart_pulchowk/features/notices/notice_editor.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 15;

  List<Notice> _notices = [];
  NoticeStats? _stats;
  String? _selectedCategory;
  String _userRole = 'student';

  final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'value': null, 'icon': Icons.all_inclusive_rounded},
    {'label': 'Results', 'value': 'results', 'icon': Icons.assignment_rounded},
    {
      'label': 'Forms',
      'value': 'application_forms',
      'icon': Icons.description_rounded,
    },
    {
      'label': 'Centers',
      'value': 'exam_centers',
      'icon': Icons.location_on_rounded,
    },
    {'label': 'General', 'value': 'general', 'icon': Icons.info_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData();
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _offset = 0;
      _hasMore = true;
    });

    try {
      final results = await Future.wait([
        _api.getNotices(
          category: _selectedCategory,
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          limit: _limit,
          offset: 0,
          forceRefresh: forceRefresh,
        ),
        _api.getNoticeStats(forceRefresh: forceRefresh),
      ]);

      if (mounted) {
        final role = await _api.getUserRole();
        setState(() {
          _notices = results[0] as List<Notice>;
          _stats = results[1] as NoticeStats?;
          _userRole = role;
          _isLoading = false;
          _offset = _notices.length;
          _hasMore = _notices.length >= _limit;
        });
      }
    } catch (e) {
      debugPrint('Error loading notices: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final newNotices = await _api.getNotices(
        category: _selectedCategory,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        limit: _limit,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _notices.addAll(newNotices);
          _offset += newNotices.length;
          _isLoadingMore = false;
          _hasMore = newNotices.length >= _limit;
        });
      }
    } catch (e) {
      debugPrint('Error loading more notices: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _openNoticeEditor({Notice? notice}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      showDragHandle: true,
      builder: (_) => NoticeEditor(notice: notice),
    );

    if (result == true) {
      _loadData(forceRefresh: true);
    }
  }

  Future<void> _deleteNotice(Notice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice?'),
        content: const Text(
          'Are you sure you want to permanently delete this notice?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      haptics.heavyImpact();
      final result = await _api.deleteNotice(notice.id);
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Notice deleted')));
          _loadData(forceRefresh: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Failed to delete notice')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Notices',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w900),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: const [SizedBox(width: AppSpacing.md)],
        ),
        body: Column(
          children: [
            _buildSearchBar(isDark),
            _buildFilters(isDark),
            if (_stats != null && _stats!.newCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_stats!.newCount} new notices in the last 7 days',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _loadData(forceRefresh: true),
                    _api.refreshUserRole(),
                  ]);
                },
                color: AppColors.primary,
                child: _isLoading ? _buildLoading() : _buildContent(isDark),
              ),
            ),
          ],
        ),
        floatingActionButton: _userRole == 'notice_manager'
            ? AnimatedScale(
                scale: isKeyboardOpen ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: isKeyboardOpen ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 80),
                    child: FloatingActionButton.extended(
                      onPressed: isKeyboardOpen
                          ? null
                          : () => _openNoticeEditor(),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'Add Notice',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search notices...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _loadData();
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Column(
      children: [
        // Categories horizontal scroll
        SizedBox(
          height: 44,
          child: ListView.builder(
            controller: _categoryScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat['value'];

              // Determine count
              String countSuffix = '';
              if (_stats != null) {
                if (cat['value'] == null && _stats!.total > 0) {
                  countSuffix = ' (${_stats!.total})';
                } else if (cat['value'] == 'results' && _stats!.results > 0) {
                  countSuffix = ' (${_stats!.results})';
                } else if (cat['value'] == 'application_forms' &&
                    _stats!.applicationForms > 0) {
                  countSuffix = ' (${_stats!.applicationForms})';
                } else if (cat['value'] == 'exam_centers' &&
                    _stats!.examCenters > 0) {
                  countSuffix = ' (${_stats!.examCenters})';
                } else if (cat['value'] == 'general' && _stats!.general > 0) {
                  countSuffix = ' (${_stats!.general})';
                }
              }

              return Builder(
                builder: (BuildContext itemContext) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('${cat['label']}$countSuffix'),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          haptics.selectionClick();
                          setState(() {
                            _selectedCategory = cat['value'];
                          });
                          _loadData();

                          // Auto-scroll to ensure the chip is visible
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (itemContext.mounted) {
                              Scrollable.ensureVisible(
                                itemContext,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                alignment: 0.5,
                              );
                            }
                          });
                        }
                      },
                      avatar: Icon(
                        cat['icon'],
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      labelStyle: AppTextStyles.labelSmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: BorderSide.none,
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: _NoticeSkeleton(),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_notices.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_off_rounded,
                  size: 64,
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No notices found',
                  style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Try changing your filters or refresh.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _notices.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _notices.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final notice = _notices[index];
        return StaggeredScaleFade(
          key: ValueKey('notice_${notice.id}'),
          index: index,
          child: _NoticeCard(
            notice: notice,
            isDark: isDark,
            userRole: _userRole,
            onEdit: () => _openNoticeEditor(notice: notice),
            onDelete: () => _deleteNotice(notice),
          ),
        );
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  final bool isDark;
  final String userRole;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoticeCard({
    required this.notice,
    required this.isDark,
    required this.userRole,
    required this.onEdit,
    required this.onDelete,
  });

  void _handleAttachmentView(BuildContext context) {
    if (notice.attachmentUrl == null || notice.attachmentUrl!.isEmpty) return;

    haptics.lightImpact();

    if (notice.isPdf) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) =>
              CustomPdfViewer(url: notice.attachmentUrl!, title: notice.title),
        ),
      );
    } else if (notice.isImage) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) =>
              FullScreenImageViewer(imageUrls: [notice.attachmentUrl!]),
        ),
      );
    } else {
      // Fallback for unknown file types
      _launchExternalUrl(notice.attachmentUrl);
    }
  }

  Future<void> _launchExternalUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url.trim());
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMMd().format(notice.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleAttachmentView(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: notice.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(notice.icon, size: 20, color: notice.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                notice.categoryDisplay,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: notice.color,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (notice.isNew) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            date,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notice.level != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notice.level!.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notice.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                if (notice.attachmentUrl != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildActionButton(
                        context,
                        icon: notice.isPdf
                            ? Icons.picture_as_pdf_rounded
                            : (notice.isImage
                                  ? Icons.image_rounded
                                  : Icons.description_rounded),
                        label:
                            'View Attachment ${notice.isPdf ? "[PDF]" : (notice.isImage ? "[IMG]" : "")}',
                        onTap: () => _handleAttachmentView(context),
                        isPrimary: true,
                      ),
                      if (notice.sourceUrl != null) ...[
                        const SizedBox(width: 8),
                        _buildActionButton(
                          context,
                          icon: Icons.launch_rounded,
                          label: 'Source',
                          onTap: () => _launchExternalUrl(notice.sourceUrl),
                        ),
                      ],
                    ],
                  ),
                ],
                if (userRole == 'notice_manager') ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          haptics.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPrimary
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : (isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isPrimary ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isPrimary ? AppColors.primary : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeSkeleton extends StatelessWidget {
  const _NoticeSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: const ShimmerWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton(height: 36, width: 36, borderRadius: 10),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 12, width: 60, borderRadius: 4),
                    SizedBox(height: 6),
                    Skeleton(height: 8, width: 80, borderRadius: 4),
                  ],
                ),
                Spacer(),
                Skeleton(height: 18, width: 40, borderRadius: 6),
              ],
            ),
            SizedBox(height: 16),
            Skeleton(height: 16, width: double.infinity, borderRadius: 4),
            SizedBox(height: 8),
            Skeleton(height: 16, width: 150, borderRadius: 4),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Skeleton(height: 36, borderRadius: 10)),
                SizedBox(width: 8),
                Expanded(child: Skeleton(height: 36, borderRadius: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
