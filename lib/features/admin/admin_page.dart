import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/models/admin.dart';
import 'package:smart_pulchowk/features/admin/widgets/admin_users_tab.dart';
import 'package:smart_pulchowk/features/admin/widgets/admin_moderation_tab.dart';
import 'package:smart_pulchowk/features/admin/widgets/admin_blocks_tab.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text(
            'Admin Control Center',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.secondary,
            unselectedLabelColor: AppColors.textSecondary.withValues(
              alpha: 0.7,
            ),
            indicatorColor: AppColors.secondary,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'User Roles'),
              Tab(text: 'Moderation'),
              Tab(text: 'Blocks'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            AdminOverviewTab(),
            AdminUsersTab(),
            AdminModerationTab(),
            AdminBlocksTab(),
          ],
        ),
      ),
    );
  }
}

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardStats?>(
      future: ApiService().getAdminOverview(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Failed to load admin overview'));
        }

        final stats = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh logic would go here if needed
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage users, verify sellers, and moderate content to keep the platform safe.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard(
                      context,
                      'Total Users',
                      stats.users.toString(),
                      '${stats.teachers} Teachers',
                      const Color(0xFF7C3AED), // violet-600
                      Icons.people_alt_rounded,
                    ),
                    _buildStatCard(
                      context,
                      'Active Listings',
                      stats.listingsAvailable.toString(),
                      'Marketplace is active',
                      const Color(0xFF059669), // emerald-600
                      Icons.shopping_bag_rounded,
                    ),
                    _buildStatCard(
                      context,
                      'Open Reports',
                      stats.openReports.toString(),
                      '${stats.activeBlocks} blocked users',
                      stats.openReports > 0
                          ? const Color(0xFFD97706)
                          : AppColors.primary,
                      Icons.report_problem_rounded,
                    ),
                    _buildStatCard(
                      context,
                      'Avg Rating',
                      stats.averageSellerRating.toStringAsFixed(1),
                      '${stats.ratingsCount} reviews total',
                      AppColors.info,
                      Icons.star_rounded,
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

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // In dark mode, use the color as the text/icon color but make it lighter
    // In light mode, use a faint version for background and dark version for text
    final Color displayColor = isDark
        ? Color.lerp(color, Colors.white, 0.4)!
        : color;
    final Color iconBackgroundColor = isDark
        ? color.withValues(alpha: 0.2)
        : color.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.borderDark.withValues(alpha: 0.5)
              : color.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: displayColor),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.textPrimaryDark : displayColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.textMutedDark
                      : displayColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
