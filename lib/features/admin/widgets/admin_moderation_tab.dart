import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';

class AdminModerationTab extends StatefulWidget {
  const AdminModerationTab({super.key});

  @override
  State<AdminModerationTab> createState() => _AdminModerationTabState();
}

class _AdminModerationTabState extends State<AdminModerationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<MarketplaceReport> _reports = [];
  bool _isLoading = true;
  String _selectedStatus = 'open';

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    final reports = await ApiService().getModerationReports(
      status: _selectedStatus,
    );
    setState(() {
      _reports = reports;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(MarketplaceReport report, String status) async {
    final TextEditingController reasonController = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Report to ${status.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add resolution notes (optional):'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for this action...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'resolved'
                  ? AppColors.success
                  : (status == 'rejected'
                        ? AppColors.error
                        : AppColors.primary),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      final result = await ApiService().updateModerationReport(
        report.id,
        status: status,
        resolutionNotes: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );

      if (result.success) {
        _fetchReports();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to update report')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'open',
                label: Text('Open'),
                icon: Icon(Icons.error_outline),
              ),
              ButtonSegment(
                value: 'in_review',
                label: Text('Reviewing'),
                icon: Icon(Icons.pending_outlined),
              ),
              ButtonSegment(
                value: 'resolved',
                label: Text('Resolved'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {_selectedStatus},
            onSelectionChanged: (newSelection) {
              setState(() => _selectedStatus = newSelection.first);
              _fetchReports();
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const ShimmerAdminModeration()
              : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 64,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No reports found with status: $_selectedStatus',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 100,
                  ),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return _buildReportCard(report);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportCard(MarketplaceReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.borderDark
              : AppColors.borderLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        report.category,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      report.category.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(report.category),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, h:mm a').format(report.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(report.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_pin_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Reported: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      report.reportedUser?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'By: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      report.reporter?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (report.listing != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.book_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Listing: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      report.listing!.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (report.resolutionNotes != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surfaceContainerDark
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resolution Notes:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.resolutionNotes!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            if (report.status == ReportStatus.open ||
                report.status == ReportStatus.inReview) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (report.status == ReportStatus.open) ...[
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _updateStatus(report, 'in_review'),
                        icon: const Icon(Icons.pending_outlined, size: 16),
                        label: const Text(
                          'Review',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _updateStatus(report, 'rejected'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text(
                        'Reject',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(report, 'resolved'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text(
                        'Resolve',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Color _getCategoryColor(ReportCategory category) {
    switch (category) {
      case ReportCategory.spam:
        return Colors.blue;
      case ReportCategory.fraud:
        return AppColors.warning;
      case ReportCategory.abusive:
        return AppColors.error;
      case ReportCategory.fakeListing:
        return Colors.amber;
      case ReportCategory.suspiciousPayment:
        return Colors.purple;
      case ReportCategory.other:
        return AppColors.textMuted;
    }
  }
}

class ShimmerAdminModeration extends StatelessWidget {
  const ShimmerAdminModeration({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceContainerDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: ShimmerWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Skeleton(height: 18, width: 80, borderRadius: 6),
                    Skeleton(height: 14, width: 100, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 12),
                Skeleton(height: 14, width: double.infinity, borderRadius: 4),
                const SizedBox(height: 6),
                Skeleton(height: 14, width: 200, borderRadius: 4),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Skeleton(height: 12, width: 100, borderRadius: 4),
                    const SizedBox(width: 8),
                    Skeleton(height: 12, width: 80, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Skeleton(height: 36, borderRadius: 8)),
                    const SizedBox(width: 8),
                    Expanded(child: Skeleton(height: 36, borderRadius: 8)),
                    const SizedBox(width: 8),
                    Expanded(child: Skeleton(height: 36, borderRadius: 8)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
