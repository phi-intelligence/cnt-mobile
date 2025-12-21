import 'package:flutter/foundation.dart';

class EventModel {
  final int id;
  final int hostId;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int maxAttendees;
  final String status;
  final String? coverImage;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final EventHost? host;
  final int attendeesCount;
  final bool isAttending;
  final String? myAttendanceStatus;

  EventModel({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    required this.eventDate,
    this.location,
    this.latitude,
    this.longitude,
    this.maxAttendees = 0,
    this.status = 'published',
    this.coverImage,
    required this.createdAt,
    this.updatedAt,
    this.host,
    this.attendeesCount = 0,
    this.isAttending = false,
    this.myAttendanceStatus,
  });

  /// Check if this event has valid GPS coordinates
  bool get hasCoordinates => latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String),
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      maxAttendees: json['max_attendees'] as int? ?? 0,
      status: json['status'] as String? ?? 'published',
      coverImage: json['cover_image'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      host: json['host'] != null
          ? EventHost.fromJson(json['host'] as Map<String, dynamic>)
          : null,
      attendeesCount: json['attendees_count'] as int? ?? 0,
      isAttending: json['is_attending'] as bool? ?? false,
      myAttendanceStatus: json['my_attendance_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host_id': hostId,
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'max_attendees': maxAttendees,
      'status': status,
      'cover_image': coverImage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'host': host?.toJson(),
      'attendees_count': attendeesCount,
      'is_attending': isAttending,
      'my_attendance_status': myAttendanceStatus,
    };
  }

  bool get isUpcoming => eventDate.isAfter(DateTime.now());
  bool get isPast => eventDate.isBefore(DateTime.now());
  bool get isFull => maxAttendees > 0 && attendeesCount >= maxAttendees;
}

class EventHost {
  final int id;
  final String? username;
  final String name;
  final String? avatar;

  EventHost({
    required this.id,
    this.username,
    required this.name,
    this.avatar,
  });

  factory EventHost.fromJson(Map<String, dynamic> json) {
    return EventHost(
      id: json['id'] as int,
      username: json['username'] as String?,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'avatar': avatar,
    };
  }
}

class EventAttendee {
  final int id;
  final int userId;
  final String status;
  final DateTime createdAt;
  final EventHost? user;

  EventAttendee({
    required this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.user,
  });

  factory EventAttendee.fromJson(Map<String, dynamic> json) {
    return EventAttendee(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: json['user'] != null
          ? EventHost.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EventCreate {
  final String title;
  final String? description;
  final DateTime eventDate;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? maxAttendees;
  final String? coverImage;

  EventCreate({
    required this.title,
    this.description,
    required this.eventDate,
    this.location,
    this.latitude,
    this.longitude,
    this.maxAttendees,
    this.coverImage,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'max_attendees': maxAttendees ?? 0,
      'cover_image': coverImage,
    };
  }
}

