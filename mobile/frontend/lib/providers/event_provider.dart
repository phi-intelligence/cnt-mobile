import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class EventProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<EventModel> _events = [];
  List<EventModel> _myHostedEvents = [];
  List<EventModel> _myAttendingEvents = [];
  EventModel? _selectedEvent;
  List<EventAttendee> _selectedEventAttendees = [];
  
  bool _isLoading = false;
  String? _error;
  int _totalEvents = 0;
  
  // Getters
  List<EventModel> get events => _events;
  List<EventModel> get myHostedEvents => _myHostedEvents;
  List<EventModel> get myAttendingEvents => _myAttendingEvents;
  EventModel? get selectedEvent => _selectedEvent;
  List<EventAttendee> get selectedEventAttendees => _selectedEventAttendees;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalEvents => _totalEvents;
  
  List<EventModel> get upcomingEvents =>
      _events.where((e) => e.isUpcoming && e.status == 'published').toList();
  
  List<EventModel> get pastEvents =>
      _events.where((e) => e.isPast).toList();

  Future<void> fetchEvents({
    int skip = 0,
    int limit = 20,
    bool upcomingOnly = false,
    bool refresh = false,
  }) async {
    if (refresh) {
      _events = [];
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _api.getEvents(
        skip: skip,
        limit: limit,
        upcomingOnly: upcomingOnly,
      );
      
      final eventsList = (result['events'] as List<dynamic>)
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
      
      if (refresh || skip == 0) {
        _events = eventsList;
      } else {
        _events.addAll(eventsList);
      }
      
      _totalEvents = result['total'] as int? ?? eventsList.length;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchEventDetails(int eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _api.getEvent(eventId);
      _selectedEvent = EventModel.fromJson(result);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyHostedEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _api.getMyHostedEvents();
      _myHostedEvents = result
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyAttendingEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _api.getMyAttendingEvents();
      _myAttendingEvents = result
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<EventModel?> createEvent(EventCreate eventData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _api.createEvent(
        title: eventData.title,
        description: eventData.description,
        eventDate: eventData.eventDate,
        location: eventData.location,
        maxAttendees: eventData.maxAttendees,
        coverImage: eventData.coverImage,
      );
      
      final newEvent = EventModel.fromJson(result);
      _events.insert(0, newEvent);
      _myHostedEvents.insert(0, newEvent);
      notifyListeners();
      return newEvent;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> joinEvent(int eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _api.joinEvent(eventId);
      
      // Update local state
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final event = _events[index];
        _events[index] = EventModel(
          id: event.id,
          hostId: event.hostId,
          title: event.title,
          description: event.description,
          eventDate: event.eventDate,
          location: event.location,
          maxAttendees: event.maxAttendees,
          status: event.status,
          coverImage: event.coverImage,
          createdAt: event.createdAt,
          updatedAt: event.updatedAt,
          host: event.host,
          attendeesCount: event.attendeesCount,
          isAttending: true,
          myAttendanceStatus: 'pending',
        );
      }
      
      if (_selectedEvent?.id == eventId) {
        _selectedEvent = EventModel(
          id: _selectedEvent!.id,
          hostId: _selectedEvent!.hostId,
          title: _selectedEvent!.title,
          description: _selectedEvent!.description,
          eventDate: _selectedEvent!.eventDate,
          location: _selectedEvent!.location,
          maxAttendees: _selectedEvent!.maxAttendees,
          status: _selectedEvent!.status,
          coverImage: _selectedEvent!.coverImage,
          createdAt: _selectedEvent!.createdAt,
          updatedAt: _selectedEvent!.updatedAt,
          host: _selectedEvent!.host,
          attendeesCount: _selectedEvent!.attendeesCount,
          isAttending: true,
          myAttendanceStatus: 'pending',
        );
      }
      
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> leaveEvent(int eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _api.leaveEvent(eventId);
      
      // Update local state
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final event = _events[index];
        _events[index] = EventModel(
          id: event.id,
          hostId: event.hostId,
          title: event.title,
          description: event.description,
          eventDate: event.eventDate,
          location: event.location,
          maxAttendees: event.maxAttendees,
          status: event.status,
          coverImage: event.coverImage,
          createdAt: event.createdAt,
          updatedAt: event.updatedAt,
          host: event.host,
          attendeesCount: event.attendeesCount - 1,
          isAttending: false,
          myAttendanceStatus: null,
        );
      }
      
      _myAttendingEvents.removeWhere((e) => e.id == eventId);
      
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchEventAttendees(int eventId, {String? statusFilter}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _api.getEventAttendees(eventId, statusFilter: statusFilter);
      _selectedEventAttendees = result
          .map((e) => EventAttendee.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAttendeeStatus(int eventId, int userId, String status) async {
    try {
      await _api.updateAttendeeStatus(eventId, userId, status);
      
      // Update local state
      final index = _selectedEventAttendees.indexWhere((a) => a.userId == userId);
      if (index != -1) {
        final attendee = _selectedEventAttendees[index];
        _selectedEventAttendees[index] = EventAttendee(
          id: attendee.id,
          userId: attendee.userId,
          status: status,
          createdAt: attendee.createdAt,
          user: attendee.user,
        );
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    }
  }

  Future<bool> deleteEvent(int eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _api.deleteEvent(eventId);
      
      // Remove from local lists
      _events.removeWhere((e) => e.id == eventId);
      _myHostedEvents.removeWhere((e) => e.id == eventId);
      
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void clearSelectedEvent() {
    _selectedEvent = null;
    _selectedEventAttendees = [];
    notifyListeners();
  }
}

