import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/services/navigation_service.dart';
import 'package:smart_pulchowk/core/models/notification.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<InAppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    } else if (mounted) {
      debugPrint('NotificationsPage: Manual refresh. Syncing role...');
      await MainLayout.of(context)?.refreshUserRole();
      if (!mounted) return;
    }
    try {
      final data = await _api.getNotifications(forceRefresh: silent);
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    haptics.mediumImpact();
    final success = await _api.markAllNotificationsRead();
    if (success) {
      await _loadNotifications(silent: true);
    }
  }

  Future<void> _markRead(InAppNotification notification) async {
    if (notification.isRead) return;
    final success = await _api.markNotificationRead(notification.id);
    if (success && mounted) {
      setState(() {
        notification.isRead = true;
      });
    }
  }

  void _handleNotificationClick(InAppNotification notification) {
    haptics.lightImpact();

    // If the page was pushed (e.g. from the App Bar bell) and is on top, pop it.
    // This allows the NavigationService to switch tabs behind it and show the result.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    NavigationService.handleInAppNotification(notification);
  }

  Map<String, List<InAppNotification>> _groupByDate(
    List<InAppNotification> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<InAppNotification>>{
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };
    for (final n in notifications) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (d == today) {
        groups['Today']!.add(n);
      } else if (d == yesterday) {
        groups['Yesterday']!.add(n);
      } else {
        groups['Older']!.add(n);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton.icon(
              onPressed: _markAllRead,
              icon: Icon(Icons.done_all_rounded, size: 18, color: cs.primary),
              label: Text(
                'Mark all read',
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(silent: true),
        color: cs.primary,
        child: _isLoading ? _buildLoading() : _buildContent(cs),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: ShimmerWrapper(
          child: Skeleton(height: 90, width: double.infinity, borderRadius: 16),
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'All caught up!',
              style: AppTextStyles.h4.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No new notifications at the moment.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    final groups = _groupByDate(_notifications);
    final items = <_ListItem>[];

    for (final key in ['Today', 'Yesterday', 'Older']) {
      final group = groups[key]!;
      if (group.isEmpty) continue;
      items.add(_ListItem.header(key));
      for (final n in group) {
        items.add(_ListItem.notification(n));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: 100,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return _buildSectionHeader(item.header!, cs);
        }
        final notification = item.notification!;
        return Dismissible(
          key: ValueKey(notification.id),
          direction: notification.isRead
              ? DismissDirection.none
              : DismissDirection.startToEnd,
          onDismissed: (_) => _markRead(notification),
          background: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Icon(Icons.done_rounded, color: cs.primary),
          ),
          child: _NotificationTile(
            notification: notification,
            onTap: () {
              _markRead(notification);
              _handleNotificationClick(notification);
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String label, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
        left: 4,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

// ─── List item helper ─────────────────────────────────────────────────────────

class _ListItem {
  final String? header;
  final InAppNotification? notification;

  bool get isHeader => header != null;

  const _ListItem.header(this.header) : notification = null;
  const _ListItem.notification(this.notification) : header = null;
}

// ─── Notification Tile ────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final InAppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final timeStr = DateFormat.jm().format(notification.createdAt);
    final dateStr = DateFormat.MMMd().format(notification.createdAt);

    final isUnread = !notification.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isUnread
            ? cs.primary.withValues(alpha: isDark ? 0.08 : 0.05)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isUnread
              ? cs.primary.withValues(alpha: 0.25)
              : cs.outlineVariant.withValues(alpha: 0.4),
          width: isUnread ? 1.2 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: icon circle (with optional actor avatar overlay)
              _buildLeadingIcon(cs),
              const SizedBox(width: AppSpacing.md),

              // Center: title + body + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isUnread
                                  ? cs.onSurface
                                  : cs.onSurface.withValues(alpha: 0.75),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Body
                    Text(
                      notification.body,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isUnread
                            ? cs.onSurface.withValues(alpha: 0.75)
                            : cs.onSurface.withValues(alpha: 0.50),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Date tag
                    Text(
                      dateStr,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.35),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Right: thumbnail or unread dot
              const SizedBox(width: AppSpacing.sm),
              _buildTrailing(cs, isUnread),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(ColorScheme cs) {
    const iconSize = 44.0;
    final iconColor = notification.color;

    // If there's an actor avatar use it with a small icon badge
    if (notification.actorAvatarUrl != null) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: Stack(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: notification.actorAvatarUrl!,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notification.icon, size: 20, color: iconColor),
                ),
                errorWidget: (_, _, _) => Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notification.icon, size: 20, color: iconColor),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 1.5),
                ),
                child: Icon(notification.icon, size: 8, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    // Plain icon circle
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(notification.icon, size: 22, color: iconColor),
    );
  }

  Widget _buildTrailing(ColorScheme cs, bool isUnread) {
    // Thumbnail image
    if (notification.thumbnailUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: CachedNetworkImage(
          imageUrl: notification.thumbnailUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            width: 52,
            height: 52,
            color: cs.surfaceContainerHighest,
          ),
          errorWidget: (_, _, e) => _buildUnreadDot(cs, isUnread),
        ),
      );
    }

    return _buildUnreadDot(cs, isUnread);
  }

  Widget _buildUnreadDot(ColorScheme cs, bool isUnread) {
    if (!isUnread) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
    );
  }
}
