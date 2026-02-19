import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_pulchowk/core/models/club.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/features/events/widgets/event_card.dart';

class ClubDetailsPage extends StatefulWidget {
  final Club club;

  const ClubDetailsPage({super.key, required this.club});

  @override
  State<ClubDetailsPage> createState() => _ClubDetailsPageState();
}

class _ClubDetailsPageState extends State<ClubDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  bool _isLoadingProfile = true;
  bool _isLoadingEvents = true;
  ClubProfile? _profile;
  List<ClubEvent> _events = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    _loadProfile(forceRefresh: forceRefresh);
    _loadEvents(forceRefresh: forceRefresh);
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _error = null;
    });

    try {
      final profile = await _apiService.getClubProfile(
        widget.club.id,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load club profile.';
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadEvents({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final events = await _apiService.getClubEvents(
        widget.club.id,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _events = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildSliverAppBar(context), _buildStickyTabBar(context)];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              child: _buildAboutTab(),
            ),
            RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              child: _buildEventsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1D4ED8), Color(0xFF6366F1)],
                ),
              ),
            ),

            // Subtle pattern overlay
            Opacity(
              opacity: 0.06,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 10,
                  childAspectRatio: 1,
                ),
                itemCount: 200,
                itemBuilder: (context, index) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  margin: const EdgeInsets.all(4),
                ),
              ),
            ),

            // Bottom gradient fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            ),

            // Logo and Basic Info
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.base,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Club Logo
                    Hero(
                      tag: 'club_logo_${widget.club.id}',
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.lg,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 4,
                          ),
                        ),
                        child: ClipOval(
                          child: widget.club.logoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.club.logoUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const ShimmerWrapper(
                                        child: Skeleton(shape: BoxShape.circle),
                                      ),
                                  errorWidget: (context, url, error) =>
                                      _buildLogoFallback(),
                                )
                              : _buildLogoFallback(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Club name
                    Text(
                      widget.club.name,
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (widget.club.description != null &&
                        widget.club.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.club.description!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: AppSpacing.md),

                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatChip(
                          Icons.event_rounded,
                          '${widget.club.upcomingEvents}',
                          'Upcoming',
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _buildStatChip(
                          Icons.check_circle_rounded,
                          '${widget.club.completedEvents}',
                          'Completed',
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _buildStatChip(
                          Icons.people_rounded,
                          '${widget.club.totalParticipants}',
                          'Members',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoFallback() {
    return Container(
      color: AppColors.primaryContainer,
      child: Center(
        child: Text(
          widget.club.name[0].toUpperCase(),
          style: AppTextStyles.h2.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: AppSpacing.xs),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyTabBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textMutedDark
              : AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(
              icon: Icon(Icons.info_outline_rounded, size: 18),
              text: 'About',
            ),
            Tab(icon: Icon(Icons.event_rounded, size: 18), text: 'Events'),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    if (_isLoadingEvents) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 3,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerWrapper(child: Skeleton(height: 100)),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No events yet',
              style: AppTextStyles.h5.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check back later for upcoming events.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        return EventCard(event: _events[index], type: EventCardType.list);
      },
    );
  }

  Widget _buildAboutTab() {
    if (_isLoadingProfile) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.base),
        children: const [
          ShimmerWrapper(
            child: Skeleton(height: 120, borderRadius: AppRadius.lg),
          ),
          SizedBox(height: AppSpacing.md),
          ShimmerWrapper(
            child: Skeleton(height: 180, borderRadius: AppRadius.lg),
          ),
          SizedBox(height: AppSpacing.md),
          ShimmerWrapper(
            child: Skeleton(height: 140, borderRadius: AppRadius.lg),
          ),
        ],
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => _loadProfile(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.massive,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          if (widget.club.isActive) _buildStatusBadge(context),

          const SizedBox(height: AppSpacing.base),

          // About section
          _buildInfoCard(
            context,
            icon: Icons.auto_stories_rounded,
            title: 'About',
            child: Text(
              _profile?.aboutClub ??
                  widget.club.description ??
                  'No description available.',
              style: AppTextStyles.bodyMedium.copyWith(height: 1.7),
            ),
          ),

          // Mission & Vision
          if (_profile?.mission != null || _profile?.vision != null)
            _buildMissionVisionCard(context),

          // Contact Information
          _buildContactCard(context),

          // Social Media
          _buildSocialCard(context),

          // Additional Info
          if (_profile?.achievements != null || _profile?.benefits != null)
            _buildAdditionalInfoCard(context),

          const SizedBox(height: AppSpacing.xl),

          // CTA Button
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.successContainer,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Active Club',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: isDark ? AppDecorations.cardDark() : AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _buildMissionVisionCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: isDark ? AppDecorations.cardDark() : AppDecorations.card(),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded, size: 16, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Mission & Vision',
                  style: AppTextStyles.h5.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_profile?.mission != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mission',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _profile!.mission!,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                  ),
                ],
              ),
            ),
          if (_profile?.mission != null && _profile?.vision != null)
            const Divider(indent: AppSpacing.base, endIndent: AppSpacing.base),
          if (_profile?.vision != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.sm,
                AppSpacing.base,
                AppSpacing.base,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vision',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _profile!.vision!,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    final hasContact =
        _profile?.contactPhone != null ||
        widget.club.email != null ||
        _profile?.websiteUrl != null ||
        _profile?.address != null;

    if (!hasContact) return const SizedBox.shrink();

    return _buildInfoCard(
      context,
      icon: Icons.contact_phone_rounded,
      title: 'Contact Information',
      child: Column(
        children: [
          if (_profile?.contactPhone != null)
            ..._profile!.contactPhone!.split(RegExp(r'[,\/]')).map((phone) {
              final trimmedPhone = phone.trim();
              if (trimmedPhone.isEmpty) return const SizedBox.shrink();
              return _buildContactTile(
                context,
                icon: Icons.phone_rounded,
                label: trimmedPhone,
                subtitle: 'Phone',
                color: AppColors.success,
                onTap: () => _launchURL('tel:$trimmedPhone'),
              );
            }),
          if (widget.club.email != null || _profile?.email != null)
            _buildContactTile(
              context,
              icon: Icons.email_rounded,
              label: widget.club.email ?? _profile!.email!,
              subtitle: 'Email',
              color: AppColors.primary,
              onTap: () =>
                  _launchURL('mailto:${widget.club.email ?? _profile!.email!}'),
            ),
          if (_profile?.websiteUrl != null)
            _buildContactTile(
              context,
              icon: Icons.language_rounded,
              label: _profile!.websiteUrl!,
              subtitle: 'Website',
              color: AppColors.tertiary,
              onTap: () => _launchURL(_profile!.websiteUrl!),
            ),
          if (_profile?.address != null)
            _buildContactTile(
              context,
              icon: Icons.location_on_rounded,
              label: _profile!.address!,
              subtitle: 'Location',
              color: AppColors.warning,
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    Color color = AppColors.primary,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: onTap != null ? color : null,
                          fontWeight: onTap != null
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }

  Widget _buildSocialCard(BuildContext context) {
    final links = _profile?.socialLinks;
    if (links == null) return const SizedBox.shrink();

    final socialMap = {
      'facebook': (Icons.facebook_rounded, const Color(0xFF1877F2)),
      'instagram': (Icons.camera_alt_rounded, const Color(0xFFE1306C)),
      'twitter': (Icons.alternate_email_rounded, const Color(0xFF1DA1F2)),
      'linkedin': (Icons.work_rounded, const Color(0xFF0A66C2)),
      'youtube': (Icons.play_circle_fill_rounded, const Color(0xFFFF0000)),
      'discord': (Icons.headset_mic_rounded, const Color(0xFF5865F2)),
      'github': (Icons.code_rounded, const Color(0xFF333333)),
      'tiktok': (Icons.music_video_rounded, const Color(0xFF000000)),
    };

    final activePlatforms = socialMap.keys
        .where((key) => links[key] != null && links[key]!.isNotEmpty)
        .toList();

    if (activePlatforms.isEmpty) return const SizedBox.shrink();

    return _buildInfoCard(
      context,
      icon: Icons.share_rounded,
      title: 'Social Media',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: activePlatforms.map((platform) {
          final (icon, color) = socialMap[platform]!;
          return _buildSocialButton(
            platform: platform,
            icon: icon,
            color: color,
            url: links[platform]!,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSocialButton({
    required String platform,
    required IconData icon,
    required Color color,
    required String url,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchURL(url),
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _capitalize(platform),
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoCard(BuildContext context) {
    if (_profile?.achievements == null && _profile?.benefits == null) {
      return const SizedBox.shrink();
    }

    return _buildInfoCard(
      context,
      icon: Icons.star_rounded,
      title: 'More Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_profile?.achievements != null) ...[
            Text(
              'Achievements',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _profile!.achievements!,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
            ),
            if (_profile?.benefits != null)
              const SizedBox(height: AppSpacing.md),
          ],
          if (_profile?.benefits != null) ...[
            Text(
              'Member Benefits',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _profile!.benefits!,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.club.email == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.glow(AppColors.primary, intensity: 0.3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchURL('mailto:${widget.club.email}'),
          borderRadius: AppRadius.lgAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.base,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_rounded, color: Colors.white, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Contact Club',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')),
        );
      }
    }
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
