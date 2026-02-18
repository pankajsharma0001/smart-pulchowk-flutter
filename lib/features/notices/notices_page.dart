import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/models/notice.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Notice> _notices = [];
  NoticeStats? _stats;

  String? _selectedCategory;
  String _selectedLevel = 'be'; // Default to Bachelor

  final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'value': null, 'icon': Icons.all_inclusive_rounded},
    {
      'label': 'Routines',
      'value': 'routines',
      'icon': Icons.calendar_today_rounded,
    },
    {'label': 'Results', 'value': 'results', 'icon': Icons.grading_rounded},
    {
      'label': 'Forms',
      'value': 'application_forms',
      'icon': Icons.assignment_rounded,
    },
    {
      'label': 'Exam Centers',
      'value': 'exam_centers',
      'icon': Icons.place_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getNotices(
          category: _selectedCategory,
          level: _selectedLevel,
          forceRefresh: forceRefresh,
        ),
        _api.getNoticeStats(forceRefresh: forceRefresh),
      ]);

      if (mounted) {
        setState(() {
          _notices = results[0] as List<Notice>;
          _stats = results[1] as NoticeStats?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notices: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Notices',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadData(forceRefresh: true),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(isDark),
          if (_stats != null && _stats!.newCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              onRefresh: () => _loadData(forceRefresh: true),
              color: AppColors.primary,
              child: _isLoading ? _buildLoading() : _buildContent(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Column(
      children: [
        // Level Switch (BE / MSc)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildLevelChip('BE', 'be', isDark),
              const SizedBox(width: 8),
              _buildLevelChip('MSc', 'msc', isDark),
            ],
          ),
        ),
        // Categories horizontal scroll
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat['value'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(cat['label']),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      haptics.selectionClick();
                      setState(() {
                        _selectedCategory = cat['value'];
                      });
                      _loadData();
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
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide.none,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLevelChip(String label, String value, bool isDark) {
    final isSelected = _selectedLevel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            haptics.selectionClick();
            setState(() => _selectedLevel = value);
            _loadData();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: ShimmerWrapper(
          child: Skeleton(
            height: 120,
            width: double.infinity,
            borderRadius: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_notices.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _notices.length,
      itemBuilder: (context, index) {
        final notice = _notices[index];
        return _NoticeCard(notice: notice, isDark: isDark);
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  final bool isDark;

  const _NoticeCard({required this.notice, required this.isDark});

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          onTap: () => _handleTap(context),
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
                          Text(
                            notice.categoryDisplay,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: notice.color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
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
                        icon: Icons.description_rounded,
                        label: 'View Attachment',
                        onTap: () => _launchUrl(notice.attachmentUrl),
                        isPrimary: true,
                      ),
                      if (notice.sourceUrl != null) ...[
                        const SizedBox(width: 8),
                        _buildActionButton(
                          context,
                          icon: Icons.launch_rounded,
                          label: 'Source',
                          onTap: () => _launchUrl(notice.sourceUrl),
                        ),
                      ],
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
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isPrimary ? AppColors.primary : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    haptics.lightImpact();
    if (notice.attachmentUrl != null) {
      _launchUrl(notice.attachmentUrl);
    } else if (notice.sourceUrl != null) {
      _launchUrl(notice.sourceUrl);
    }
  }
}
