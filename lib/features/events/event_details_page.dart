import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:smart_pulchowk/features/events/widgets/event_status_badge.dart';
import 'package:smart_pulchowk/core/widgets/image_viewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_pulchowk/features/clubs/club_details_page.dart';

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

  Future<void> _handleRegistration() async {
    if (widget.event.externalRegistrationLink != null &&
        widget.event.externalRegistrationLink!.isNotEmpty) {
      final url = Uri.parse(widget.event.externalRegistrationLink!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
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
                                  child: CachedNetworkImage(
                                    imageUrl: widget.event.bannerUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => Container(
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
                                  child: CachedNetworkImage(
                                    imageUrl: widget.event.bannerUrl!,
                                    fit: BoxFit.contain,
                                    placeholder: (_, _) => const ShimmerWrapper(
                                      child: Skeleton(height: double.infinity),
                                    ),
                                    errorWidget: (_, _, _) => Center(
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
                                        child: CachedNetworkImage(
                                          imageUrl: widget.event.club!.logoUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) =>
                                              const ShimmerWrapper(
                                                child: Skeleton(
                                                  height: double.infinity,
                                                ),
                                              ),
                                          errorWidget: (_, _, _) => const Icon(
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
      );
    }

    final bool canRegister =
        !widget.event.isCompleted &&
        !widget.event.isCancelled &&
        !_isRegistering;

    return Row(
      children: [
        // Share Button
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
        // Primary Action
        Expanded(
          child: Container(
            decoration: canRegister
                ? AppDecorations.gradientCard(borderRadius: AppRadius.md)
                : null,
            child: ElevatedButton(
              onPressed: canRegister ? _handleRegistration : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canRegister ? Colors.transparent : null,
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
                      widget.event.isCompleted
                          ? 'Event Ended'
                          : widget.event.isCancelled
                          ? 'Cancelled'
                          : widget.event.externalRegistrationLink != null
                          ? 'External Registration'
                          : 'Join Event',
                      style: AppTextStyles.button.copyWith(
                        color: canRegister ? Colors.white : Colors.grey,
                      ),
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

    await Share.share(text, subject: 'Event: ${widget.event.title}');
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
