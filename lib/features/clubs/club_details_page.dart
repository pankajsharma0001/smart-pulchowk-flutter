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
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.8),
                    AppColors.primary.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),

            // Logo and Basic Info
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Hero(
                    tag: 'club_logo_${widget.club.id}',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.md,
                        border: Border.all(color: Colors.white, width: 3),
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
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    widget.club.name[0].toUpperCase(),
                                    style: AppTextStyles.h2.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  widget.club.name[0].toUpperCase(),
                                  style: AppTextStyles.h2.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.club.name,
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
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
          tabs: const [
            Tab(text: 'About'),
            Tab(text: 'Events'),
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
            Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No upcoming events',
              style: AppTextStyles.bodyLarge.copyWith(
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
        children: const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: ShimmerWrapper(child: Skeleton(height: 100)),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: ShimmerWrapper(child: Skeleton(height: 150)),
          ),
        ],
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: AppTextStyles.bodyMedium),
            TextButton(
              onPressed: () => _loadProfile(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'About',
            _profile?.aboutClub ??
                widget.club.description ??
                'No description available.',
          ),
          if (_profile?.mission != null)
            _buildSection('Mission', _profile!.mission!),
          if (_profile?.vision != null)
            _buildSection('Vision', _profile!.vision!),

          _buildContactInfo(),
          _buildSocialLinks(),

          const SizedBox(height: AppSpacing.xxl),
          _buildActionButtons(),
          const SizedBox(height: 100), // Spacing for safe area
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_profile?.contactPhone != null)
            _buildContactRow(
              Icons.phone_rounded,
              'Phone',
              _profile!.contactPhone!,
            ),
          if (widget.club.email != null)
            _buildContactRow(Icons.email_rounded, 'Email', widget.club.email!),
          if (_profile?.websiteUrl != null)
            _buildContactRow(
              Icons.language_rounded,
              'Website',
              _profile!.websiteUrl!,
            ),
          if (_profile?.address != null)
            _buildContactRow(
              Icons.location_on_rounded,
              'Location',
              _profile!.address!,
            ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                Text(value, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinks() {
    final links = _profile?.socialLinks;
    if (links == null ||
        (links['facebook'] == null &&
            links['instagram'] == null &&
            links['twitter'] == null &&
            links['linkedin'] == null &&
            links['youtube'] == null &&
            links['discord'] == null &&
            links['github'] == null &&
            links['tiktok'] == null)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Social Media',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            if (links['facebook'] != null)
              _buildSocialIcon('facebook', links['facebook']!),
            if (links['instagram'] != null)
              _buildSocialIcon('instagram', links['instagram']!),
            if (links['twitter'] != null)
              _buildSocialIcon('twitter', links['twitter']!),
            if (links['linkedin'] != null)
              _buildSocialIcon('linkedin', links['linkedin']!),
            if (links['youtube'] != null)
              _buildSocialIcon('youtube', links['youtube']!),
            if (links['discord'] != null)
              _buildSocialIcon('discord', links['discord']!),
            if (links['github'] != null)
              _buildSocialIcon('github', links['github']!),
            if (links['tiktok'] != null)
              _buildSocialIcon('tiktok', links['tiktok']!),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialIcon(String platform, String url) {
    return GestureDetector(
      onTap: () => _launchURL(url),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          'assets/icons/social/$platform.png',
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.link_rounded, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.club.email == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launchURL('mailto:${widget.club.email}'),
        icon: const Icon(Icons.email_rounded),
        label: const Text('Contact Club'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(content, style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
        ],
      ),
    );
  }
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
