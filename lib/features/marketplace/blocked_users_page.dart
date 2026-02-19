import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final ApiService _api = ApiService();
  List<BlockedUser> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    final users = await _api.getBlockedMarketplaceUsers();
    if (mounted) {
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Unblock',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _api.unblockMarketplaceUser(userId);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Unblocked $name')));
          _loadBlockedUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to unblock')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _blockedUsers.length,
              itemBuilder: (context, index) {
                final blocked = _blockedUsers[index];
                final user = blocked.blockedUser;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: ListTile(
                    leading: SmartImage(
                      imageUrl: user?.image,
                      width: 40,
                      height: 40,
                      shape: BoxShape.circle,
                      errorWidget: const Icon(Icons.person),
                    ),
                    title: Text(
                      user?.name ?? 'Unknown User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      blocked.reason != null && blocked.reason!.isNotEmpty
                          ? 'Reason: ${blocked.reason}'
                          : 'No reason provided',
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        haptics.selectionClick();
                        _unblockUser(
                          blocked.blockedUserId,
                          user?.name ?? 'User',
                        );
                      },
                      child: const Text('Unblock'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block_rounded,
            size: 64,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No blocked users',
            style: AppTextStyles.h4.copyWith(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users you block will appear here',
            style: AppTextStyles.bodyMedium.copyWith(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
