import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';

enum LostFoundCardType { grid, list }

class LostFoundCard extends StatelessWidget {
  final LostFoundItem item;
  final LostFoundCardType type;
  final VoidCallback? onTap;

  const LostFoundCard({
    super.key,
    required this.item,
    this.type = LostFoundCardType.grid,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (type == LostFoundCardType.grid) {
      return _buildGridCard(context);
    }
    return _buildListCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLost = item.itemType == LostFoundItemType.lost;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: isDark
            ? AppDecorations.cardDark(borderRadius: AppRadius.lg)
            : AppDecorations.card(borderRadius: AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Expanded(
              flex: 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SmartImage(
                    imageUrl: item.images.isNotEmpty
                        ? item.images.first.imageUrl
                        : null,
                    errorWidget: _buildPlaceholder(context),
                  ),

                  // Type Badge (Lost/Found)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _buildTypeBadge(isLost),
                  ),

                  // Category Icon
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getCategoryIcon(item.category),
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Status Indicator
                  if (item.status != LostFoundStatus.open)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Text(
                          item.status.displayName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.overline.copyWith(
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.labelLarge.copyWith(height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.locationText,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: item.owner?['image'] != null
                                ? SmartImage(
                                    imageUrl: item.owner!['image'],
                                    fit: BoxFit.cover,
                                    errorWidget: const Icon(
                                      Icons.person,
                                      size: 10,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.owner?['name']?.toString() ?? 'Unknown',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.timeAgo,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMuted,
                          ),
                        ),
                        if (item.rewardText != null &&
                            item.rewardText!.isNotEmpty)
                          const Icon(
                            Icons.card_giftcard_rounded,
                            size: 14,
                            color: AppColors.secondary,
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

  Widget _buildListCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLost = item.itemType == LostFoundItemType.lost;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: isDark
            ? AppDecorations.cardDark(borderRadius: AppRadius.lg)
            : AppDecorations.card(borderRadius: AppRadius.lg),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(borderRadius: AppRadius.mdAll),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SmartImage(
                    imageUrl: item.images.isNotEmpty
                        ? item.images.first.imageUrl
                        : null,
                    errorWidget: _buildPlaceholder(context, iconSize: 24),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _buildTypeBadge(isLost, isCompact: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.locationText,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: item.owner?['image'] != null
                              ? SmartImage(
                                  imageUrl: item.owner!['image'],
                                  fit: BoxFit.cover,
                                  errorWidget: const Icon(
                                    Icons.person,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 10,
                                  color: AppColors.primary,
                                ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.owner?['name']?.toString() ?? 'Unknown',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.timeAgo,
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                      const Spacer(),
                      if (item.status != LostFoundStatus.open)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.xsAll,
                          ),
                          child: Text(
                            item.status.displayName,
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.primary,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(bool isLost, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 6,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: isLost ? AppColors.error : AppColors.success,
        borderRadius: AppRadius.xsAll,
      ),
      child: Text(
        isLost ? 'LOST' : 'FOUND',
        style: AppTextStyles.overline.copyWith(
          color: Colors.white,
          fontSize: isCompact ? 8 : 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {double iconSize = 48}) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: AppColors.primary.withValues(alpha: 0.1),
          size: iconSize,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(LostFoundCategory category) {
    switch (category) {
      case LostFoundCategory.documents:
        return Icons.description_rounded;
      case LostFoundCategory.electronics:
        return Icons.devices_other_rounded;
      case LostFoundCategory.accessories:
        return Icons.watch_rounded;
      case LostFoundCategory.idsCards:
        return Icons.badge_rounded;
      case LostFoundCategory.keys:
        return Icons.key_rounded;
      case LostFoundCategory.bags:
        return Icons.shopping_bag_rounded;
      case LostFoundCategory.other:
        return Icons.category_rounded;
    }
  }
}
