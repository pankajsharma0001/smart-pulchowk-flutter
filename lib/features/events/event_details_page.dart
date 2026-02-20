import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/features/events/widgets/event_status_badge.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_pulchowk/features/clubs/club_details_page.dart';
import 'package:smart_pulchowk/features/events/widgets/event_editor.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/services/calendar_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';

class EventDetailsPage extends StatefulWidget {
  final ClubEvent event;

  const EventDetailsPage({super.key, required this.event});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final ApiService _apiService = ApiService();
  bool _isRegistering = false;
  bool _isEnrolled = false;
  bool _isLoadingEnrollment = true;
  bool _isAdmin = false;
  Map<String, dynamic>? _extraDetails;
  bool _isLoadingExtraDetails = true;
  List<RegisteredStudent> _registeredStudents = [];
  bool _isLoadingStudents = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();

    // Instant Load Enrollment from Cache
    final cachedEnrollment = _apiService.getCachedEnrollment();
    if (cachedEnrollment != null) {
      _isEnrolled = cachedEnrollment.any((e) => e.eventId == widget.event.id);
      _isLoadingEnrollment = false;
    }

    _checkEnrollment();
    _checkAdminStatus();
    _loadExtraDetails();
  }

  Future<void> _checkEnrollment() async {
    try {
      final enrollment = await _apiService.getStudentEnrollment();
      if (mounted) {
        setState(() {
          _isEnrolled = enrollment.any((e) => e.eventId == widget.event.id);
          _isLoadingEnrollment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEnrollment = false);
      }
    }
  }

  Future<void> _checkAdminStatus() async {
    try {
      final dbUserId = await StorageService.readSecure(
        AppConstants.dbUserIdKey,
      );

      // Prefer ID from club object if available, fallback to event's clubId
      final clubId = widget.event.club?.id ?? widget.event.clubId;

      // Club owner (matches database internal ID)
      final isOwner =
          dbUserId != null && dbUserId == widget.event.club?.authClubId;

      // Club-level admin (via clubAdmins table)
      final isClubAdmin = await _apiService.getIsAdminForClub(clubId);

      final isAdmin = isOwner || isClubAdmin;
      if (mounted) {
        setState(() => _isAdmin = isAdmin);
        if (isAdmin) _loadRegisteredStudents();
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _loadExtraDetails() async {
    try {
      final result = await _apiService.getExtraEventDetails(widget.event.id);
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _extraDetails = result['details'];
          }
          _isLoadingExtraDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingExtraDetails = false);
      }
    }
  }

  Future<void> _loadRegisteredStudents() async {
    if (!mounted) return;
    setState(() => _isLoadingStudents = true);
    try {
      final students = await _apiService.getRegisteredStudents(widget.event.id);
      if (mounted) {
        setState(() {
          _registeredStudents = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _exportStudents(String format) async {
    setState(() => _isExporting = true);
    final result = await _apiService.downloadAndOpenExport(
      widget.event.id,
      format,
    );
    if (mounted) {
      setState(() => _isExporting = false);
      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Export failed')),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    haptics.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _handleDelete();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    try {
      final result = await _apiService.deleteEvent(widget.event.id);
      if (mounted) {
        if (result['success'] == true || result['data']?['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
          Navigator.pop(context, true); // Go back with refresh signal
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to delete')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openEditor() async {
    haptics.selectionClick();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventEditor(event: widget.event),
    );

    if (result == true && mounted) {
      // Refresh page or trigger a reload of event data
      // For now, let's just show a message or pop with true
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated! Please refresh.')),
      );
    }
  }

  Future<void> _handleRegistration() async {
    if (widget.event.externalRegistrationLink != null &&
        widget.event.externalRegistrationLink!.isNotEmpty) {
      final url = Uri.parse(widget.event.externalRegistrationLink!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    setState(() => _isRegistering = true);
    try {
      final result = await _apiService.registerForEvent(widget.event.id);
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _isEnrolled = true;
            _isRegistering = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully registered for event!')),
          );
        } else {
          setState(() => _isRegistering = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result['message'])));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to register')));
      }
    }
  }

  void _showFullScreenImage() {
    if (widget.event.bannerUrl == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) =>
            FullScreenImageViewer(imageUrls: [widget.event.bannerUrl!]),
      ),
    );
  }

  Future<void> _handleCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Registration'),
        content: const Text(
          'Are you sure you want to cancel your registration for this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRegistering = true);
    try {
      final result = await _apiService.cancelEventRegistration(widget.event.id);
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _isEnrolled = false;
            _isRegistering = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration cancelled successfully'),
            ),
          );
        } else {
          setState(() => _isRegistering = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result['message'])));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to cancel')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full date format as requested
    final fullDateFormat = DateFormat('EEEE, MMMM d, yyyy h:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Banner Image
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                elevation: 0,
                stretch: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const BackButton(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (_isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 8.0,
                        top: 8,
                        bottom: 8,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openEditor();
                                } else if (value == 'delete') {
                                  _showDeleteConfirmation();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 20),
                                      SizedBox(width: 12),
                                      Text('Edit Event'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                        color: AppColors.error,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Delete Event',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: GestureDetector(
                    onTap: _showFullScreenImage,
                    child: widget.event.bannerUrl != null
                        ? Hero(
                            tag: widget.event.bannerUrl!,
                            child: Stack(
                              children: [
                                // Blurred Background
                                Positioned.fill(
                                  child: SmartImage(
                                    imageUrl: widget.event.bannerUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                // Focused Foreground
                                Positioned.fill(
                                  child: SmartImage(
                                    imageUrl: widget.event.bannerUrl,
                                    fit: BoxFit.contain,
                                    errorWidget: Center(
                                      child: Icon(
                                        Icons.broken_image_rounded,
                                        size: 48,
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.event_rounded,
                                size: 64,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          EventStatusBadge(event: widget.event),
                          const Spacer(),
                          if (widget.event.club != null)
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClubDetailsPage(
                                      club: widget.event.club!,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: isDark
                                    ? AppDecorations.glassDark(borderRadius: 20)
                                    : AppDecorations.glass(borderRadius: 20),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.event.club!.logoUrl != null) ...[
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: SmartImage(
                                          imageUrl: widget.event.club!.logoUrl,
                                          fit: BoxFit.cover,
                                          shape: BoxShape.circle,
                                          errorWidget: const Icon(
                                            Icons.business_rounded,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      widget.event.club!.name,
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        widget.event.title,
                        style: AppTextStyles.h2.copyWith(height: 1.2),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (widget.event.isUpcoming) ...[
                        _CountdownTimer(eventTime: widget.event.eventStartTime),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.lg),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: isDark
                            ? AppDecorations.cardDark()
                            : AppDecorations.card(),
                        child: Column(
                          children: [
                            _buildIconInfo(
                              Icons.calendar_today_rounded,
                              'Start Date',
                              fullDateFormat.format(
                                widget.event.eventStartTime,
                              ),
                            ),
                            const Divider(height: AppSpacing.lg),
                            _buildIconInfo(
                              Icons.event_available_rounded,
                              'End Date',
                              fullDateFormat.format(widget.event.eventEndTime),
                            ),
                            if (widget.event.registrationDeadline != null) ...[
                              const Divider(height: AppSpacing.lg),
                              _buildIconInfo(
                                Icons.timer_outlined,
                                'Registration Deadline',
                                fullDateFormat.format(
                                  widget.event.registrationDeadline!,
                                ),
                                textColor:
                                    widget.event.registrationDeadline!.isBefore(
                                      DateTime.now().add(
                                        const Duration(days: 1),
                                      ),
                                    )
                                    ? AppColors.error
                                    : null,
                              ),
                            ],
                            const Divider(height: AppSpacing.lg),
                            _buildIconInfo(
                              Icons.location_on_rounded,
                              'Venue',
                              widget.event.venue ?? 'To be announced',
                            ),
                            const Divider(height: AppSpacing.lg),
                            _buildIconInfo(
                              Icons.people_rounded,
                              'Participants',
                              '${widget.event.currentParticipants}${widget.event.maxParticipants != null ? ' / ${widget.event.maxParticipants}' : ''} registered',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                      Text('About the Event', style: AppTextStyles.h4),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        widget.event.description ?? 'No description provided.',
                        style: AppTextStyles.bodyLarge.copyWith(
                          height: 1.6,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      if (_isLoadingExtraDetails)
                        const ShimmerWrapper(
                          child: ShimmerInfoCard(height: 150),
                        )
                      else if (_extraDetails != null) ...[
                        if (_extraDetails!['fullDescription'] != null &&
                            _extraDetails!['fullDescription']!
                                .toString()
                                .isNotEmpty) ...[
                          _buildSectionTitle('Event Overlook'),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _extraDetails!['fullDescription']!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              height: 1.6,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _buildExtraDetailField(
                          'Objectives',
                          _extraDetails!['objectives'],
                          Icons.auto_awesome_rounded,
                        ),
                        _buildExtraDetailField(
                          'Target Audience',
                          _extraDetails!['targetAudience'],
                          Icons.person_search_rounded,
                        ),
                        _buildExtraDetailField(
                          'Prerequisites',
                          _extraDetails!['prerequisites'],
                          Icons.rule_rounded,
                        ),
                        _buildExtraDetailField(
                          'Rules & Regulations',
                          _extraDetails!['rules'],
                          Icons.gavel_rounded,
                        ),
                        _buildExtraDetailField(
                          'Judging Criteria',
                          _extraDetails!['judgingCriteria'],
                          Icons.grading_rounded,
                        ),
                      ],

                      // Registered Students (Admin only)
                      if (_isAdmin) _buildRegisteredStudentsCard(),

                      const SizedBox(
                        height: 200,
                      ), // Increased spacing for bottom interaction to prevent overlap with the floating bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.md,
                AppSpacing.base,
                MediaQuery.of(context).padding.bottom + AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: _isLoadingEnrollment
                  ? ShimmerWrapper(
                      child: Container(
                        height: 48,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : _buildActionButtons(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Admin: show admin badge, no enrollment buttons ──────────────────
    if (_isAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Admin View — Registration managed by you',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    // ── Inactive Status: common for non-enrolled users ────────────────────
    final bool isInactive =
        widget.event.isCompleted ||
        widget.event.isCancelled ||
        (widget.event.registrationDeadline != null &&
            widget.event.registrationDeadline!.isBefore(DateTime.now()));

    if (isInactive && !_isEnrolled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              widget.event.isCompleted
                  ? 'Event Ended'
                  : widget.event.isCancelled
                  ? 'Event Cancelled'
                  : 'Registration Closed',
              style: AppTextStyles.labelMedium.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // ── External registration: only show redirect button ─────────────────
    final hasExternalLink =
        widget.event.externalRegistrationLink != null &&
        widget.event.externalRegistrationLink!.isNotEmpty;

    if (hasExternalLink && !_isEnrolled) {
      return Row(
        children: [
          Container(
            decoration: isDark
                ? AppDecorations.cardDark(borderRadius: AppRadius.md)
                : AppDecorations.card(borderRadius: AppRadius.md),
            child: IconButton(
              onPressed: _shareEvent,
              icon: const Icon(Icons.share_rounded, color: AppColors.primary),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Container(
              decoration: AppDecorations.gradientCard(
                borderRadius: AppRadius.md,
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(widget.event.externalRegistrationLink!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  'Register Externally',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Enrolled: show cancel button ──────────────────────────────────────
    if (_isEnrolled) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'You are registered',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.event.isCompleted && !widget.event.isCancelled) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isRegistering ? null : _handleCancellation,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: _isRegistering
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : Text(
                        'Unregister',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.error,
                        ),
                      ),
              ),
            ),
          ],
        ],
      );
    }

    // ── Not enrolled: show join button ────────────────────────────────────
    return Row(
      children: [
        Container(
          decoration: isDark
              ? AppDecorations.cardDark(borderRadius: AppRadius.md)
              : AppDecorations.card(borderRadius: AppRadius.md),
          child: IconButton(
            onPressed: _shareEvent,
            icon: Icon(Icons.share_rounded, color: AppColors.primary),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          decoration: isDark
              ? AppDecorations.cardDark(borderRadius: AppRadius.md)
              : AppDecorations.card(borderRadius: AppRadius.md),
          child: IconButton(
            onPressed: () async {
              final success = await CalendarService.addEventToCalendar(
                widget.event,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Event added to calendar'
                          : 'Could not add event to calendar',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: Icon(Icons.event_note_rounded, color: AppColors.primary),
            padding: const EdgeInsets.all(12),
            tooltip: 'Add to Calendar',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            decoration: AppDecorations.gradientCard(borderRadius: AppRadius.md),
            child: ElevatedButton(
              onPressed: _isRegistering ? null : _handleRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: _isRegistering
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Join Event',
                      style: AppTextStyles.button.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconInfo(
    IconData icon,
    String label,
    String value, {
    Color? textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.labelLarge.copyWith(
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _shareEvent() async {
    final baseUrl = AppConstants.baseUrl;
    final eventUrl = '$baseUrl/events/${widget.event.id}';
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy h:mm a');

    final String text =
        '''
Check out this event: ${widget.event.title}

📅 Date: ${dateFormat.format(widget.event.eventStartTime)}
📍 Venue: ${widget.event.venue ?? 'To be announced'}

${widget.event.description ?? ''}

Join here: $eventUrl
''';

    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Event: ${widget.event.title}'),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
    );
  }

  /// Admin-only card showing registered students with export options.
  Widget _buildRegisteredStudentsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Registered Students',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              // Export buttons
              if (_isExporting)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton<String>(
                  onSelected: _exportStudents,
                  icon: const Icon(Icons.more_vert_rounded),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Export CSV'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Export PDF'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_isLoadingStudents)
            const ShimmerWrapper(child: ShimmerInfoCard(height: 120))
          else if (_registeredStudents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: isDark
                  ? AppDecorations.cardDark()
                  : AppDecorations.card(),
              child: Text(
                'No students registered yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              decoration: isDark
                  ? AppDecorations.cardDark()
                  : AppDecorations.card(),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _registeredStudents.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final student = _registeredStudents[index];
                  final statusColor = student.status == 'registered'
                      ? AppColors.success
                      : AppColors.textSecondary;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: SmartImage(
                        imageUrl: student.studentPhoto,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        shape: BoxShape.circle,
                        errorWidget: Center(
                          child: Text(
                            (student.studentName ?? '?')[0].toUpperCase(),
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      student.studentName ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.studentEmail ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (student.registeredAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Registered ${DateFormat('MMM d, h:mm a').format(student.registeredAt!)}',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textSecondaryDark.withValues(
                                        alpha: 0.7,
                                      )
                                    : AppColors.textSecondary.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        student.status,
                        style: AppTextStyles.caption.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExtraDetailField(String label, dynamic value, IconData icon) {
    if (value == null || value.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: isDark
                ? AppDecorations.cardDark(borderRadius: AppRadius.md)
                : AppDecorations.card(borderRadius: AppRadius.md),
            child: Text(
              value.toString(),
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.6,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime eventTime;

  const _CountdownTimer({required this.eventTime});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    final difference = widget.eventTime.difference(now);
    if (mounted) {
      setState(() {
        _timeLeft = difference.isNegative ? Duration.zero : difference;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.inSeconds == 0) return const SizedBox.shrink();

    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            'Starts in: ',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
          ),
          Text(
            '${days}d ${hours}h ${minutes}m ${seconds}s',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
