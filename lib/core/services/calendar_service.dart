import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_pulchowk/core/models/event.dart';

class CalendarService {
  static Future<bool> addEventToCalendar(ClubEvent event) async {
    final Event deviceEvent = Event(
      title: event.title,
      description: event.description ?? '',
      location: event.venue ?? '',
      startDate: event.eventStartTime,
      endDate: event.eventEndTime,
      allDay: false,
    );

    try {
      return await Add2Calendar.addEvent2Cal(deviceEvent);
    } catch (e) {
      debugPrint('Error adding event to calendar: $e');
      return false;
    }
  }
}
