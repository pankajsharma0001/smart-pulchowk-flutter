import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/events/widgets/event_card.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<ClubEvent> _allEvents = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents({bool forceRefresh = false}) async {
    if (!mounted) return;

    // Only show full screen loading if we don't have events yet
    final bool showFullLoading =
        (_allEvents.isEmpty || _error != null) && !forceRefresh;

    if (showFullLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final events = await _apiService.getAllEvents(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoading = false;
          _error = null;

          // Smart Tab Selection: Default to Ongoing (0)
          // If Ongoing is empty but Upcoming has events, switch to Upcoming (1)
          final hasOngoing = events.any((e) => e.isOngoing);
          final hasUpcoming = events.any((e) => e.isUpcoming);

          if (!hasOngoing && hasUpcoming && _tabController.index == 0) {
            _tabController.animateTo(1);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load events';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Events'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Ongoing'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: _isLoading
            ? _buildLoadingState()
            : _error != null
            ? _buildErrorState()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildRefreshableList(
                    _allEvents.where((e) => e.isOngoing).toList(),
                  ),
                  _buildRefreshableList(
                    _allEvents.where((e) => e.isUpcoming).toList(),
                  ),
                  _buildRefreshableList(
                    _allEvents
                        .where((e) => e.isCompleted || e.isCancelled)
                        .toList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRefreshableList(List<ClubEvent> events) {
    return RefreshIndicator(
      onRefresh: () => _loadEvents(forceRefresh: true),
      child: events.isEmpty ? _buildEmptyState() : _buildEventList(events),
    );
  }

  Widget _buildEventList(List<ClubEvent> events) {
    if (events.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100, // Bottom padding for navbar
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return EventCard(event: events[index]);
      },
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100, // Bottom padding for navbar
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const ShimmerWrapper(
          child: Skeleton(borderRadius: AppRadius.lg),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 64,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No events found',
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error ?? 'Something went wrong',
                    style: AppTextStyles.bodyLarge,
                  ),
                  TextButton(
                    onPressed: () => _loadEvents(forceRefresh: true),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
