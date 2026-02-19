import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/events/widgets/event_status_badge.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.event.bannerUrl != null
                  ? CachedNetworkImage(
                      imageUrl: widget.event.bannerUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ShimmerWrapper(
                        child: Skeleton(height: double.infinity),
                      ),
                    )
                  : Container(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventStatusBadge(event: widget.event),
                  const SizedBox(height: AppSpacing.md),
                  Text(widget.event.title, style: AppTextStyles.h2),
                  if (widget.event.club != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (widget.event.club!.logoUrl != null)
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: CachedNetworkImageProvider(
                              widget.event.club!.logoUrl!,
                            ),
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          widget.event.club!.name,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: AppSpacing.xxl),
                  _buildIconInfo(
                    Icons.calendar_month_rounded,
                    'Date',
                    dateFormat.format(widget.event.eventStartTime),
                  ),
                  _buildIconInfo(
                    Icons.access_time_rounded,
                    'Time',
                    '${timeFormat.format(widget.event.eventStartTime)} - ${timeFormat.format(widget.event.eventEndTime)}',
                  ),
                  _buildIconInfo(
                    Icons.location_on_rounded,
                    'Venue',
                    widget.event.venue ?? 'To be announced',
                  ),
                  _buildIconInfo(
                    Icons.people_rounded,
                    'Participants',
                    '${widget.event.currentParticipants}${widget.event.maxParticipants != null ? ' / ${widget.event.maxParticipants}' : ''} registered',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('About the Event', style: AppTextStyles.h4),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.event.description ?? 'No description provided.',
                    style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 100), // Spacing for fab/bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: _isLoadingEnrollment
              ? const LinearProgressIndicator()
              : ElevatedButton(
                  onPressed:
                      widget.event.isCompleted ||
                          widget.event.isCancelled ||
                          _isEnrolled ||
                          _isRegistering
                      ? null
                      : _handleRegistration,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                          _isEnrolled
                              ? 'Registered'
                              : widget.event.externalRegistrationLink != null
                              ? 'Register on External Site'
                              : 'Register Now',
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildIconInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
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
                  ),
                ),
                Text(value, style: AppTextStyles.labelLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
