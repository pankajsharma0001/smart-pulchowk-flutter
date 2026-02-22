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
}

class ChatBotData {
  final String message;
  final List<ChatBotLocation> locations;
  final String
  action; // "show_route", "show_location", "show_multiple_locations"

  ChatBotData({
    required this.message,
    required this.locations,
    required this.action,
  });

  factory ChatBotData.fromJson(Map<String, dynamic> json) {
    final locationsJson = json['locations'] as List<dynamic>? ?? [];
    return ChatBotData(
      message: json['message'] as String? ?? '',
      locations: locationsJson
          .map((l) => ChatBotLocation.fromJson(l as Map<String, dynamic>))
          .toList(),
      action: json['action'] as String? ?? 'show_location',
    );
  }
}

class ChatBotResponse {
  final bool success;
  final ChatBotData? data;
  final String? errorMessage;
  final bool isQuotaError;

  ChatBotResponse({
    required this.success,
    this.data,
    this.errorMessage,
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
  final bool isQuotaError;
  final DateTime timestamp;

  ChatBotMessage({
    required this.content,
    required this.role,
    this.locations,
    this.action,
    this.isQuotaError = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum ChatBotMessageRole { user, assistant, error }
