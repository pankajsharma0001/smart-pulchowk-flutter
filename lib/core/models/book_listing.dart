/// Book condition enum matching backend enum
enum BookCondition {
  newBook('new', 'New'),
  likeNew('like_new', 'Like New'),
  good('good', 'Good'),
  fair('fair', 'Fair'),
  poor('poor', 'Poor');

  const BookCondition(this.value, this.label);
  final String value;
  final String label;

  /// Alias for label, used by UI
  String get displayName => label;

  /// Alias for value, used when sending to backend
  String get backendValue => value;

  static BookCondition fromString(String? value) {
    return BookCondition.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookCondition.good,
    );
  }
}

/// Book listing status enum
enum BookStatus {
  available('available', 'Available'),
  pending('pending', 'Pending'),
  sold('sold', 'Sold'),
  removed('removed', 'Removed');

  const BookStatus(this.value, this.label);
  final String value;
  final String label;

  static BookStatus fromString(String? value) {
    return BookStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookStatus.available,
    );
  }
}

/// Book image model
class BookImage {
  final int id;
  final int listingId;
  final String imageUrl;
  final String? imagePublicId;
  final DateTime createdAt;

  BookImage({
    required this.id,
    required this.listingId,
    required this.imageUrl,
    this.imagePublicId,
    required this.createdAt,
  });

  factory BookImage.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['imageUrl'] as String?;
    return BookImage(
      id: json['id'] as int? ?? 0,
      listingId: json['listingId'] as int? ?? 0,
      imageUrl: _processImageUrl(rawUrl) ?? '',
      imagePublicId: json['imagePublicId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'listingId': listingId,
    'imageUrl': imageUrl,
    'imagePublicId': imagePublicId,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Book category model
class BookCategory {
  final int id;
  final String name;
  final String? description;
  final int? parentCategoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BookCategory? parentCategory;
  final List<BookCategory>? subcategories;

  BookCategory({
    required this.id,
    required this.name,
    this.description,
    this.parentCategoryId,
    required this.createdAt,
    required this.updatedAt,
    this.parentCategory,
    this.subcategories,
  });

  factory BookCategory.fromJson(Map<String, dynamic> json) {
    return BookCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      parentCategoryId: json['parentCategoryId'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      parentCategory: json['parentCategory'] != null
          ? BookCategory.fromJson(
              json['parentCategory'] as Map<String, dynamic>,
            )
          : null,
      subcategories: json['subcategories'] != null
          ? (json['subcategories'] as List)
                .map((e) => BookCategory.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'parentCategoryId': parentCategoryId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Book seller info
class BookSeller {
  final String id;
  final String name;
  final String? email;
  final String? image;

  BookSeller({required this.id, required this.name, this.email, this.image});

  factory BookSeller.fromJson(Map<String, dynamic> json) {
    return BookSeller(
      id: (json['id'] ?? json['user_id'])?.toString() ?? '',
      name: (json['name'] ?? json['full_name'])?.toString() ?? 'Unknown User',
      email: json['email']?.toString(),
      image: json['image']?.toString(),
    );
  }
}

/// Main book listing model
class BookListing {
  final int id;
  final String sellerId;
  final String title;
  final String author;
  final String? isbn;
  final String? edition;
  final String? publisher;
  final int? publicationYear;
  final BookCondition condition;
  final String? description;
  final String price;
  final BookStatus status;
  final String? courseCode;
  final int? categoryId;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? soldAt;
  final BookSeller? seller;
  final List<BookImage>? images;
  final BookCategory? category;
  final bool isSaved;
  final bool isOwner;
  final String? buyerContactInfo;
  final int requestCount;

  BookListing({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.author,
    this.isbn,
    this.edition,
    this.publisher,
    this.publicationYear,
    required this.condition,
    this.description,
    required this.price,
    required this.status,
    this.courseCode,
    this.categoryId,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
    this.soldAt,
    this.seller,
    this.images,
    this.category,
    this.isSaved = false,
    this.isOwner = false,
    this.buyerContactInfo,
    this.requestCount = 0,
  });

  factory BookListing.fromJson(Map<String, dynamic> json) {
    return BookListing(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      sellerId: (json['sellerId'] ?? json['seller_id'])?.toString() ?? '',
      title: (json['title'] ?? 'Untitled').toString(),
      author: (json['author'] ?? 'Unknown Author').toString(),
      isbn: json['isbn']?.toString(),
      edition: json['edition']?.toString(),
      publisher: json['publisher']?.toString(),
      publicationYear: json['publicationYear'] is int
          ? json['publicationYear'] as int
          : int.tryParse(
              json['publication_year']?.toString() ??
                  json['publicationYear']?.toString() ??
                  '',
            ),
      condition: BookCondition.fromString(
        (json['condition'] ?? json['book_condition'])?.toString(),
      ),
      description: (json['description'] ?? json['desc'])?.toString(),
      price: (json['price'] ?? '0').toString(),
      status: BookStatus.fromString((json['status'] ?? 'available').toString()),
      courseCode: (json['courseCode'] ?? json['course_code'])?.toString(),
      categoryId: json['categoryId'] is int
          ? json['categoryId'] as int
          : (json['category_id'] is int
                ? json['category_id'] as int
                : int.tryParse(
                    json['category_id']?.toString() ??
                        json['categoryId']?.toString() ??
                        '',
                  )),
      viewCount: json['viewCount'] is int
          ? json['viewCount'] as int
          : int.tryParse(
                  json['view_count']?.toString() ??
                      json['viewCount']?.toString() ??
                      '',
                ) ??
                0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : (json['updated_at'] != null
                ? DateTime.tryParse(json['updated_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      soldAt: (json['soldAt'] ?? json['sold_at']) != null
          ? DateTime.tryParse((json['soldAt'] ?? json['sold_at']).toString())
          : null,
      seller: json['seller'] != null
          ? BookSeller.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      images: json['images'] != null
          ? (json['images'] as List)
                .map((e) => BookImage.fromJson(e as Map<String, dynamic>))
                .where((image) => image.imageUrl.isNotEmpty)
                .toList()
          : null,
      category: (json['category'] ?? json['book_category']) != null
          ? BookCategory.fromJson(
              (json['category'] ?? json['book_category'])
                  as Map<String, dynamic>,
            )
          : null,
      isSaved: (json['isSaved'] ?? json['is_saved']) as bool? ?? false,
      isOwner: (json['isOwner'] ?? json['is_owner']) as bool? ?? false,
      buyerContactInfo: (json['buyerContactInfo'] ?? json['buyer_contact'])
          ?.toString(),
      requestCount: json['requestCount'] is int
          ? json['requestCount'] as int
          : int.tryParse(
                  json['request_count']?.toString() ??
                      json['requestCount']?.toString() ??
                      '',
                ) ??
                0,
    );
  }

  /// Parse partial book data from search endpoint
  factory BookListing.fromPartialJson(Map<String, dynamic> json) {
    return BookListing(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      sellerId: json['sellerId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      author: json['author']?.toString() ?? 'Unknown Author',
      isbn: json['isbn']?.toString(),
      edition: json['edition']?.toString(),
      publisher: json['publisher']?.toString(),
      publicationYear: json['publicationYear'] is int
          ? json['publicationYear'] as int
          : int.tryParse(json['publicationYear']?.toString() ?? ''),
      condition: BookCondition.fromString(json['condition']?.toString()),
      description: json['description']?.toString(),
      price: json['price']?.toString() ?? '0',
      status: BookStatus.fromString(json['status']?.toString()),
      courseCode: json['courseCode']?.toString(),
      categoryId: json['categoryId'] is int
          ? json['categoryId'] as int
          : int.tryParse(json['categoryId']?.toString() ?? ''),
      viewCount: json['viewCount'] is int
          ? json['viewCount'] as int
          : int.tryParse(json['viewCount']?.toString() ?? '') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      soldAt: json['soldAt'] != null
          ? DateTime.tryParse(json['soldAt'].toString())
          : null,
      seller: json['seller'] != null
          ? BookSeller.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      images: json['images'] != null
          ? (json['images'] as List)
                .map((e) => BookImage.fromJson(e as Map<String, dynamic>))
                .where((image) => image.imageUrl.isNotEmpty)
                .toList()
          : null,
      category: json['category'] != null
          ? BookCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      isSaved: json['isSaved'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      buyerContactInfo: json['buyerContactInfo']?.toString(),
      requestCount: json['requestCount'] is int
          ? json['requestCount'] as int
          : int.tryParse(json['requestCount']?.toString() ?? '') ?? 0,
    );
  }

  /// Create a placeholder listing with just an ID for navigation.
  factory BookListing.fromId(int id) {
    return BookListing(
      id: id,
      sellerId: '',
      title: '...',
      author: '...',
      condition: BookCondition.good,
      price: '0',
      status: BookStatus.available,
      viewCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Get the first image URL or null
  String? get primaryImageUrl =>
      images != null && images!.isNotEmpty ? images!.first.imageUrl : null;

  /// Get formatted price with currency
  String get formattedPrice => 'Rs. ${double.parse(price).toStringAsFixed(0)}';

  /// Get human-readable listing date
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Check if book is available for purchase
  bool get isAvailable => status == BookStatus.available;

  BookListing copyWith({
    int? id,
    String? sellerId,
    String? title,
    String? author,
    String? isbn,
    String? edition,
    String? publisher,
    int? publicationYear,
    BookCondition? condition,
    String? description,
    String? price,
    BookStatus? status,
    String? courseCode,
    int? categoryId,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? soldAt,
    BookSeller? seller,
    List<BookImage>? images,
    BookCategory? category,
    bool? isSaved,
    bool? isOwner,
    String? buyerContactInfo,
    int? requestCount,
  }) {
    return BookListing(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      edition: edition ?? this.edition,
      publisher: publisher ?? this.publisher,
      publicationYear: publicationYear ?? this.publicationYear,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      price: price ?? this.price,
      status: status ?? this.status,
      courseCode: courseCode ?? this.courseCode,
      categoryId: categoryId ?? this.categoryId,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      soldAt: soldAt ?? this.soldAt,
      seller: seller ?? this.seller,
      images: images ?? this.images,
      category: category ?? this.category,
      isSaved: isSaved ?? this.isSaved,
      isOwner: isOwner ?? this.isOwner,
      buyerContactInfo: buyerContactInfo ?? this.buyerContactInfo,
      requestCount: requestCount ?? this.requestCount,
    );
  }
}

/// Saved book model
class SavedBook {
  final int id;
  final String userId;
  final int listingId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BookListing? listing;

  SavedBook({
    required this.id,
    required this.userId,
    required this.listingId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.listing,
  });

  factory SavedBook.fromJson(Map<String, dynamic> json) {
    return SavedBook(
      id: json['id'] as int,
      userId: json['userId'] as String,
      listingId: json['listingId'] as int,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      listing: json['listing'] != null
          ? BookListing.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Book purchase request status enum
enum RequestStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled');

  const RequestStatus(this.value, this.label);
  final String value;
  final String label;

  static RequestStatus fromString(String? value) {
    return RequestStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RequestStatus.pending,
    );
  }
}

/// Book purchase request model
class BookPurchaseRequest {
  final int id;
  final int listingId;
  final String buyerId;
  final RequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BookListing? listing;
  final BookSeller? buyer;

  BookPurchaseRequest({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.status,
    this.message,
    required this.createdAt,
    required this.updatedAt,
    this.listing,
    this.buyer,
  });

  factory BookPurchaseRequest.fromJson(Map<String, dynamic> json) {
    return BookPurchaseRequest(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      listingId: (json['listingId'] ?? json['listing_id']) is int
          ? (json['listingId'] ?? json['listing_id']) as int
          : int.tryParse(
                  (json['listingId'] ?? json['listing_id'])?.toString() ?? '',
                ) ??
                0,
      buyerId: (json['buyerId'] ?? json['buyer_id'])?.toString() ?? '',
      status: RequestStatus.fromString(
        (json['status'] ?? 'pending').toString(),
      ),
      message: (json['message'] ?? json['customer_message'])?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : (json['updated_at'] != null
                ? DateTime.tryParse(json['updated_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      listing: (json['listing'] ?? json['book_listing']) != null
          ? BookListing.fromJson(
              (json['listing'] ?? json['book_listing']) as Map<String, dynamic>,
            )
          : null,
      buyer: (json['buyer'] ?? json['buyer_info']) != null
          ? BookSeller.fromJson(
              (json['buyer'] ?? json['buyer_info']) as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Convenience getters for UI
  String? get listingTitle => listing?.title;
  String? get sellerName => listing?.seller?.name;
}

/// Book filters for search/filter API
class BookFilters {
  final String? search;
  final String? author;
  final String? isbn;
  final int? categoryId;
  final String? condition;
  final double? minPrice;
  final double? maxPrice;
  final String? status;
  final String? sortBy; // 'price_asc', 'price_desc', 'newest', 'oldest'
  final String? sellerId;
  final int page;
  final int limit;

  BookFilters({
    this.search,
    this.author,
    this.isbn,
    this.categoryId,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.status,
    this.sortBy,
    this.sellerId,
    this.page = 1,
    this.limit = 12,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (search != null && search!.isNotEmpty) params['search'] = search!;
    if (author != null && author!.isNotEmpty) params['author'] = author!;
    if (isbn != null && isbn!.isNotEmpty) params['isbn'] = isbn!;
    if (categoryId != null) params['categoryId'] = categoryId.toString();
    if (condition != null && condition!.isNotEmpty) {
      params['condition'] = condition!;
    }
    if (minPrice != null) params['minPrice'] = minPrice.toString();
    if (maxPrice != null) params['maxPrice'] = maxPrice.toString();
    if (status != null && status!.isNotEmpty) params['status'] = status!;
    if (sortBy != null && sortBy!.isNotEmpty) params['sortBy'] = sortBy!;
    if (sellerId != null && sellerId!.isNotEmpty) {
      params['sellerId'] = sellerId!;
    }
    params['page'] = page.toString();
    params['limit'] = limit.toString();
    return params;
  }

  BookFilters copyWith({
    String? search,
    String? author,
    String? isbn,
    int? categoryId,
    String? condition,
    double? minPrice,
    double? maxPrice,
    String? status,
    String? sortBy,
    String? sellerId,
    int? page,
    int? limit,
  }) {
    return BookFilters(
      search: search ?? this.search,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      categoryId: categoryId ?? this.categoryId,
      condition: condition ?? this.condition,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      status: status ?? this.status,
      sortBy: sortBy ?? this.sortBy,
      sellerId: sellerId ?? this.sellerId,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

/// Pagination info model
class BookPagination {
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;

  BookPagination({
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
  });

  factory BookPagination.fromJson(Map<String, dynamic> json) {
    return BookPagination(
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalCount: json['totalCount'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  /// Alias used by UI pagination logic
  bool get hasMore => hasNextPage;
}

/// Book listings response model
class BookListingsResponse {
  final List<BookListing> listings;
  final BookPagination pagination;

  BookListingsResponse({required this.listings, required this.pagination});

  factory BookListingsResponse.fromJson(Map<String, dynamic> json) {
    return BookListingsResponse(
      listings: (json['listings'] as List)
          .map((e) => BookListing.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: BookPagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}

// ── Helper ──────────────────────────────────────────────────────────────────

/// Process an image URL: return null for invalid/empty URLs, pass through valid ones.
String? _processImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    return null;
  }
  return trimmed;
}
