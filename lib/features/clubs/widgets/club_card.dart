import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/club.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/features/clubs/club_details_page.dart';

class ClubCard extends StatelessWidget {
  final Club club;
  final VoidCallback? onTap;

  const ClubCard({super.key, required this.club, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap ?? () => _navigateToDetails(context),
      child: Container(
        decoration: isDark
            ? AppDecorations.cardDark(borderRadius: AppRadius.lg)
            : AppDecorations.card(borderRadius: AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Club Logo Section
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Logo with animated-ish background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.1),
                          AppColors.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Hero(
                      tag: 'club_logo_${club.id}',
                      child: _buildLogo(context),
                    ),
                  ),

                  // Official Badge
                  if (club.isActive)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'OFFICIAL',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        club.description ?? 'No description available.',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMuted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Stats Row
                    Row(
                      children: [
                        _buildStat(
                          context,
                          Icons.event_note_rounded,
                          '${club.upcomingEvents} Events',
                        ),
                        const SizedBox(width: 12),
                        _buildStat(
                          context,
                          Icons.people_rounded,
                          '${club.totalParticipants} Members',
                          isPrimary: true,
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

  Widget _buildLogo(BuildContext context) {
    if (club.logoUrl != null && club.logoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: club.logoUrl!,
        fit: BoxFit.contain,
        placeholder: (_, _) =>
            const ShimmerWrapper(child: Skeleton(shape: BoxShape.circle)),
        errorWidget: (_, _, _) => _buildPlaceholderLogo(context),
      );
    }
    return _buildPlaceholderLogo(context);
  }

  Widget _buildPlaceholderLogo(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(
    BuildContext context,
    IconData icon,
    String label, {
    bool isPrimary = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isPrimary
        ? AppColors.primary
        : (isDark ? AppColors.textMutedDark : AppColors.textMuted);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ClubDetailsPage(club: club)),
    );
  }
}
