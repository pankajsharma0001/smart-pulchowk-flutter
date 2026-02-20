import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/theme/theme_provider.dart';
import 'package:smart_pulchowk/core/services/auth_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/services/notification_service.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_pulchowk/features/marketplace/blocked_users_page.dart';
import 'package:smart_pulchowk/features/marketplace/my_reports_page.dart';
import 'package:smart_pulchowk/features/settings/help_center_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _appVersion = '1.0.0';
  String _userRole = 'student';

  // Notification Preferences
  bool _eventsNotify = true;
  bool _booksNotify = true;
  bool _noticesNotify = true;
  bool _announcementsNotify = true;
  bool _classroomNotify = true;
  bool _chatNotify = true;
  bool _lostFoundNotify = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    final hasPermission = await NotificationService.hasPermission();
    final role = await _apiService.getUserRole();

    setState(() {
      _eventsNotify = hasPermission && (prefs.getBool('notify_events') ?? true);
      _booksNotify = hasPermission && (prefs.getBool('notify_books') ?? true);
      _noticesNotify =
          hasPermission && (prefs.getBool('notify_notices') ?? true);
      _announcementsNotify =
          hasPermission && (prefs.getBool('notify_announcements') ?? true);
      _classroomNotify =
          hasPermission && (prefs.getBool('notify_classroom') ?? true);
      _chatNotify = hasPermission && (prefs.getBool('notify_chat') ?? true);
      _lostFoundNotify =
          hasPermission && (prefs.getBool('notify_lost_found') ?? true);
      _appVersion = info.version;
      _userRole = role;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotification(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    setState(() {
      if (key == 'notify_events') _eventsNotify = value;
      if (key == 'notify_books') _booksNotify = value;
      if (key == 'notify_notices') _noticesNotify = value;
      if (key == 'notify_announcements') _announcementsNotify = value;
      if (key == 'notify_classroom') _classroomNotify = value;
      if (key == 'notify_chat') _chatNotify = value;
      if (key == 'notify_lost_found') _lostFoundNotify = value;
    });

    final topic = key.replaceFirst('notify_', '');
    if (value) {
      await NotificationService.subscribeToTopic(topic);
    } else {
      await NotificationService.unsubscribeFromTopic(topic);
    }

    if (key == 'notify_classroom') {
      try {
        final profile = await _apiService.getStudentProfile();
        if (profile != null) {
          if (value) {
            await NotificationService.subscribeToTopic(
              'faculty_${profile.facultyId}',
            );
          } else {
            await NotificationService.unsubscribeFromTopic(
              'faculty_${profile.facultyId}',
            );
          }
        }
      } catch (e) {
        debugPrint('Error syncing classroom topic: $e');
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will delete all cached images and data. They will be re-downloaded when needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clearing cache...')));

      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      try {
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          tempDir.listSync().forEach((entity) {
            try {
              entity.deleteSync(recursive: true);
            } catch (_) {}
          });
        }
      } catch (_) {}

      try {
        final box = Hive.box('api_cache');
        await box.clear();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All caches cleared successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _sendFeedback() async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: 'support@pulchowkx.com',
      query:
          'subject=App Feedback (v$_appVersion)&body=Type your feedback here...',
    );
    if (await canLaunchUrl(params)) {
      await launchUrl(params);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = AuthService.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: 100, // Extra space to clear the bottom navbar
        ),
        children: [
          const SizedBox(height: AppSpacing.sm),

          // ── Account Section ─────────────────────────────────────────────
          _buildSectionHeader('Account'),
          _buildAccountCard(user),

          const SizedBox(height: AppSpacing.lg),

          // ── Appearance Section ──────────────────────────────────────────
          _buildSectionHeader('Appearance'),
          _buildAppearanceCard(),

          const SizedBox(height: AppSpacing.lg),

          // ── Notifications Section ───────────────────────────────────────
          _buildSectionHeader('Notifications'),
          _buildNotificationCard(),

          const SizedBox(height: AppSpacing.lg),

          // ── Utilities Section ───────────────────────────────────────────
          _buildSectionHeader('Utilities'),
          _buildUtilityCard(),

          const SizedBox(height: AppSpacing.lg),

          // ── Info Section ────────────────────────────────────────────────
          _buildSectionHeader('Support & Legal'),
          _buildInfoCard(),

          const SizedBox(height: AppSpacing.xl),

          // ── Danger Zone ─────────────────────────────────────────────────
          _buildDangerZone(),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAccountCard(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.borderDark
                      : AppColors.borderLight)
                  .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          SmartImage(
            imageUrl: user?.photoURL,
            width: 60,
            height: 60,
            shape: BoxShape.circle,
            errorWidget: const Icon(
              Icons.person_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user?.displayName ?? 'Guest User',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _userRole.toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  user?.email ?? 'Sign in to sync your data',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard() {
    final themeProvider = ThemeProvider.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.borderDark
                      : AppColors.borderLight)
                  .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: themeProvider.themeModeIcon,
            title: 'Theme Mode',
            subtitle: themeProvider.themeModeLabel,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThemeOption(
                    icon: Icons.light_mode_rounded,
                    isSelected: themeProvider.themeMode == ThemeMode.light,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  ),
                  _ThemeOption(
                    icon: Icons.dark_mode_rounded,
                    isSelected: themeProvider.themeMode == ThemeMode.dark,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  ),
                  _ThemeOption(
                    icon: Icons.settings_brightness_rounded,
                    isSelected: themeProvider.themeMode == ThemeMode.system,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
            ),
          ),
          const _Divider(),
          _buildSettingsTile(
            icon: Icons.vibration_rounded,
            title: 'Haptic Feedback',
            subtitle: 'Provide tactile feedback on tap',
            trailing: Switch.adaptive(
              value: themeProvider.hapticsEnabled,
              activeTrackColor: AppColors.primary,
              onChanged: (val) async {
                await themeProvider.setHapticsEnabled(val);
                if (val) {
                  haptics.selectionClick();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.borderDark
                      : AppColors.borderLight)
                  .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildToggleTile(
            title: 'Upcoming Events',
            subtitle: 'Alerts for registration and starts',
            value: _eventsNotify,
            onChanged: (v) => _toggleNotification('notify_events', v),
            icon: Icons.event_rounded,
          ),
          const _Divider(),
          _buildToggleTile(
            title: 'Marketplace Alerts',
            subtitle: 'New requests and listings',
            value: _booksNotify,
            onChanged: (v) => _toggleNotification('notify_books', v),
            icon: Icons.shopping_bag_rounded,
          ),
          const _Divider(),
          _buildToggleTile(
            title: 'Campus Notices',
            subtitle: 'New university results & forms',
            value: _noticesNotify,
            onChanged: (v) => _toggleNotification('notify_notices', v),
            icon: Icons.campaign_rounded,
          ),
          const _Divider(),
          _buildToggleTile(
            title: 'University Announcements',
            subtitle: 'Official campus updates',
            value: _announcementsNotify,
            onChanged: (v) => _toggleNotification('notify_announcements', v),
            icon: Icons.campaign_rounded,
          ),
          const _Divider(),
          _buildToggleTile(
            title: 'Classroom Notifications',
            subtitle: 'Assignments and grades',
            value: _classroomNotify,
            onChanged: (v) => _toggleNotification('notify_classroom', v),
            icon: Icons.class_rounded,
          ),
          const _Divider(),
          _buildToggleTile(
            title: 'Chat Messages',
            subtitle: 'Real-time message alerts',
            value: _chatNotify,
            onChanged: (v) => _toggleNotification('notify_chat', v),
            icon: Icons.chat_bubble_rounded,
          ),
          const _Divider(),
          _buildToggleTile(
            title: 'Lost & Found',
            subtitle: 'New reported target items',
            value: _lostFoundNotify,
            onChanged: (v) => _toggleNotification('notify_lost_found', v),
            icon: Icons.find_in_page_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.borderDark
                      : AppColors.borderLight)
                  .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.cleaning_services_rounded,
            title: 'Clear Cache',
            subtitle: 'Free up local storage space',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: _clearCache,
          ),
          const _Divider(),
          _buildSettingsTile(
            icon: Icons.block_rounded,
            title: 'Blocked Users',
            subtitle: 'Manage ignored accounts',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () {
              haptics.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BlockedUsersPage(),
                ),
              );
            },
          ),
          const _Divider(),
          _buildSettingsTile(
            icon: Icons.report_gmailerrorred_rounded,
            title: 'My Reports',
            subtitle: 'View your reports status',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () {
              haptics.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyReportsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.borderDark
                      : AppColors.borderLight)
                  .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help Center',
            subtitle: 'FAQ and support contact',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () {
              haptics.selectionClick();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, animation, secondaryAnimation) =>
                      const HelpCenterPage(),
                  transitionsBuilder:
                      (_, animation, secondaryAnimation, child) {
                        final offsetTween = Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeOutCubic));
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: animation.drive(offsetTween),
                            child: child,
                          ),
                        );
                      },
                  transitionDuration: const Duration(milliseconds: 260),
                  reverseTransitionDuration: const Duration(milliseconds: 220),
                ),
              );
            },
          ),
          const _Divider(),
          _buildSettingsTile(
            icon: Icons.feedback_rounded,
            title: 'Send Feedback',
            subtitle: 'Tell us how to improve',
            trailing: const Icon(Icons.send_rounded, size: 18),
            onTap: _sendFeedback,
          ),
          const _Divider(),
          _buildSettingsTile(
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () {
              haptics.selectionClick();
            },
          ),
          const _Divider(),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About Smart Pulchowk',
            subtitle: 'Version $_appVersion',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Smart Pulchowk',
                applicationVersion: _appVersion,
                applicationLegalese: '© 2026 Developed for Pulchowk Campus',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset('assets/icons/logo.png', width: 48),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return InkWell(
      onTap: () async {
        haptics.heavyImpact();
        await AuthService.signOut();
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              color: Color(0xFFEF4444),
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Sign Out',
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return _buildSettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: value,
        activeTrackColor: AppColors.primary,
        onChanged: (v) {
          haptics.selectionClick();
          onChanged(v);
        },
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        haptics.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppColors.secondary,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 64,
      color:
          (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.borderDark
                  : AppColors.borderLight)
              .withValues(alpha: 0.5),
    );
  }
}
