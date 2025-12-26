import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentEvent {
  final String id;
  final String dayOfWeek;
  final String date;
  final String startTime;
  final String endTime;
  final String eventName;
  final DateTime createdAt;

  TournamentEvent({
    required this.id,
    required this.dayOfWeek,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.eventName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dayOfWeek': dayOfWeek,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'eventName': eventName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static TournamentEvent fromJson(Map<String, dynamic> json) {
    return TournamentEvent(
      id: json['id'] ?? '',
      dayOfWeek: json['dayOfWeek'] ?? '',
      date: json['date'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      eventName: json['eventName'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class WeekSchedule {
  final DateTime weekStartDate;
  final List<TournamentEvent> mondayEvents;
  final List<TournamentEvent> tuesdayEvents;
  final List<TournamentEvent> wednesdayEvents;
  final List<TournamentEvent> thursdayEvents;
  final List<TournamentEvent> fridayEvents;
  final List<TournamentEvent> saturdayEvents;
  final List<TournamentEvent> sundayEvents;

  WeekSchedule({
    required this.weekStartDate,
    this.mondayEvents = const [],
    this.tuesdayEvents = const [],
    this.wednesdayEvents = const [],
    this.thursdayEvents = const [],
    this.fridayEvents = const [],
    this.saturdayEvents = const [],
    this.sundayEvents = const [],
  });

  List<TournamentEvent> getEventsForDay(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return mondayEvents;
      case 'tuesday':
        return tuesdayEvents;
      case 'wednesday':
        return wednesdayEvents;
      case 'thursday':
        return thursdayEvents;
      case 'friday':
        return fridayEvents;
      case 'saturday':
        return saturdayEvents;
      case 'sunday':
        return sundayEvents;
      default:
        return [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'weekStartDate': weekStartDate.toIso8601String(),
      'mondayEvents': mondayEvents.map((e) => e.toJson()).toList(),
      'tuesdayEvents': tuesdayEvents.map((e) => e.toJson()).toList(),
      'wednesdayEvents': wednesdayEvents.map((e) => e.toJson()).toList(),
      'thursdayEvents': thursdayEvents.map((e) => e.toJson()).toList(),
      'fridayEvents': fridayEvents.map((e) => e.toJson()).toList(),
      'saturdayEvents': saturdayEvents.map((e) => e.toJson()).toList(),
      'sundayEvents': sundayEvents.map((e) => e.toJson()).toList(),
    };
  }
}