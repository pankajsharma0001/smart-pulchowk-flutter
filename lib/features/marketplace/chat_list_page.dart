import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_pulchowk/features/home/main_layout.dart';
import 'package:smart_pulchowk/core/models/chat.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/notification_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/features/marketplace/chat_room_page.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'package:smart_pulchowk/core/widgets/empty_state.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ApiService _api = ApiService();
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _currentUserId;
  final Set<int> _selectedIds = {};
  StreamSubscription? _chatSubscription;
  StreamSubscription? _refreshSubscription;

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initChatList();
    _setupStreamListeners();
  }

  void _setupStreamListeners() {
    // Listen for incoming messages and refresh the conversation list
    _chatSubscription = NotificationService.chatStream.listen((_) {
      _loadConversations(forceRefresh: true);
    });
    _refreshSubscription = NotificationService.refreshStream.listen((_) {
      _loadConversations(forceRefresh: true);
    });
  }

  Future<void> _initChatList() async {
    _currentUserId = await StorageService.readSecure(AppConstants.dbUserIdKey);
    _loadConversations();
  }

  Future<void> _loadConversations({bool forceRefresh = false}) async {
    // Only show full loading indicator on first load, not on background refresh
    if (!forceRefresh) setState(() => _isLoading = true);
    if (forceRefresh) {
      // Bypass the cache so we get fresh unread counts and last messages
      await ApiService.invalidateConversationsCache();
    }
    final results = await _api.getConversations();
    if (mounted) {
      setState(() {
        _conversations = results;
        _isLoading = false;
        // Clean up selection if any of the conversations were removed
        _selectedIds.retainWhere((id) => _conversations.any((c) => c.id == id));
      });
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _refreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} conversations?'),
        content: const Text(
          'This will remove these conversations from your list. Other participants will still be able to see them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      int successCount = 0;
      for (final id in _selectedIds) {
        final res = await _api.deleteConversation(id);
        if (res['success'] == true) successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $successCount conversations')),
        );
        _selectedIds.clear();
        _loadConversations(
          forceRefresh: true,
        ); // bypass cache so deletions take effect
      }
    }
  }

  void _navigateToChat(Conversation conversation) async {
    final otherUser = conversation.getOtherParticipant(_currentUserId ?? '');
    if (otherUser == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomPage(
          conversationId: conversation.id,
          recipientId: otherUser.id,
          recipientName: otherUser.name,
          recipientImage: otherUser.image,
          listing: conversation.listing,
        ),
      ),
    );
    _loadConversations(forceRefresh: true); // Refresh on return with fresh data
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(date);
    } else if (difference.inDays < 7) {
      return DateFormat('E').format(date);
    } else {
      return DateFormat('MMM d').format(date);
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
        title: _isSelectionMode
            ? Text('${_selectedIds.length} selected')
            : const Text('Messages'),
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        elevation: 0,
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: () => setState(() => _selectedIds.clear()),
              child: const Text('Clear'),
            ),
            IconButton(
              onPressed: _bulkDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? _buildChatListSkeleton(isDark)
          : _conversations.isEmpty
          ? _buildEmptyState(isDark)
          : RefreshIndicator(
              onRefresh: () async {
                if (mounted) {
                  debugPrint('ChatListPage: Manual refresh. Syncing role...');
                  await MainLayout.of(context)?.refreshUserRole();
                }
                await _loadConversations(forceRefresh: true);
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  final otherUser = conversation.getOtherParticipant(
                    _currentUserId ?? '',
                  );
                  final lastMsg = conversation.lastMessage;
                  final isSelected = _selectedIds.contains(conversation.id);
                  final hasUnread = conversation.unreadCount > 0;

                  return GestureDetector(
                    onTap: () {
                      if (_isSelectionMode) {
                        setState(() {
                          if (isSelected) {
                            _selectedIds.remove(conversation.id);
                          } else {
                            _selectedIds.add(conversation.id);
                          }
                        });
                      } else {
                        _navigateToChat(conversation);
                      }
                    },
                    onLongPress: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(conversation.id);
                        } else {
                          _selectedIds.add(conversation.id);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : (isDark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight),
                        borderRadius: AppRadius.lgAll,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : (isDark ? Colors.white10 : Colors.black12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              SmartImage(
                                imageUrl: otherUser?.image,
                                width: 48,
                                height: 48,
                                shape: BoxShape.circle,
                                errorWidget: Center(
                                  child: Text(
                                    otherUser?.name[0].toUpperCase() ?? '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      otherUser?.name ?? 'Unknown User',
                                      style: AppTextStyles.labelLarge,
                                    ),
                                    if (lastMsg != null)
                                      Text(
                                        _formatDate(lastMsg.createdAt),
                                        style: AppTextStyles.labelSmall
                                            .copyWith(color: Colors.grey),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMsg?.content ?? 'No messages yet',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: hasUnread
                                                  ? (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                  : Colors.grey,
                                              fontWeight: hasUnread
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                      ),
                                    ),
                                    if (hasUnread)
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          conversation.unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (conversation.listing != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 60,
                                          ),
                                          child: Text(
                                            conversation.listing!.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildChatListSkeleton(bool isDark) {
    return ShimmerWrapper(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              const Skeleton(height: 48, width: 48, borderRadius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Skeleton(height: 16, width: 100),
                        const Skeleton(height: 12, width: 40),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Skeleton(height: 14, width: double.infinity),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return const EmptyState(
      title: 'No conversations yet',
      subtitle: 'Start chatting with sellers or buyers!',
    );
  }
}
