import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';

class AdminBlocksTab extends StatefulWidget {
  const AdminBlocksTab({super.key});

  @override
  State<AdminBlocksTab> createState() => _AdminBlocksTabState();
}

class _AdminBlocksTabState extends State<AdminBlocksTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<BlockedUser> _blocks = [];
  bool _isLoading = true;
  int? _busyBlockId;

  @override
  void initState() {
    super.initState();
    _fetchBlocks();
  }

  Future<void> _fetchBlocks() async {
    setState(() => _isLoading = true);
    final blocks = await ApiService().getAdminBlocks();
    setState(() {
      _blocks = blocks;
      _isLoading = false;
    });
  }

  Future<void> _unblockUser(BlockedUser block) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User?'),
        content: Text(
          'Are you sure you want to unblock ${block.blockedUser?.name ?? 'this user'}? they will regain full access to the platform.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      setState(() => _busyBlockId = block.id);
      final result = await ApiService().unblockUserByAdmin(block.id);
      setState(() => _busyBlockId = null);

      if (result.success) {
        _fetchBlocks();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to unblock user')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.block_flipped, color: AppColors.error),
              const SizedBox(width: 8),
              const Text(
                'Platform-wide Blocks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _fetchBlocks,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const ShimmerAdminBlocks()
              : _blocks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 64,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No blocked users found',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 100,
                  ),
                  itemCount: _blocks.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  itemBuilder: (context, index) {
                    final block = _blocks[index];
                    final isBusy = _busyBlockId == block.id;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDark
                            ? AppColors.error.withValues(alpha: 0.2)
                            : AppColors.errorContainer,
                        backgroundImage: block.blockedUser?.image != null
                            ? CachedNetworkImageProvider(
                                ApiService.processImageUrl(
                                  block.blockedUser!.image,
                                )!,
                              )
                            : null,
                        child: block.blockedUser?.image == null
                            ? const Icon(
                                Icons.person_off_rounded,
                                color: AppColors.error,
                              )
                            : null,
                      ),
                      title: Text(
                        block.blockedUser?.name ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            block.blockedUser?.email ?? 'No email',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          if (block.reason != null)
                            Text(
                              'Reason: ${block.reason}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          Text(
                            'Blocked on: ${DateFormat('MMM d, yyyy').format(block.createdAt)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      trailing: isBusy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.undo_rounded),
                              onPressed: () => _unblockUser(block),
                              tooltip: 'Unblock User',
                              color: AppColors.primary,
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ShimmerAdminBlocks extends StatelessWidget {
  const ShimmerAdminBlocks({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
      itemCount: 5,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
      ),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ShimmerWrapper(
            child: Row(
              children: [
                const Skeleton(width: 40, height: 40, shape: BoxShape.circle),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(height: 14, width: 140, borderRadius: 4),
                      const SizedBox(height: 6),
                      Skeleton(height: 12, width: 180, borderRadius: 4),
                      const SizedBox(height: 4),
                      Skeleton(height: 10, width: 100, borderRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Skeleton(width: 24, height: 24, borderRadius: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}
