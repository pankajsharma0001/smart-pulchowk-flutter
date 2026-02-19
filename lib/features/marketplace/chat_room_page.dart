import 'package:flutter/material.dart';
import 'package:smart_pulchowk/core/widgets/smart_image.dart';
import 'package:smart_pulchowk/core/models/chat.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/services/notification_service.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/features/marketplace/book_details_page.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:smart_pulchowk/core/widgets/shimmer_loading.dart';
import 'dart:async';

class ChatRoomPage extends StatefulWidget {
  final int? conversationId;
  final String recipientId;
  final String recipientName;
  final String? recipientImage;
  final BookListing? listing;

  const ChatRoomPage({
    super.key,
    this.conversationId,
    required this.recipientId,
    required this.recipientName,
    this.recipientImage,
    this.listing,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ApiService _api = ApiService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  int? _activeConversationId;
  Timer? _pollTimer;
  StreamSubscription? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _initChat();
    _listenForMessages();
  }

  void _listenForMessages() {
    _chatSubscription = NotificationService.chatStream.listen((data) {
      final notificationConvId = int.tryParse(data['conversationId'] ?? '');
      if (notificationConvId != null &&
          notificationConvId == _activeConversationId) {
        debugPrint('Real-time chat update triggered by notification');
        _loadMessages(refresh: true);
      }
    });
  }

  Future<void> _initChat() async {
    _currentUserId = await StorageService.readSecure(AppConstants.dbUserIdKey);
    _activeConversationId = widget.conversationId;

    // If we don't have a conversation ID but we have a listing,
    // try to find an existing conversation for this listing and recipient.
    if (_activeConversationId == null && widget.listing != null) {
      try {
        final conversations = await _api.getConversations();
        for (var conv in conversations) {
          if (conv.listingId == widget.listing!.id &&
              (conv.buyerId == widget.recipientId ||
                  conv.sellerId == widget.recipientId)) {
            _activeConversationId = conv.id;
            break;
          }
        }
      } catch (e) {
        debugPrint('Error finding existing conversation: $e');
      }
    }

    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _chatSubscription?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_activeConversationId != null) {
        _loadMessages(refresh: true);
      }
    });
  }

  Future<void> _loadMessages({bool refresh = false}) async {
    if (_activeConversationId == null) {
      if (!refresh) setState(() => _isLoading = false);
      return;
    }

    if (!refresh) setState(() => _isLoading = true);

    final results = await _api.getMessages(
      _activeConversationId!,
      forceRefresh: refresh,
    );

    if (mounted) {
      setState(() {
        // Keep original order from API (usually [Latest, ..., Oldest])
        // Since ListView(reverse: true) shows index 0 at the bottom.
        _messages = results;
        // Don't set isLoading false on refresh to avoid flickering,
        // but if it was initial load (!refresh), set it to false.
        if (!refresh) _isLoading = false;
      });
      // Scroll to newest on initial load and when new messages arrived
      if (results.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNewest());
      }
    }
  }

  void _scrollToNewest() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    // Optimistic update
    final tempMsg = ChatMessage(
      id: -1, // Temp ID
      conversationId: _activeConversationId ?? -1,
      senderId: _currentUserId ?? '',
      content: text,
      isRead: false,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, tempMsg); // Insert at top (bottom of screen)
      _msgController.clear();
    });
    _scrollToNewest();

    final result = await _api.sendMessage(
      conversationId: _activeConversationId,
      listingId: widget.listing?.id,
      receiverId: widget.recipientId,
      content: text,
    );

    if (mounted) {
      setState(() => _isSending = false);

      if (result['success'] == true) {
        // If this was a new conversation, update the ID
        if (_activeConversationId == null && result['data'] != null) {
          // Ideally we get the ID here. For now, we might need to rely on
          // _loadConversations in parent or refetching.
          // If the backend returns the full message or conversation object, extracting ID would be good.
          // Assuming for now we need to rely on next poll or parent reload if we don't have ID.

          // To be safe, if we don't have ID, we can't poll effectively.
          // Let's assume the backend returns the created message which has conversationId.
          try {
            // Verify if result['data'] is Map and has conversationId
            if (result['data'] is Map) {
              final msgData = result['data'];
              if (msgData['conversationId'] != null) {
                _activeConversationId = msgData['conversationId'];
              }
            }
          } catch (_) {}
        }
        _loadMessages(refresh: true);
      } else {
        // Remove optimistic message on failure
        setState(() {
          _messages.remove(tempMsg);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to send message'),
          ),
        );
      }
    }
  }

  String _formatMessageTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  Future<void> _deleteChat() async {
    if (_activeConversationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: const Text(
          'This will remove this conversation from your list. Other participants will still be able to see it.',
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
      final res = await _api.deleteConversation(_activeConversationId!);

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Conversation deleted')));
          Navigator.pop(context); // Go back to list
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to delete')),
          );
        }
      }
    }
  }

  void _viewListing() {
    if (widget.listing == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailsPage(listing: widget.listing!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            SmartImage(
              imageUrl: widget.recipientImage,
              width: 36,
              height: 36,
              shape: BoxShape.circle,
              errorWidget: Center(
                child: Text(
                  widget.recipientName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.recipientName, style: AppTextStyles.labelLarge),
                  if (widget.listing != null)
                    Text(
                      'Book: ${widget.listing!.title}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'view_listing') {
                _viewListing();
              } else if (val == 'delete_chat') {
                _deleteChat();
              }
            },
            itemBuilder: (context) => [
              if (widget.listing != null)
                const PopupMenuItem(
                  value: 'view_listing',
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('View Listing'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete_chat',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete Chat',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? _buildMessageSkeleton()
                  : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Say hi to ${widget.recipientName}!',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      reverse:
                          true, // Show latest messages at the bottom if list is [Latest, Oldest]
                      controller: _scrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior
                          .onDrag, // Common preference
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe =
                            msg.senderId.toString() ==
                            _currentUserId.toString();
                        return _buildMessageBubble(msg, isMe, isDark);
                      },
                    ),
            ),
            _buildInputArea(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : (isDark ? AppColors.cardDark : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            if (msg.id != -1)
              Text(
                _formatMessageTime(msg.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: isDark ? Colors.black12 : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSkeleton() {
    return ShimmerWrapper(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        reverse: true,
        itemBuilder: (_, i) {
          final isMe = i % 2 == 0;
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              width: 150 + (i * 20.0) % 100,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }
}
