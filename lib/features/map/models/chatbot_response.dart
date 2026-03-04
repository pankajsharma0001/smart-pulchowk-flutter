/// Model classes for campus navigation chatbot responses
class ChatBotLocation {
  final String buildingId;
  final String buildingName;
  final double lat;
  final double lng;
  final String? serviceName;
  final String? serviceLocation;
  final String role; // "start", "end", or "destination"

  ChatBotLocation({
    required this.buildingId,
    required this.buildingName,
    required this.lat,
    required this.lng,
    this.serviceName,
    this.serviceLocation,
    required this.role,
  });

  factory ChatBotLocation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>;
    return ChatBotLocation(
      buildingId: json['building_id'] as String? ?? '',
      buildingName: json['building_name'] as String? ?? 'Unknown',
      lat: (coords['lat'] as num).toDouble(),
      lng: (coords['lng'] as num).toDouble(),
      serviceName: json['service_name'] as String?,
      serviceLocation: json['service_location'] as String?,
      role: json['role'] as String? ?? 'destination',
    );
  }

  Map<String, dynamic> toJson() => {
    'building_id': buildingId,
    'building_name': buildingName,
    'coordinates': {'lat': lat, 'lng': lng},
    'service_name': serviceName,
    'service_location': serviceLocation,
    'role': role,
  };
}

class ChatBotData {
  final String message;
  final List<ChatBotLocation> locations;
  final String action;
  final String intent;
  final List<String> followUp;

  ChatBotData({
    required this.message,
    required this.locations,
    required this.action,
    this.intent = 'unknown',
    this.followUp = const [],
  });

  /// True when the response is text-only (no map interaction needed).
  bool get isTextOnly => action == 'text_answer';

  /// True when the response should trigger a map action (location/route).
  bool get isMapAction =>
      action == 'show_route' ||
      action == 'show_location' ||
      action == 'show_multiple_locations';

  factory ChatBotData.fromJson(Map<String, dynamic> json) {
    final locationsJson = json['locations'] as List<dynamic>? ?? [];
    final followUpJson = json['follow_up'] as List<dynamic>? ?? [];
    return ChatBotData(
      message: json['message'] as String? ?? '',
      locations: locationsJson
          .map((l) => ChatBotLocation.fromJson(l as Map<String, dynamic>))
          .toList(),
      action: json['action'] as String? ?? 'show_location',
      intent: json['intent'] as String? ?? 'unknown',
      followUp: followUpJson
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}

class ChatBotResponse {
  final bool success;
  final ChatBotData? data;
  final String? errorMessage;
  final String? errorType;
  final bool isQuotaError;

  ChatBotResponse({
    required this.success,
    this.data,
    this.errorMessage,
    this.errorType,
    this.isQuotaError = false,
  });

  factory ChatBotResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? false;
    final message = json['message'] as String?;
    final errorType = json['errorType'] as String?;

    if (success && json['data'] != null) {
      return ChatBotResponse(
        success: true,
        data: ChatBotData.fromJson(json['data'] as Map<String, dynamic>),
      );
    }

    return ChatBotResponse(
      success: false,
      errorMessage: message ?? 'Something went wrong',
      errorType: errorType,
      isQuotaError: errorType == 'quota_exceeded',
    );
  }
}

/// Chat message model for UI
class ChatBotMessage {
  final String content;
  final ChatBotMessageRole role;
  final List<ChatBotLocation>? locations;
  final String? action;
  final List<String> followUp;
  final bool isQuotaError;
  final DateTime timestamp;

  ChatBotMessage({
    required this.content,
    required this.role,
    this.locations,
    this.action,
    this.followUp = const [],
    this.isQuotaError = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'content': content,
    'role': role.name,
    'action': action,
    'followUp': followUp,
    'isQuotaError': isQuotaError,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatBotMessage.fromJson(Map<String, dynamic> json) {
    return ChatBotMessage(
      content: json['content'] as String? ?? '',
      role: ChatBotMessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => ChatBotMessageRole.assistant,
      ),
      action: json['action'] as String?,
      followUp:
          (json['followUp'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isQuotaError: json['isQuotaError'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

enum ChatBotMessageRole { user, assistant, error }
