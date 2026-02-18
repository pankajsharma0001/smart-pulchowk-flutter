import 'package:flutter/material.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
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
      // Manual/Silent refresh - sync role too
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
    if (success) {
      setState(() {
        notification.isRead = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(silent: true),
        child: _isLoading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 8,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: ShimmerWrapper(
          child: Skeleton(height: 90, width: double.infinity, borderRadius: 16),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'All caught up!',
              style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No new notifications at the moment.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: 100,
      ),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _NotificationTile(
          notification: notification,
          onTap: () {
            _markRead(notification);
            _handleNotificationClick(notification);
          },
        );
      },
    );
  }

  void _handleNotificationClick(InAppNotification notification) {
    haptics.lightImpact();
    // Implementation for navigation based on type will go here
    // e.g., if (notification.type == NotificationType.messageReceived) ...
  }
}

class _NotificationTile extends StatelessWidget {
  final InAppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat.jm().format(notification.createdAt);
    final dateStr = DateFormat.MMMd().format(notification.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: notification.isRead
            ? Colors.transparent
            : (isDark
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.primary.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: notification.isRead
              ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                    .withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: notification.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.icon,
                  size: 20,
                  color: notification.color,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notification.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w700
                                : FontWeight.w900,
                            color: notification.isRead
                                ? null
                                : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: notification.isRead
                            ? AppColors.textMuted
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(left: AppSpacing.sm, top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
