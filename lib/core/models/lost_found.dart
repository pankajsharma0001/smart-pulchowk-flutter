import 'package:intl/intl.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';

enum LostFoundItemType { lost, found }

enum LostFoundCategory {
  documents,
  electronics,
  accessories,
  idsCards,
  keys,
  bags,
  other,
}

enum LostFoundStatus {
  open,
  claimed,
  resolved,
  closed;

  String get displayName {
    switch (this) {
      case LostFoundStatus.open:
        return 'Open';
      case LostFoundStatus.claimed:
        return 'Claimed';
      case LostFoundStatus.resolved:
        return 'Resolved';
      case LostFoundStatus.closed:
        return 'Closed';
    }
  }
}

enum LostFoundClaimStatus { pending, accepted, rejected, cancelled }

class LostFoundItem {
  final int id;
  final String ownerId;
  final LostFoundItemType itemType;
  final String title;
  final String description;
  final LostFoundCategory category;
  final DateTime lostFoundDate;
  final String locationText;
  final String? contactNote;
  final LostFoundStatus status;
  final String? rewardText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LostFoundImage> images;
  final List<LostFoundClaim>? claims;
  final Map<String, dynamic>? owner;

  LostFoundItem({
    required this.id,
    required this.ownerId,
    required this.itemType,
    required this.title,
    required this.description,
    required this.category,
    required this.lostFoundDate,
    required this.locationText,
    this.contactNote,
    required this.status,
    this.rewardText,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.claims,
    this.owner,
  });

  factory LostFoundItem.fromJson(Map<String, dynamic> json) {
    return LostFoundItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      ownerId:
          json['ownerId']?.toString() ?? json['owner_id']?.toString() ?? '',
      itemType: _parseItemType(json['itemType'] ?? json['item_type']),
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString() ?? '',
      category: _parseCategory(json['category'] ?? 'other'),
      lostFoundDate: json['lostFoundDate'] != null
          ? DateTime.tryParse(json['lostFoundDate'].toString()) ??
                DateTime.now()
          : json['lost_found_date'] != null
          ? DateTime.tryParse(json['lost_found_date'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      locationText:
          (json['locationText'] ?? json['location_text'] ?? '')?.toString() ??
          '',
      contactNote:
          json['contactNote']?.toString() ?? json['contact_note']?.toString(),
      status: _parseStatus(json['status']),
      rewardText:
          json['rewardText']?.toString() ?? json['reward_text']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      images:
          (json['images'] as List<dynamic>?)
              ?.map((i) => LostFoundImage.fromJson(i as Map<String, dynamic>))
              .where((i) => i.imageUrl.isNotEmpty)
              .toList() ??
          [],
      claims: (json['claims'] as List<dynamic>?)
          ?.map((c) => LostFoundClaim.fromJson(c as Map<String, dynamic>))
          .toList(),
      owner: json['owner'] as Map<String, dynamic>?,
    );
  }

  static LostFoundItemType _parseItemType(dynamic value) {
    if (value?.toString().toLowerCase() == 'lost') {
      return LostFoundItemType.lost;
    }
    return LostFoundItemType.found;
  }

  static LostFoundCategory _parseCategory(dynamic value) {
    final val = value?.toString().toLowerCase();
    switch (val) {
      case 'documents':
        return LostFoundCategory.documents;
      case 'electronics':
        return LostFoundCategory.electronics;
      case 'accessories':
        return LostFoundCategory.accessories;
      case 'ids_cards':
      case 'idscards':
        return LostFoundCategory.idsCards;
      case 'keys':
        return LostFoundCategory.keys;
      case 'bags':
        return LostFoundCategory.bags;
      default:
        return LostFoundCategory.other;
    }
  }

  static LostFoundStatus _parseStatus(dynamic value) {
    final val = value?.toString().toLowerCase();
    switch (val) {
      case 'open':
        return LostFoundStatus.open;
      case 'claimed':
        return LostFoundStatus.claimed;
      case 'resolved':
        return LostFoundStatus.resolved;
      case 'closed':
        return LostFoundStatus.closed;
      default:
        return LostFoundStatus.open;
    }
  }

  String get dateFormatted => DateFormat('MMM dd, yyyy').format(lostFoundDate);

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays >= 30) return DateFormat('MMM dd').format(createdAt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class LostFoundImage {
  final int id;
  final int itemId;
  final String imageUrl;
  final int sortOrder;

  LostFoundImage({
    required this.id,
    required this.itemId,
    required this.imageUrl,
    this.sortOrder = 0,
  });

  factory LostFoundImage.fromJson(Map<String, dynamic> json) {
    return LostFoundImage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      itemId: json['itemId'] is int
          ? json['itemId']
          : json['item_id'] is int
          ? json['item_id']
          : int.tryParse(
                  json['itemId']?.toString() ??
                      json['item_id']?.toString() ??
                      '0',
                ) ??
                0,
      imageUrl:
          ApiService.processImageUrl(
            json['imageUrl']?.toString() ?? json['image_url']?.toString(),
          ) ??
          '',
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder']
          : json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse(
                  json['sortOrder']?.toString() ??
                      json['sort_order']?.toString() ??
                      '0',
                ) ??
                0,
    );
  }
}

class LostFoundClaim {
  final int id;
  final int itemId;
  final String requesterId;
  final String message;
  final LostFoundClaimStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? requester;
  final LostFoundItem? item;

  LostFoundClaim({
    required this.id,
    required this.itemId,
    required this.requesterId,
    required this.message,
    required this.status,
    required this.createdAt,
    this.requester,
    this.item,
  });

  factory LostFoundClaim.fromJson(Map<String, dynamic> json) {
    return LostFoundClaim(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      itemId: json['itemId'] is int
          ? json['itemId']
          : json['item_id'] is int
          ? json['item_id']
          : int.tryParse(
                  json['itemId']?.toString() ??
                      json['item_id']?.toString() ??
                      '0',
                ) ??
                0,
      requesterId:
          json['requesterId']?.toString() ??
          json['requester_id']?.toString() ??
          '',
      message: json['message']?.toString() ?? '',
      status: _parseClaimStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      requester: json['requester'] as Map<String, dynamic>?,
      item: json['item'] != null
          ? LostFoundItem.fromJson(json['item'] as Map<String, dynamic>)
          : null,
    );
  }

  static LostFoundClaimStatus _parseClaimStatus(dynamic value) {
    final val = value?.toString().toLowerCase();
    switch (val) {
      case 'pending':
        return LostFoundClaimStatus.pending;
      case 'accepted':
        return LostFoundClaimStatus.accepted;
      case 'rejected':
        return LostFoundClaimStatus.rejected;
      case 'cancelled':
        return LostFoundClaimStatus.cancelled;
      default:
        return LostFoundClaimStatus.pending;
    }
  }
}
