import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/custom_app_bar.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/models/classroom.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';

class ClassroomPage extends StatefulWidget {
  final String userRole;
  const ClassroomPage({super.key, this.userRole = 'student'});

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
    // Teacher gets their own dashboard
    if (widget.userRole == 'teacher') {
      return const _TeacherClassroomPage();
    }

    // Other non-student roles get a restricted message
    if (widget.userRole != 'student') {
      return _buildRoleRestrictedView();
    }

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
      appBar: const CustomAppBar(title: 'Classroom'),
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
        child: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildStatsGrid(),
              _buildTabBar(),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
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
      itemBuilder: (context, index) => _AssignmentCard(
        assignment: assignments[index],
        index: index,
        onRefresh: () => _loadData(forceRefresh: true),
      ),
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

  Widget _buildRoleRestrictedView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleLabel = widget.userRole == 'teacher'
        ? 'Teacher'
        : widget.userRole == 'notice manager'
        ? 'Notice Manager'
        : widget.userRole;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Classroom'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: 56,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Students Only',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The Classroom feature is available for students only. Your current role ($roleLabel) does not have access to assignments and subjects.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
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
  final VoidCallback? onRefresh;

  const _AssignmentCard({
    required this.assignment,
    required this.index,
    this.onRefresh,
  });

  @override
  State<_AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<_AssignmentCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expansionController;
  late Animation<double> _animation;

  PlatformFile? _selectedFile;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResubmitting = false;

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
    _commentController.dispose();
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
        haptics.mediumImpact();
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick file')));
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedFile == null) return;

    setState(() => _isSubmitting = true);
    haptics.mediumImpact();

    try {
      final apiService = ApiService();
      final result = await apiService.submitAssignment(
        widget.assignment.id,
        _selectedFile!,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          haptics.success();
          widget.onRefresh?.call();
          setState(() {
            _isResubmitting = false;
            _selectedFile = null;
            _commentController.clear();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Submission failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
                      if (!isSubmitted || _isResubmitting)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isResubmitting)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: Text(
                                  "Resubmitting work...",
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (_selectedFile != null) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: AppRadius.mdAll,
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.insert_drive_file_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedFile!.name,
                                            style: AppTextStyles.labelMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB",
                                            style: AppTextStyles.caption,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          setState(() => _selectedFile = null),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                      ),
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                controller: _commentController,
                                decoration: AppDecorations.input(
                                  hint: "Add a comment (optional)",
                                  prefixIcon: Icons.chat_bubble_outline_rounded,
                                ),
                                style: AppTextStyles.bodyMedium,
                                maxLines: 2,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : (_selectedFile == null
                                          ? _pickFile
                                          : _submit),
                                icon: Icon(
                                  _isSubmitting
                                      ? Icons.hourglass_empty_rounded
                                      : (_selectedFile == null
                                            ? Icons.upload_file_rounded
                                            : Icons.send_rounded),
                                  size: 18,
                                ),
                                label: Text(
                                  _isSubmitting
                                      ? "Submitting..."
                                      : (_selectedFile == null
                                            ? "Select Work File"
                                            : "Turn In Work"),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _selectedFile != null
                                      ? Colors.green
                                      : AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (_isResubmitting)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.md,
                                ),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isResubmitting = false;
                                        _selectedFile = null;
                                        _commentController.clear();
                                      });
                                    },
                                    child: const Text("Cancel"),
                                  ),
                                ),
                              ),
                          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.green,
                      ),
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
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton.icon(
            onPressed: () {
              haptics.mediumImpact();
              setState(() {
                _isResubmitting = true;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text("Resubmit Work"),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// TEACHER CLASSROOM DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherClassroomPage extends StatefulWidget {
  const _TeacherClassroomPage();

  @override
  State<_TeacherClassroomPage> createState() => _TeacherClassroomPageState();
}

class _TeacherClassroomPageState extends State<_TeacherClassroomPage> {
  final ApiService _apiService = ApiService();

  // Data
  List<Subject> _teacherSubjects = [];
  List<Faculty> _faculties = [];
  List<Subject> _availableSubjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Submissions per assignment (expanded view)
  final Map<int, List<TeacherSubmission>> _submissionsMap = {};
  final Map<int, bool> _submissionsLoading = {};

  // Create Assignment form
  int? _selectedSubjectId;
  String _assignmentType = 'classwork';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime? _dueAt;
  bool _isCreating = false;
  String? _createError;

  // Add Subject form
  Faculty? _selectedFaculty;
  int _selectedSemester = 1;
  int? _selectedAvailableSubjectId;
  bool _isAddingSubject = false;
  String? _addSubjectError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _apiService.getTeacherSubjects(forceRefresh: forceRefresh),
        _apiService.getFaculties(),
      ]);
      if (mounted) {
        setState(() {
          _teacherSubjects = results[0] as List<Subject>;
          _faculties = results[1] as List<Faculty>;
          if (_teacherSubjects.isNotEmpty && _selectedSubjectId == null) {
            _selectedSubjectId = _teacherSubjects.first.id;
          }
          _isLoading = false;
        });
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

  Future<void> _loadAvailableSubjects() async {
    if (_selectedFaculty == null) return;
    final subjects = await _apiService.getSubjectsByFaculty(
      _selectedFaculty!.id,
      semester: _selectedSemester,
    );
    if (mounted) {
      setState(() {
        _availableSubjects = subjects;
        _selectedAvailableSubjectId = subjects.isNotEmpty
            ? subjects.first.id
            : null;
      });
    }
  }

  Future<void> _toggleSubmissions(int assignmentId) async {
    if (_submissionsMap.containsKey(assignmentId)) {
      setState(() => _submissionsMap.remove(assignmentId));
      return;
    }
    setState(() => _submissionsLoading[assignmentId] = true);
    final subs = await _apiService.getAssignmentSubmissions(assignmentId);
    if (mounted) {
      setState(() {
        _submissionsMap[assignmentId] = subs;
        _submissionsLoading.remove(assignmentId);
      });
    }
  }

  Future<void> _createAssignment() async {
    if (_selectedSubjectId == null || _titleController.text.trim().isEmpty) {
      setState(() => _createError = 'Please fill in all required fields.');
      return;
    }
    setState(() {
      _isCreating = true;
      _createError = null;
    });
    haptics.mediumImpact();
    final result = await _apiService.createAssignment(
      subjectId: _selectedSubjectId!,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      type: _assignmentType,
      dueAt: _dueAt,
    );
    if (mounted) {
      setState(() => _isCreating = false);
      if (result['success'] == true) {
        haptics.success();
        _titleController.clear();
        _descController.clear();
        setState(() => _dueAt = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment published!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(forceRefresh: true);
      } else {
        setState(() => _createError = result['message'] ?? 'Failed to create');
      }
    }
  }

  Future<void> _addSubject() async {
    if (_selectedAvailableSubjectId == null) return;
    setState(() {
      _isAddingSubject = true;
      _addSubjectError = null;
    });
    haptics.mediumImpact();
    final result = await _apiService.addTeacherSubject(
      _selectedAvailableSubjectId!,
    );
    if (mounted) {
      setState(() => _isAddingSubject = false);
      if (result['success'] == true) {
        haptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject added!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(forceRefresh: true);
      } else {
        setState(() => _addSubjectError = result['message'] ?? 'Failed to add');
      }
    }
  }

  // ── Stats ────────────────────────────────────────────────────────────────

  int get _subjectCount => _teacherSubjects.length;
  int get _taskCount =>
      _teacherSubjects.fold(0, (s, sub) => s + (sub.assignments?.length ?? 0));
  int get _classworkCount => _teacherSubjects.fold(
    0,
    (s, sub) =>
        s + (sub.assignments?.where((a) => a.type == 'classwork').length ?? 0),
  );
  int get _homeworkCount => _teacherSubjects.fold(
    0,
    (s, sub) =>
        s + (sub.assignments?.where((a) => a.type == 'homework').length ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Classroom'),
        body: ShimmerWrapper(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.base),
            children: [
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.2,
                children: List.generate(
                  4,
                  (_) => const Skeleton(borderRadius: AppRadius.md),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              const Skeleton(height: 220, borderRadius: AppRadius.lg),
              const SizedBox(height: AppSpacing.md),
              const Skeleton(height: 180, borderRadius: AppRadius.lg),
            ],
          ),
        ),
      );
    }

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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Classroom'),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.base,
            100,
          ),
          children: [
            // ── Teacher badge ──
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TEACHER',
                      style: AppTextStyles.overline.copyWith(
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),

            // ── Stats Grid ──
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.9,
              children: [
                _buildTeacherStatCard(
                  'Subjects',
                  '$_subjectCount',
                  const Color(0xFF3B82F6),
                ),
                _buildTeacherStatCard(
                  'Tasks',
                  '$_taskCount',
                  const Color(0xFF6366F1),
                ),
                _buildTeacherStatCard(
                  'Classwork',
                  '$_classworkCount',
                  const Color(0xFF8B5CF6),
                ),
                _buildTeacherStatCard(
                  'Homework',
                  '$_homeworkCount',
                  const Color(0xFF10B981),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),

            // ── Create Assignment Card ──
            _buildSectionCard(
              isDark: isDark,
              title: 'Create Assignment',
              subtitle: 'Post new work for students',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_createError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smAll,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _createError!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  if (_teacherSubjects.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text(
                        'Add a subject first.',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),

                  // Subject dropdown
                  _buildLabel('Subject'),
                  _buildDropdown<int?>(
                    value: _selectedSubjectId,
                    hint: _teacherSubjects.isEmpty ? 'None' : 'Select',
                    items: _teacherSubjects
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSubjectId = v),
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Type + Due Date row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Type'),
                            _buildDropdown<String>(
                              value: _assignmentType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'classwork',
                                  child: Text('Classwork'),
                                ),
                                DropdownMenuItem(
                                  value: 'homework',
                                  child: Text('Homework'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _assignmentType = v!),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Due Date'),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                    const Duration(days: 7),
                                  ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null && mounted) {
                                  setState(() => _dueAt = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.grey[50],
                                  borderRadius: AppRadius.smAll,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  _dueAt != null
                                      ? '${_dueAt!.day}/${_dueAt!.month}/${_dueAt!.year}'
                                      : 'Optional',
                                  style: AppTextStyles.caption.copyWith(
                                    color: _dueAt != null ? null : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Title
                  _buildLabel('Title *'),
                  _buildTextField(
                    controller: _titleController,
                    hint: 'Lab Report 1',
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Description
                  _buildLabel('Description'),
                  _buildTextField(
                    controller: _descController,
                    hint: 'Instructions...',
                    maxLines: 2,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Publish button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating || _teacherSubjects.isEmpty
                          ? null
                          : _createAssignment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.smAll,
                        ),
                      ),
                      child: Text(
                        _isCreating ? 'Publishing...' : 'Publish',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Add Subject Card ──
            _buildSectionCard(
              isDark: isDark,
              title: 'Add Subject',
              subtitle: 'Assign yourself to teach',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_addSubjectError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smAll,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _addSubjectError!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),

                  // Faculty
                  _buildLabel('Faculty'),
                  _buildDropdown<Faculty?>(
                    value: _selectedFaculty,
                    hint: 'Select',
                    items: _faculties
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (f) {
                      setState(() {
                        _selectedFaculty = f;
                        _selectedSemester = 1;
                        _availableSubjects = [];
                        _selectedAvailableSubjectId = null;
                      });
                      _loadAvailableSubjects();
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Semester
                  _buildLabel('Semester'),
                  _buildDropdown<int>(
                    value: _selectedSemester,
                    hint: 'Select',
                    items: List.generate(
                      _selectedFaculty?.semestersCount ?? 8,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('Semester ${i + 1}'),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _selectedSemester = v!;
                        _availableSubjects = [];
                        _selectedAvailableSubjectId = null;
                      });
                      _loadAvailableSubjects();
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Subject
                  _buildLabel('Subject'),
                  _buildDropdown<int?>(
                    value: _selectedAvailableSubjectId,
                    hint: _availableSubjects.isEmpty
                        ? 'Choose context first'
                        : 'Select',
                    items: _availableSubjects
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedAvailableSubjectId = v),
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isAddingSubject ||
                              _selectedAvailableSubjectId == null
                          ? null
                          : _addSubject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.smAll,
                        ),
                      ),
                      child: Text(
                        _isAddingSubject ? 'Adding...' : 'Add Subject',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),

            // ── Managed Subjects ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Managed Subjects',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    '$_subjectCount Total',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            if (_teacherSubjects.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 40,
                      color: Colors.grey.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No subjects assigned',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Use "Add Subject" to get started.',
                      style: AppTextStyles.caption.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ...(_teacherSubjects.map(
                (subject) => _buildSubjectCard(subject, isDark),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherStatCard(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.h4.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.overline.copyWith(
              color: Colors.grey,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Subject subject, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
      child: Column(
        children: [
          // Subject header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.title,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${subject.code ?? 'NO-CODE'} • Semester ${subject.semesterNumber}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    '${subject.assignments?.length ?? 0} tasks',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Assignments list
          if (subject.assignments != null && subject.assignments!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: subject.assignments!.map((assignment) {
                  final isLoading = _submissionsLoading[assignment.id] == true;
                  final submissions = _submissionsMap[assignment.id];
                  final isExpanded = submissions != null;
                  final isClasswork = assignment.type == 'classwork';

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: isExpanded
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isClasswork
                                    ? const Color(
                                        0xFF3B82F6,
                                      ).withValues(alpha: 0.1)
                                    : const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.1),
                                borderRadius: AppRadius.xsAll,
                                border: Border.all(
                                  color: isClasswork
                                      ? const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.3)
                                      : const Color(
                                          0xFF8B5CF6,
                                        ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                assignment.type.toUpperCase(),
                                style: AppTextStyles.overline.copyWith(
                                  color: isClasswork
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (assignment.dueAt != null)
                              Text(
                                'Due ${_formatShortDate(assignment.dueAt!)}',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _toggleSubmissions(assignment.id),
                              child: Text(
                                isLoading
                                    ? 'Loading...'
                                    : isExpanded
                                    ? 'Hide'
                                    : 'View',
                                style: AppTextStyles.caption.copyWith(
                                  color: const Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignment.title,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        // Submissions list
                        if (isExpanded) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.sm),
                          if (submissions.isEmpty)
                            Text(
                              'No submissions yet.',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            ...submissions.map(
                              (sub) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (sub.studentName?.isNotEmpty == true
                                                  ? sub.studentName![0]
                                                  : 'S')
                                              .toUpperCase(),
                                          style: AppTextStyles.caption.copyWith(
                                            color: const Color(0xFF3B82F6),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sub.studentName ?? sub.studentId,
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          Text(
                                            _formatShortDate(sub.submittedAt),
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: Colors.grey,
                                                  fontSize: 9,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (sub.fileUrl.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          // TODO: open file URL
                                        },
                                        child: Text(
                                          'View',
                                          style: AppTextStyles.caption.copyWith(
                                            color: const Color(0xFF3B82F6),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.overline.copyWith(
          color: Colors.grey,
          fontWeight: FontWeight.w600,
          fontSize: 9,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    String? hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.any((item) => item.value == value) ? value : null,
          hint: hint != null
              ? Text(
                  hint,
                  style: AppTextStyles.caption.copyWith(color: Colors.grey),
                )
              : null,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: AppTextStyles.caption,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.caption,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.caption.copyWith(color: Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
