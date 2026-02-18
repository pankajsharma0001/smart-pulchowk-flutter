import 'package:smart_pulchowk/core/models/book_listing.dart';

class Conversation {
  final int id;
  final int listingId;
  final String buyerId;
  final String sellerId;
  final BookListing? listing;
  final ChatUser? buyer;
  final ChatUser? seller;
  final ChatMessage? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    this.listing,
    this.buyer,
    this.seller,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    dynamic lastMsgJson =
        json['lastMessage'] ??
        json['last_message'] ??
        json['latestMessage'] ??
        json['latest_message'] ??
        json['last_msg'] ??
        json['latest_msg'];

    if (lastMsgJson == null &&
        json['messages'] is List &&
        (json['messages'] as List).isNotEmpty) {
      lastMsgJson = (json['messages'] as List)
          .first; // Often the first one if reversed or last if not
    }

    return Conversation(
      id: json['id'] as int? ?? 0,
      listingId: (json['listingId'] ?? json['listing_id']) as int? ?? 0,
      buyerId: (json['buyerId'] ?? json['buyer_id'])?.toString() ?? '',
      sellerId: (json['sellerId'] ?? json['seller_id'])?.toString() ?? '',
      listing: json['listing'] != null
          ? BookListing.fromJson(json['listing'])
          : null,
      buyer: json['buyer'] != null ? ChatUser.fromJson(json['buyer']) : null,
      seller: json['seller'] != null ? ChatUser.fromJson(json['seller']) : null,
      lastMessage: lastMsgJson != null
          ? ChatMessage.fromJson(lastMsgJson)
          : null,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      unreadCount: (json['unreadCount'] ?? json['unread_count']) as int? ?? 0,
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    final dateStr = date.toString();
    if (dateStr.isEmpty) return DateTime.now();

    try {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        return DateTime.parse('${dateStr}Z').toLocal();
      }
      return DateTime.parse(dateStr).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  ChatUser? getOtherParticipant(String currentUserId) {
    // String comparison
    if (buyerId == currentUserId) return seller;
    if (sellerId == currentUserId) return buyer;
    // Fallback if currentUserId doesn't match either (should not happen if IDs are correct)
    return buyerId == currentUserId ? seller : buyer;
  }
}

class ChatMessage {
  final int id;
  final int conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int? ?? 0,
      conversationId:
          (json['conversationId'] ?? json['conversation_id']) as int? ?? 0,
      senderId: (json['senderId'] ?? json['sender_id'])?.toString() ?? '',
      content:
          (json['content'] ??
                  json['message'] ??
                  json['msg'] ??
                  json['text'] ??
                  '')
              .toString(),
      isRead: (json['isRead'] ?? json['is_read']) as bool? ?? false,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    final dateStr = date.toString();
    if (dateStr.isEmpty) return DateTime.now();

    try {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        return DateTime.parse('${dateStr}Z').toLocal();
      }
      return DateTime.parse(dateStr).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
}

class ChatUser {
  final String id;
  final String name;
  final String? image;

  ChatUser({required this.id, required this.name, this.image});

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: (json['id'] ?? json['user_id'])?.toString() ?? '',
      name: (json['name'] ?? json['full_name'] ?? 'Unknown').toString(),
      image: json['image']?.toString(),
    );
  }
}
