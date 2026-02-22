import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/widgets/logo_card.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:smart_pulchowk/features/search/search.dart';
import 'package:smart_pulchowk/features/notifications/notifications.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_pulchowk/features/settings/help_center_page.dart';

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
  final String? title;
  final bool showBackButton;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    this.isHomePage = false,
    this.currentPage,
    this.userRole,
    this.title,
    this.showBackButton = false,
    this.actions,
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
          height: 60,
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
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? AppSpacing.sm : AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                // Logo and Brand
                if (showBackButton)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTextStyles.h4.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  _BrandLogo(isHomePage: isHomePage),

                if (title == null) const Spacer(),

                // Actions
                if (actions != null)
                  ...actions!
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
              PageRouteBuilder(
                pageBuilder: (_, animation, secondaryAnimation) =>
                    const NotificationsPage(),
                transitionsBuilder: (_, animation, secondaryAnimation, child) {
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
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
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
          value: 'share',
          child: _ProfileMenuItem(
            icon: Icons.share_outlined,
            label: 'Share App',
            onTap: () async {
              haptics.selectionClick();
              await SharePlus.instance.share(
                ShareParams(
                  text:
                      'Join me on the Smart Pulchowk app! Stay connected with campus events, clubs, and announcements. Download now!\n\nhttps://smartpulchowk.com',
                ),
              );
            },
          ),
        ),
        PopupMenuItem<String>(
          value: 'help',
          child: _ProfileMenuItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () {
              haptics.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterPage()),
              );
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
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );
              await AuthService.signOut();
              // No need to pop the dialog manually because signing out usually changes
              // the root auth state, navigating the user entirely away to the login screen.
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
          child: SmartImage(
            imageUrl: widget.photoUrl,
            width: 28,
            height: 28,
            shape: BoxShape.circle,
            errorWidget: const Icon(Icons.person, size: 16),
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
  final bool isDestructive;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
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
          ],
        ),
      ),
    );
  }
}
