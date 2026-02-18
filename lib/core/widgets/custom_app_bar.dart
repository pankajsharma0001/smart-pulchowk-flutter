import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/widgets/logo_card.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:smart_pulchowk/features/search/search.dart';
import 'package:smart_pulchowk/features/notifications/notifications.dart';
import 'package:smart_pulchowk/core/theme/theme_provider.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/auth_service.dart';

enum AppPage {
  home,
  clubs,
  events,
  map,
  dashboard,
  bookMarketplace,
  classroom,
  notices,
  login,
  notifications,
  lostAndFound,
  settings,
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isHomePage;
  final AppPage? currentPage;
  final String? userRole;

  const CustomAppBar({
    super.key,
    this.isHomePage = false,
    this.currentPage,
    this.userRole,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data != null;
        final user = snapshot.data;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).appBarTheme.backgroundColor,
            border: Border(
              bottom: BorderSide(
                color:
                    (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.borderDark
                            : AppColors.borderLight)
                        .withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? AppSpacing.sm : AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  // Logo and Brand
                  _BrandLogo(isHomePage: isHomePage),

                  const Spacer(),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _ThemeToggleButton(),
                      _SearchButton(currentPage: currentPage),
                      _NotificationBell(
                        isActive: currentPage == AppPage.notifications,
                      ),
                      if (!isSmallScreen) const SizedBox(width: AppSpacing.sm),
                      if (isLoggedIn)
                        _UserAvatar(
                          photoUrl: user?.photoURL,
                          displayName: user?.displayName,
                          userRole: userRole,
                        )
                      else
                        _SignInButton(
                          isActive: currentPage == AppPage.login,
                          onTap: () => _navigateToLogin(context, currentPage),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _navigateToLogin(BuildContext context, AppPage? currentPage) {
    if (currentPage == AppPage.login) return;
    final mainLayout = MainLayout.of(context);
    if (mainLayout != null) {
      // Login is usually handled by AuthWrapper, but we can switch to profile tab
      mainLayout.setSelectedIndex(4);
    }
  }
}

class _BrandLogo extends StatelessWidget {
  final bool isHomePage;

  const _BrandLogo({required this.isHomePage});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          haptics.lightImpact();
          if (isHomePage) return;
          final mainLayout = MainLayout.of(context);
          if (mainLayout != null) {
            mainLayout.setSelectedIndex(0);
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoCard(width: 32, height: 32, useHero: false),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Smart Pulchowk',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          themeProvider.themeModeIcon,
          size: 20,
          color: AppColors.secondary,
        ),
      ),
      onPressed: () {
        haptics.selectionClick();
        themeProvider.toggleTheme();
      },
      tooltip: 'Theme: ${themeProvider.themeModeLabel}',
    );
  }
}

class _SearchButton extends StatelessWidget {
  final AppPage? currentPage;

  const _SearchButton({this.currentPage});

  @override
  Widget build(BuildContext context) {
    if (currentPage == AppPage.home) return const SizedBox.shrink();

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.primary,
        ),
      ),
      onPressed: () {
        haptics.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchPage()),
        );
      },
    );
  }
}

class _NotificationBell extends StatefulWidget {
  final bool isActive;

  const _NotificationBell({this.isActive = false});

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  final ApiService _api = ApiService();
  int _unreadCount = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    // Periodically fetch in background while app is active
    _startPeriodicFetch();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _startPeriodicFetch() async {
    while (!_isDisposed) {
      await Future.delayed(const Duration(minutes: 2));
      if (!_isDisposed && mounted) {
        _fetchUnreadCount();
      }
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final notifications = await _api.getNotifications();
      if (mounted) {
        setState(() {
          _unreadCount = notifications.where((n) => !n.isRead).length;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(
            widget.isActive
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: widget.isActive ? AppColors.primary : null,
          ),
          onPressed: () async {
            haptics.selectionClick();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsPage(),
              ),
            );
            // Refresh count when returning
            _fetchUnreadCount();
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      Theme.of(context).appBarTheme.backgroundColor ??
                      Colors.transparent,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserAvatar extends StatefulWidget {
  final String? photoUrl;
  final String? displayName;
  final String? userRole;

  const _UserAvatar({this.photoUrl, this.displayName, this.userRole});

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<_UserAvatar> {
  bool _isMenuOpen = false;

  void _showProfileMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    setState(() {
      _isMenuOpen = true;
    });

    await showMenu<String>(
      context: context,
      position: position.shift(const Offset(0, 48)), // Shift below avatar
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.borderDark
                      : AppColors.borderLight)
                  .withValues(alpha: 0.1),
        ),
      ),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111827) // Dark grayish blue
          : Colors.white,
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: _ProfileMenuHeader(
            name: widget.displayName ?? 'User',
            role: widget.userRole ?? 'Student',
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'settings',
          child: _ProfileMenuItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () =>
                MainLayout.of(context)?.setSelectedIndex(10), // Settings index
          ),
        ),
        PopupMenuItem<String>(
          value: 'notifications',
          child: _ProfileMenuItem(
            icon: Icons.notifications_none_outlined,
            label: 'Notifications',
            trailing: const _NewBadge(count: 4),
            onTap: () =>
                MainLayout.of(context)?.setSelectedIndex(8), // Notices index
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          child: _ProfileMenuItem(
            icon: Icons.share_outlined,
            label: 'Share App',
            onTap: () {
              // Share logic placeholder
            },
          ),
        ),
        PopupMenuItem<String>(
          value: 'help',
          child: _ProfileMenuItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () {
              // Help logic placeholder
            },
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'logout',
          child: _ProfileMenuItem(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            isDestructive: true,
            onTap: () async {
              haptics.heavyImpact();
              await AuthService.signOut();
            },
          ),
        ),
      ],
    );

    if (mounted) {
      setState(() {
        _isMenuOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          haptics.selectionClick();
          _showProfileMenu(context);
        },
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(
                alpha: _isMenuOpen ? 1.0 : 0.5,
              ),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 14,
            backgroundImage: widget.photoUrl != null
                ? CachedNetworkImageProvider(widget.photoUrl!)
                : null,
            child: widget.photoUrl == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _SignInButton({required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        haptics.lightImpact();
        onTap();
      },
      icon: const Icon(Icons.login_rounded, size: 18),
      label: const Text('Sign In'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ProfileMenuHeader extends StatelessWidget {
  final String name;
  final String role;

  const _ProfileMenuHeader({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            '${role.toUpperCase()} · IOE Pulchowk',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFEF4444) : null;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  final int count;

  const _NewBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$count new',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF6366F1),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
