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
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Admin Control Center',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.textSecondary.withOpacity(0.7),
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
                const Text(
                  'Platform Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage users, verify sellers, and moderate content to keep the platform safe.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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
                      'Total Users',
                      stats.users.toString(),
                      '${stats.teachers} Teachers',
                      const Color(0xFFEDE9FE), // violet-100
                      const Color(0xFF7C3AED), // violet-600
                      Icons.people_alt_rounded,
                    ),
                    _buildStatCard(
                      'Active Listings',
                      stats.listingsAvailable.toString(),
                      'Marketplace is active',
                      const Color(0xFFDCFCE7), // emerald-100
                      const Color(0xFF059669), // emerald-600
                      Icons.shopping_bag_rounded,
                    ),
                    _buildStatCard(
                      'Open Reports',
                      stats.openReports.toString(),
                      '${stats.activeBlocks} blocked users',
                      const Color(0xFFFEF3C7), // amber-100
                      stats.openReports > 0
                          ? const Color(0xFFD97706)
                          : AppColors.textPrimary,
                      Icons.report_problem_rounded,
                    ),
                    _buildStatCard(
                      'Avg Rating',
                      stats.averageSellerRating.toStringAsFixed(1),
                      '${stats.ratingsCount} reviews total',
                      AppColors.infoContainer,
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
    String title,
    String value,
    String subtitle,
    Color bgColor,
    Color textColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: textColor),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textColor,
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
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withOpacity(0.8),
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
