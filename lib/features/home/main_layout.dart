import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/widgets/custom_app_bar.dart';
import 'package:smart_pulchowk/features/home/home_page.dart';
import 'package:smart_pulchowk/features/notifications/notifications.dart';
import 'package:smart_pulchowk/features/settings/settings.dart';
import 'package:smart_pulchowk/features/marketplace/book_marketplace_page.dart';
import 'package:smart_pulchowk/features/classroom/classroom_page.dart';

// ── Placeholder pages (will be replaced as features are built) ──────────────
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Coming soon',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN LAYOUT
// ─────────────────────────────────────────────────────────────────────────────

class MainLayout extends StatefulWidget {
  final int initialIndex;
  const MainLayout({super.key, this.initialIndex = 0});

  /// Global key to access MainLayoutState from anywhere (e.g., NotificationService)
  static final GlobalKey<MainLayoutState> mainLayoutKey =
      GlobalKey<MainLayoutState>();

  /// Access the [MainLayoutState] from a descendant widget.
  static MainLayoutState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainLayoutState>();

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late int _selectedIndex;
  String _userRole = 'student';
  final ApiService _apiService = ApiService();

  // Menu Animation
  late AnimationController _menuController;
  late Animation<double> _menuAnimation;
  bool _isMenuOpen = false;

  /// ValueNotifier to notify children when tab changes.
  final ValueNotifier<int> tabIndexNotifier = ValueNotifier<int>(0);

  /// Expose the current selected tab index.
  int get currentIndex => _selectedIndex;

  // Navigator keys for each tab's independent navigation stack
  // We expand this to support all menu features (10 total)
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    12,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex;
    tabIndexNotifier.value = _selectedIndex;

    _menuController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            setState(() {}); // Remove from stack when closed
          }
        });
    _menuAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutBack,
    );

    _checkUserRole();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _apiService.refreshUserRole().then((_) => _checkUserRole());
    }
  }

  Future<void> _checkUserRole() async {
    final role = await _apiService.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabIndexNotifier.dispose();
    _menuController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        haptics.mediumImpact();
        _menuController.forward();
      } else {
        _menuController.reverse();
      }
    });
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
        _menuController.reverse();
      });
    }
  }

  /// Public method to switch tabs programmatically.
  void setSelectedIndex(int index) {
    _closeMenu();
    if (_selectedIndex == index) {
      // If tapping the same tab, pop to root of that tab
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
        tabIndexNotifier.value = index;
      });
    }
  }

  /// Navigate to a specific tab and optionally push a sub-page.
  void navigateToTab(int index, {Widget? subPage}) {
    setSelectedIndex(index);
    if (subPage != null) {
      // Short delay to allow IndexedStack to switch if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKeys[index].currentState?.push(
          MaterialPageRoute(builder: (_) => subPage),
        );
      });
    }
  }

  // Pages for each tab
  Widget _pageForIndex(int index) {
    switch (index) {
      case 0:
        return const HomePage();
      case 1:
        return const _PlaceholderPage(title: 'Map', icon: Icons.map_rounded);
      case 2:
        if (_userRole == 'admin') {
          return const _PlaceholderPage(
            title: 'Admin',
            icon: Icons.admin_panel_settings_rounded,
          );
        } else if (_userRole == 'notice manager') {
          return const NotificationsPage();
        }
        return const ClassroomPage();
      case 3:
        return const BookMarketplacePage();
      case 4:
        return const _PlaceholderPage(
          title: 'Profile',
          icon: Icons.person_rounded,
        );
      case 5:
        return const _PlaceholderPage(
          title: 'Clubs',
          icon: Icons.groups_rounded,
        );
      case 6:
        return const _PlaceholderPage(
          title: 'Events',
          icon: Icons.event_rounded,
        );
      case 7:
        return const _PlaceholderPage(
          title: 'Admin Dashboard',
          icon: Icons.dashboard_customize_rounded,
        );
      case 8:
        return const NotificationsPage(); // Notices mapping to NotificationPage for now
      case 9:
        return const _PlaceholderPage(
          title: 'Lost & Found',
          icon: Icons.search_rounded,
        );
      case 10:
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  AppPage _getCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return AppPage.home;
      case 1:
        return AppPage.map;
      case 2:
        if (_userRole == 'admin') return AppPage.dashboard;
        return AppPage.classroom;
      case 3:
        return AppPage.bookMarketplace;
      case 4:
        return AppPage.dashboard;
      case 5:
        return AppPage.home; // Clubs (placeholder)
      case 6:
        return AppPage.home; // Events (placeholder)
      case 7:
        return AppPage.dashboard; // Admin Dashboard
      case 8:
        return AppPage.notifications; // Notices
      case 9:
        return AppPage.home; // Lost & Found
      case 10:
        return AppPage.settings;
      default:
        return AppPage.home;
    }
  }

  IconData _getCenterIcon() {
    // If a submenu page is selected, show its specific icon
    switch (_selectedIndex) {
      case 2:
        if (_userRole == 'admin') return Icons.admin_panel_settings_rounded;
        if (_userRole == 'notice manager') {
          return Icons.notifications_active_rounded;
        }
        return Icons.school_rounded;
      case 5:
        return Icons.groups_rounded;
      case 6:
        return Icons.event_rounded;
      case 7:
        return Icons.dashboard_customize_rounded;
      case 8:
        return Icons.notifications_active_rounded;
      case 9:
        return Icons.search_rounded;
      case 10:
        return Icons.settings_rounded;
    }

    // Default role-based icon for main tabs (Home, Map, Books, Profile)
    if (_userRole == 'admin') {
      return Icons.admin_panel_settings_rounded;
    }
    if (_userRole == 'notice manager') {
      return Icons.notifications_active_rounded;
    }
    return Icons.grid_view_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isMenuOpen) {
          _closeMenu();
          return;
        }

        final NavigatorState? currentNavigator =
            _navigatorKeys[_selectedIndex].currentState;

        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else if (_selectedIndex != 0) {
          // Go back to Home tab
          setState(() {
            _selectedIndex = 0;
            tabIndexNotifier.value = 0;
          });
        } else {
          SystemNavigator.pop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            resizeToAvoidBottomInset: false,
            extendBody: true,
            extendBodyBehindAppBar: true,
            appBar: CustomAppBar(
              isHomePage: _selectedIndex == 0,
              currentPage: _getCurrentPage(),
              userRole: _userRole,
            ),
            body: IndexedStack(
              index: _selectedIndex,
              children: List.generate(
                12,
                (i) => _TabNavigator(
                  key: i == 2 ? ValueKey('role_$_userRole') : null,
                  navigatorKey: _navigatorKeys[i],
                  rootPage: _pageForIndex(i),
                ),
              ),
            ),
            bottomNavigationBar: _BottomNavBar(
              selectedIndex: _selectedIndex,
              onItemSelected: setSelectedIndex,
            ),
          ),

          // ── Quick Menu Overlay ──────────────────────────────────────
          if (_isMenuOpen || !_menuController.isDismissed)
            _QuickMenu(
              animation: _menuAnimation,
              isMenuOpen: _isMenuOpen,
              selectedIndex: _selectedIndex,
              userRole: _userRole,
              onClose: _closeMenu,
              onItemSelected: setSelectedIndex,
            ),

          // ── Floating center button (Root level to avoid blur) ───────
          Positioned(
            bottom: (MediaQuery.of(context).padding.bottom + 65.0) - 36,
            left: (MediaQuery.of(context).size.width - 55) / 2,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedBuilder(
                animation: _menuAnimation,
                builder: (context, child) {
                  return Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6366F1), // Indigo
                          Color(0xFF818CF8), // Lighter indigo
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: Offset(0, 6 * (1 - _menuAnimation.value)),
                        ),
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Transform.rotate(
                      angle: _menuAnimation.value * (3.14159 / 4), // 45 deg
                      child: AnimatedScale(
                        duration: AppAnimations.fast,
                        scale:
                            ([2, 5, 6, 7, 8, 9, 10].contains(_selectedIndex) ||
                                _isMenuOpen)
                            ? 1.1
                            : 1.0,
                        child: AnimatedSwitcher(
                          duration: AppAnimations.fast,
                          child: Icon(
                            _isMenuOpen ? Icons.add_rounded : _getCenterIcon(),
                            key: ValueKey(
                              _isMenuOpen
                                  ? Icons.add_rounded
                                  : _getCenterIcon(),
                            ),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB NAVIGATOR
// ─────────────────────────────────────────────────────────────────────────────

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;

  const _TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.rootPage,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => rootPage,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV BAR — Dark glass with floating center button
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final barHeight = 65.0 + bottomPadding;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0D1321).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : Colors.black.withValues(alpha: 0.05);

    final totalWidth = MediaQuery.of(context).size.width;
    final itemWidth = totalWidth / 5;

    final indicatorIndex = [0, 1, 3, 4].contains(selectedIndex)
        ? selectedIndex
        : 2;

    return SizedBox(
      height: barHeight,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(top: BorderSide(color: borderColor, width: 0.5)),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
            ),
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Stack(
              children: [
                // ── Sliding Indicator Pill ──
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  left: indicatorIndex * itemWidth + (itemWidth - 48) / 2,
                  top: (65.0 - 52.0) / 2,
                  child: Container(
                    width: 48,
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                          (isDark ? const Color(0xFF818CF8) : AppColors.primary)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // Icons Row
                Row(
                  children: [
                    // Left side: Home + Map
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: Icons.home_outlined,
                              activeIcon: Icons.home_rounded,
                              label: 'Home',
                              isActive: selectedIndex == 0,
                              onTap: () => onItemSelected(0),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.navigation_outlined,
                              activeIcon: Icons.navigation_rounded,
                              label: 'Map',
                              isActive: selectedIndex == 1,
                              onTap: () => onItemSelected(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Center gap for floating button
                    SizedBox(width: itemWidth),
                    // Right side: Books + Profile
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: Icons.auto_stories_outlined,
                              activeIcon: Icons.auto_stories_rounded,
                              label: 'Books',
                              isActive: selectedIndex == 3,
                              onTap: () => onItemSelected(3),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.person_outline_rounded,
                              activeIcon: Icons.person_rounded,
                              label: 'Profile',
                              isActive: selectedIndex == 4,
                              onTap: () => onItemSelected(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK MENU OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

class _QuickMenu extends StatelessWidget {
  final Animation<double> animation;
  final bool isMenuOpen;
  final int selectedIndex;
  final String userRole;
  final VoidCallback onClose;
  final Function(int) onItemSelected;

  const _QuickMenu({
    required this.animation,
    required this.isMenuOpen,
    required this.selectedIndex,
    required this.userRole,
    required this.onClose,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final shouldIgnore = animation.value == 0 && !isMenuOpen;

        return IgnorePointer(
          ignoring: shouldIgnore,
          child: Stack(
            children: [
              // Tap area to close
              GestureDetector(
                onTap: onClose,
                child: FadeTransition(
                  opacity: animation,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: 10 * animation.value,
                        sigmaY: 10 * animation.value,
                      ),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              ),

              // Menu Items
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 85,
                    left: 24,
                    right: 24,
                  ),
                  child: FadeTransition(
                    opacity: animation,
                    child: Transform.translate(
                      offset: Offset(0, 40 * (1 - animation.value)),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: _buildGrid(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    final List<_QuickMenuItemData> items = [
      _QuickMenuItemData(
        icon: Icons.school_rounded,
        label: 'Classroom',
        index: 2,
        color: const Color(0xFF6366F1),
      ),
      _QuickMenuItemData(
        icon: Icons.notifications_active_rounded,
        label: 'Notices',
        index: 8,
        color: const Color(0xFFF59E0B),
      ),
      _QuickMenuItemData(
        icon: Icons.event_rounded,
        label: 'Events',
        index: 6,
        color: const Color(0xFFEC4899),
      ),
      _QuickMenuItemData(
        icon: Icons.groups_rounded,
        label: 'Clubs',
        index: 5,
        color: const Color(0xFF10B981),
      ),
      _QuickMenuItemData(
        icon: Icons.search_rounded,
        label: 'Lost & Found',
        index: 9,
        color: const Color(0xFF8B5CF6),
      ),
      _QuickMenuItemData(
        icon: Icons.settings_rounded,
        label: 'Settings',
        index: 10,
        color: const Color(0xFF64748B),
      ),
    ];

    if (userRole == 'admin') {
      items.add(
        _QuickMenuItemData(
          icon: Icons.dashboard_customize_rounded,
          label: 'Admin Panel',
          index: 7,
          color: const Color(0xFFEF4444),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      physics: const NeverScrollableScrollPhysics(),
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return _QuickMenuItem(
          data: item,
          isActive: selectedIndex == item.index,
          onTap: () => onItemSelected(item.index),
          delay: i * 0.05,
          animation: animation,
        );
      }).toList(),
    );
  }
}

class _QuickMenuItemData {
  final IconData icon;
  final String label;
  final int index;
  final Color color;
  const _QuickMenuItemData({
    required this.icon,
    required this.label,
    required this.index,
    required this.color,
  });
}

class _QuickMenuItem extends StatelessWidget {
  final _QuickMenuItemData data;
  final bool isActive;
  final VoidCallback onTap;
  final double delay;
  final Animation<double> animation;

  const _QuickMenuItem({
    required this.data,
    required this.isActive,
    required this.onTap,
    required this.delay,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        haptics.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isActive ? data.color : data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? data.color
                    : data.color.withValues(alpha: 0.2),
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: data.color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              data.icon,
              color: isActive ? Colors.white : data.color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: isActive ? data.color : null,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEM — Outlined icon + label
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark
        ? const Color(0xFF818CF8) // Dark mode: light indigo
        : AppColors.primary; // Light mode: primary purple/indigo
    final inactiveColor = isDark
        ? const Color(0xFF64748B) // Dark mode: slate-500
        : Colors.black.withValues(alpha: 0.4); // Light mode: faded black

    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: () {
        haptics.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              scale: isActive ? 1.2 : 1.0,
              child: AnimatedSwitcher(
                duration: AppAnimations.fast,
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: color,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
