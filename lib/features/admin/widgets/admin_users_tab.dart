import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/models/admin.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = '';
  List<AdminUser> _users = [];
  bool _isLoading = true;
  String? _busyUserId;

  final List<String> _roleOptions = [
    'student',
    'teacher',
    'admin',
    'notice_manager',
    'guest',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final users = await ApiService().getAdminUsers(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      role: _selectedRole.isEmpty ? null : _selectedRole,
      limit: 100,
    );
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _updateRole(AdminUser user, String newRole) async {
    if (user.role == newRole) return;

    setState(() => _busyUserId = user.id);
    final result = await ApiService().updateAdminUserRole(user.id, newRole);
    setState(() => _busyUserId = null);

    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Role updated for ${user.name}')));
      _fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to update role')),
      );
    }
  }

  Future<void> _toggleVerification(AdminUser user, bool verified) async {
    setState(() => _busyUserId = user.id);
    final result = await ApiService().toggleSellerVerification(
      user.id,
      verified,
    );
    setState(() => _busyUserId = null);

    if (result.success) {
      _fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to update verification'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onSubmitted: (_) => _fetchUsers(),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Filter by Role',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      dropdownColor: isDark
                          ? AppColors.surfaceContainerDark
                          : AppColors.surfaceContainerLight,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All Roles'),
                        ),
                        ..._roleOptions.map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(
                              role[0].toUpperCase() + role.substring(1),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedRole = val ?? '');
                        _fetchUsers();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _fetchUsers,
                    icon: const Icon(Icons.refresh),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.surfaceContainerHighDark
                          : AppColors.surfaceContainerLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? const Center(child: Text('No users found'))
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 100,
                  ),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 64,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isBusy = _busyUserId == user.id;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: isDark
                            ? AppColors.surfaceContainerHighDark
                            : AppColors.surfaceContainerHighLight,
                        backgroundImage: user.image != null
                            ? CachedNetworkImageProvider(
                                ApiService.processImageUrl(user.image)!,
                              )
                            : null,
                        child: user.image == null
                            ? Text(user.name[0].toUpperCase())
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isVerifiedSeller)
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: AppColors.success,
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.surfaceContainerHighDark
                                      : AppColors.surfaceContainerLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user.role.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: isBusy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_note_rounded),
                                  onPressed: () => _showRolePicker(user),
                                  tooltip: 'Change Role',
                                ),
                                IconButton(
                                  icon: Icon(
                                    user.isVerifiedSeller
                                        ? Icons.verified_user
                                        : Icons.verified_user_outlined,
                                    color: user.isVerifiedSeller
                                        ? AppColors.success
                                        : null,
                                  ),
                                  onPressed: () => _toggleVerification(
                                    user,
                                    !user.isVerifiedSeller,
                                  ),
                                  tooltip: user.isVerifiedSeller
                                      ? 'Revoke Verification'
                                      : 'Verify Seller',
                                ),
                              ],
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showRolePicker(AdminUser user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Text(
                      'Update Role:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      user.name,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ..._roleOptions.map(
                (role) => ListTile(
                  leading: Icon(
                    Icons.person_outline,
                    color: user.role == role ? AppColors.secondary : null,
                  ),
                  title: Text(
                    role[0].toUpperCase() + role.substring(1),
                    style: TextStyle(
                      fontWeight: user.role == role ? FontWeight.bold : null,
                      color: user.role == role ? AppColors.secondary : null,
                    ),
                  ),
                  trailing: user.role == role
                      ? const Icon(Icons.check, color: AppColors.secondary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _updateRole(user, role);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
