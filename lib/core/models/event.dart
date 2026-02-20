import 'package:smart_pulchowk/core/models/club.dart';

enum EventStatus { draft, published, ongoing, completed, cancelled }

class ClubEvent {
  final int id;
  final int clubId;
  final String title;
  final String? description;
  final String eventType;
  final String status;
  final String? venue;
  final int? maxParticipants;
  final int currentParticipants;
  final DateTime? registrationDeadline;
  final DateTime eventStartTime;
  final DateTime eventEndTime;
  final String? bannerUrl;
  final String? externalRegistrationLink;
  final bool isRegistrationOpen;
  final DateTime createdAt;
  final Club? club;

  ClubEvent({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    required this.eventType,
    required this.status,
    this.venue,
    this.maxParticipants,
    this.currentParticipants = 0,
    this.registrationDeadline,
    required this.eventStartTime,
    required this.eventEndTime,
    this.bannerUrl,
    this.externalRegistrationLink,
    this.isRegistrationOpen = true,
    required this.createdAt,
    this.club,
  });

  factory ClubEvent.fromJson(Map<String, dynamic> json) {
    return ClubEvent(
      id: _parseInt(json['id']) ?? 0,
      clubId: _parseInt(json['clubId']) ?? _parseInt(json['club_id']) ?? 0,
      title: json['title']?.toString() ?? 'Untitled Event',
      description: json['description']?.toString(),
      eventType: json['eventType']?.toString() ?? 'event',
      status: json['status']?.toString() ?? 'published',
      venue: json['venue']?.toString(),
      maxParticipants: _parseInt(json['maxParticipants']),
      currentParticipants: _parseInt(json['currentParticipants']) ?? 0,
      registrationDeadline: json['registrationDeadline'] != null
          ? DateTime.tryParse(json['registrationDeadline'].toString())
          : null,
      eventStartTime: json['eventStartTime'] != null
          ? (DateTime.tryParse(json['eventStartTime'].toString()) ??
                DateTime.now())
          : DateTime.now(),
      eventEndTime: json['eventEndTime'] != null
          ? (DateTime.tryParse(json['eventEndTime'].toString()) ??
                DateTime.now().add(const Duration(hours: 2)))
          : DateTime.now().add(const Duration(hours: 2)),
      bannerUrl: json['bannerUrl']?.toString(),
      externalRegistrationLink: json['externalRegistrationLink']?.toString(),
      isRegistrationOpen: json['isRegistrationOpen'] is bool
          ? json['isRegistrationOpen']
          : true,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      club: json['club'] != null
          ? Club.fromJson(json['club'] as Map<String, dynamic>)
          : null,
    );
  }

  factory ClubEvent.fromId(int id) {
    return ClubEvent(
      id: id,
      clubId: 0,
      title: 'Event #$id',
      eventType: 'event',
      status: 'published',
      eventStartTime: DateTime.now(),
      eventEndTime: DateTime.now().add(const Duration(hours: 2)),
      createdAt: DateTime.now(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool get isOngoing {
    final now = DateTime.now();
    return status == 'ongoing' ||
        (eventStartTime.isBefore(now) &&
            eventEndTime.isAfter(now) &&
            status != 'completed' &&
            status != 'cancelled');
  }

  bool get isUpcoming {
    final now = DateTime.now();
    return eventStartTime.isAfter(now) &&
        status != 'completed' &&
        status != 'cancelled' &&
        status != 'ongoing';
  }

  bool get isCompleted {
    final now = DateTime.now();
    return status == 'completed' || eventEndTime.isBefore(now);
  }

  bool get isCancelled {
    return status == 'cancelled';
  }

  bool get canRegister {
    if (isCompleted || isCancelled) return false;
    if (!isRegistrationOpen) return false;
    final now = DateTime.now();
    if (registrationDeadline != null && registrationDeadline!.isBefore(now)) {
      return false;
    }
    if (maxParticipants != null && currentParticipants >= maxParticipants!) {
      return false;
    }
    return true;
  }
}

class EventRegistration {
  final int id;
  final int eventId;
  final String studentId;
  final String status;
  final DateTime createdAt;
  final ClubEvent? event;

  EventRegistration({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.status,
    required this.createdAt,
    this.event,
  });

  factory EventRegistration.fromJson(Map<String, dynamic> json) {
    return EventRegistration(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      eventId: json['eventId'] is int
          ? json['eventId']
          : json['event_id'] is int
          ? json['event_id']
          : int.tryParse(
                  json['eventId']?.toString() ??
                      json['event_id']?.toString() ??
                      '0',
                ) ??
                0,
      studentId:
          json['studentId']?.toString() ?? json['student_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'registered',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      event: json['event'] != null
          ? (json['event'] is Map<String, dynamic>
                ? ClubEvent.fromJson(json['event'])
                : null)
          : null,
    );
  }
}

/// A registered student for an event. Used by the admin roster view.
class RegisteredStudent {
  final int registrationId;
  final String status;
  final DateTime? registeredAt;
  final String? studentName;
  final String? studentEmail;
  final String? studentPhoto;

  RegisteredStudent({
    required this.registrationId,
    required this.status,
    this.registeredAt,
    this.studentName,
    this.studentEmail,
    this.studentPhoto,
  });

  factory RegisteredStudent.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>?;
    return RegisteredStudent(
      registrationId: json['registrationId'] is int
          ? json['registrationId']
          : int.tryParse(json['registrationId']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'registered',
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt'].toString())
          : null,
      studentName: student?['name']?.toString(),
      studentEmail: student?['email']?.toString(),
      studentPhoto: student?['image']?.toString(),
    );
  }
}
