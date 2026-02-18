import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/custom_app_bar.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/models/classroom.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';

class ClassroomPage extends StatefulWidget {
  const ClassroomPage({super.key});

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  StudentProfile? _profile;
  List<Subject> _subjects = [];
  List<Assignment> _todoAssignments = [];
  List<Assignment> _doneAssignments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getMyClassroomSubjects(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        if (result['success'] == true) {
          final subjects = (result['subjects'] as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList();

          final allAssignments = <Assignment>[];
          for (final subject in subjects) {
            if (subject.assignments != null) {
              for (final assignment in subject.assignments!) {
                assignment.subjectTitle = subject.title;
                allAssignments.add(assignment);
              }
            }
          }

          setState(() {
            _profile = StudentProfile.fromJson(result['profile']);
            _subjects = subjects;
            _todoAssignments = allAssignments
                .where((a) => a.submission == null)
                .toList();
            _doneAssignments = allAssignments
                .where((a) => a.submission != null)
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage =
                result['message'] ?? 'Failed to load classroom data';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildShimmerBody();

    if (_errorMessage != null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Classroom'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => _loadData(forceRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Classroom',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              haptics.mediumImpact();
              _loadData(forceRefresh: true);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [AppColors.backgroundDark, AppColors.backgroundDark]
                : [AppColors.backgroundLight, Colors.white],
          ),
        ),
        child: Column(
          children: [
            _buildStatsGrid(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildAssignmentList(
                    _todoAssignments,
                    "No assignments to do! 🎉",
                    Icons.celebration_rounded,
                  ),
                  _buildAssignmentList(
                    _doneAssignments,
                    "No completed assignments yet.",
                    Icons.assignment_turned_in_rounded,
                  ),
                  _buildSubjectsGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final progress = _calculateSemesterProgress();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.2,
            children: [
              _buildStatCard(
                "Pending",
                "${_todoAssignments.length}",
                const Color(0xFF6366F1), // Indigo
                Icons.pending_actions_rounded,
              ),
              _buildStatCard(
                "Overdue",
                "${_todoAssignments.where((a) => a.isOverdue).length}",
                const Color(0xFFEF4444), // Red
                Icons.error_outline_rounded,
              ),
              _buildStatCard(
                "Completed",
                "${_doneAssignments.length}",
                const Color(0xFF10B981), // Emerald
                Icons.check_circle_outline_rounded,
              ),
              _buildProgressCard("Semester", progress),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: isDark
          ? AppDecorations.cardDark().copyWith(
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            )
          : AppDecorations.card().copyWith(
              color: color.withValues(alpha: 0.05),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTextStyles.h4.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String label, double progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: isDark ? AppDecorations.cardDark() : AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        borderRadius: AppRadius.lgAll,
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: AppRadius.mdAll,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelStyle: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w500,
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        onTap: (_) => haptics.lightImpact(),
        tabs: [
          Tab(text: "TO DO (${_todoAssignments.length})"),
          const Tab(text: "DONE"),
          const Tab(text: "SUBJECTS"),
        ],
      ),
    );
  }

  Widget _buildAssignmentList(
    List<Assignment> assignments,
    String emptyMessage,
    IconData emptyIcon,
  ) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                emptyIcon,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              emptyMessage,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        100, // Bottom padding for navbar
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: assignments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) =>
          _AssignmentCard(assignment: assignments[index], index: index),
    );
  }

  Widget _buildSubjectsGrid() {
    if (_subjects.isEmpty) return _buildEmptyState();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        100, // Bottom padding for navbar
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.2,
      ),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: isDark
              ? AppDecorations.cardDark().copyWith(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : AppDecorations.card().copyWith(
                  gradient: LinearGradient(
                    colors: [Colors.white, const Color(0xFFF1F5F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.xsAll,
                ),
                child: Text(
                  subject.code ?? "SUBJ",
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subject.title,
                style: AppTextStyles.labelLarge.copyWith(height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 14,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${subject.assignments?.length ?? 0} Tasks",
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  double _calculateSemesterProgress() {
    if (_profile == null || _profile!.semesterEndDate == null) return 0.0;
    final start = _profile!.semesterStartDate;
    final end = _profile!.semesterEndDate!;
    final now = DateTime.now();
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;
    final total = end.difference(start).inDays;
    final elapsed = now.difference(start).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No subjects found for this semester.',
        style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
      ),
    );
  }

  Widget _buildShimmerBody() {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Classroom'),
      body: ShimmerWrapper(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 2.2,
                children: List.generate(
                  4,
                  (_) => const Skeleton(borderRadius: AppRadius.md),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: Skeleton(height: 48, borderRadius: AppRadius.lg),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.base),
                itemCount: 5,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, _) =>
                    const Skeleton(height: 100, borderRadius: AppRadius.lg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatefulWidget {
  final Assignment assignment;
  final int index;
  const _AssignmentCard({required this.assignment, required this.index});

  @override
  State<_AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<_AssignmentCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expansionController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expansionController.forward();
      } else {
        _expansionController.reverse();
      }
    });
    haptics.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assignment = widget.assignment;
    final isSubmitted = assignment.submission != null;
    final statusColor = _getStatusColor(assignment);
    final statusText = _getStatusText(assignment);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleExpanded,
          borderRadius: AppRadius.lgAll,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                          Row(
                            children: [
                              _buildTypeBadge(assignment.type),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  assignment.subjectTitle ?? "Subject",
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            assignment.title,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(statusText, statusColor),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: assignment.isOverdue && !isSubmitted
                          ? AppColors.error
                          : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      assignment.dueAt != null
                          ? "Due ${_formatDate(assignment.dueAt!)}"
                          : "No Deadline",
                      style: AppTextStyles.caption.copyWith(
                        color: assignment.isOverdue && !isSubmitted
                            ? AppColors.error
                            : Colors.grey,
                        fontWeight: assignment.isOverdue && !isSubmitted
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.grey,
                    ),
                  ],
                ),
                SizeTransition(
                  sizeFactor: _animation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Divider(),
                      ),
                      Text(
                        "Instructions",
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.description ?? "No description provided.",
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (!isSubmitted)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              haptics.mediumImpact();
                              // TODO: Implement Submission
                            },
                            icon: const Icon(
                              Icons.upload_file_rounded,
                              size: 18,
                            ),
                            label: const Text("Turn In Work"),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        )
                      else
                        _buildSubmissionInfo(assignment.submission!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final isHW = type == "homework";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isHW ? Colors.orange : Colors.blue).withValues(alpha: 0.1),
        borderRadius: AppRadius.xsAll,
      ),
      child: Text(
        isHW ? "HOMEWORK" : "CLASSWORK",
        style: AppTextStyles.overline.copyWith(
          color: isHW ? Colors.orange : Colors.blue,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        text,
        style: AppTextStyles.overline.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSubmissionInfo(Submission submission) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.done_all_rounded,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Work Submitted",
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.green),
                ),
                Text(
                  "Done on ${_formatDate(submission.submittedAt)}",
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.green.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: AppRadius.xsAll,
            ),
            child: Text(
              submission.status.toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(Assignment a) {
    if (a.submission != null) return Colors.green;
    if (a.dueAt == null) return Colors.blue;
    if (a.isOverdue) return Colors.red;
    if (a.isDueSoon) return Colors.orange;
    return AppColors.primary;
  }

  String _getStatusText(Assignment a) {
    if (a.submission != null) return "COMPLETED";
    if (a.dueAt == null) return "PENDING";
    if (a.isOverdue) return "OVERDUE";
    if (a.isDueSoon) return "DUE SOON";
    return "PENDING";
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.inDays == 0) {
      return "Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    if (diff.inDays == 1) {
      return "Tomorrow";
    }

    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${date.day} ${months[date.month - 1]}";
  }
}
