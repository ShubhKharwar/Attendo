import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; // For decoding JSON
import 'package:http/http.dart' as http; // For API calls
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For handling auth token
import 'package:intl/intl.dart';

// Data model for a teacher's class - REMAINS THE SAME
class TeacherClass {
  final String className;
  final String venue; // In our case, this will be the student's class (e.g., 'B.Tech CSE')
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  TeacherClass({
    required this.className,
    required this.venue,
    required this.startTime,
    required this.endTime,
  });

  // --- ADDED: Factory constructor to parse from API response ---
  factory TeacherClass.fromJson(Map<String, dynamic> json) {
    TimeOfDay startTime = _parseTime(json['startTime'] ?? '00:00');
    TimeOfDay endTime = _calculateEndTime(startTime, json['duration'] ?? '0 minutes');

    return TeacherClass(
      className: json['subject'] ?? 'Unknown Subject',
      venue: json['class'] ?? 'Unknown Class', // The student class from the backend
      startTime: startTime,
      endTime: endTime,
    );
  }
}

// Helper function to parse time from "HH:mm" string
TimeOfDay _parseTime(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return const TimeOfDay(hour: 0, minute: 0);
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

// Helper function to calculate end time from start time and duration string
TimeOfDay _calculateEndTime(TimeOfDay startTime, String duration) {
  final minutesToAdd = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  final now = DateTime.now();
  final startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
  final endDateTime = startDateTime.add(Duration(minutes: minutesToAdd));
  return TimeOfDay.fromDateTime(endDateTime);
}

// Enum to represent the status of a class - REMAINS THE SAME
enum ClassStatus { past, current, future }

class TeacherSchedulePage extends StatefulWidget {
  const TeacherSchedulePage({super.key});

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  // --- MODIFIED: State Management ---
  DateTime _selectedDate = DateTime.now();
  List<TeacherClass> _classesForSelectedDate = [];
  late Timer _timer;

  // --- ADDED: State for API calls ---
  bool _isLoading = true;
  String? _errorMessage;
  final _storage = const FlutterSecureStorage();

  // --- REMOVED: The hardcoded _allSchedules map is no longer needed ---

  @override
  void initState() {
    super.initState();
    // Fetch data for the initial date (today)
    _fetchScheduleForDate(_selectedDate);

    // Timer to update the UI for 'current' class status
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- REPLACED: This function now fetches data from your backend ---
  Future<void> _fetchScheduleForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Get the stored authentication token
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      // 2. Format the date and construct the URL
      // IMPORTANT: Replace 'YOUR_SERVER_IP:PORT' with your actual server address
      final String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final url = Uri.parse('http://192.168.0.104:3000/api/v1/admin/schedule?date=$formattedDate');

      // 3. Make the authenticated GET request
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      // 4. Handle the response
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> classesJson = data['classes'] ?? [];

        setState(() {
          _classesForSelectedDate = classesJson
              .map((jsonItem) => TeacherClass.fromJson(jsonItem))
              .toList();
          _isLoading = false;
        });
      } else {
        // Handle backend errors (e.g., 401, 404, 500)
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load schedule.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _classesForSelectedDate = []; // Clear data on error
      });
    }
  }

  // --- MODIFIED: This function now triggers the API call ---
  Future<void> _showCalendar() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Fetch data for the newly selected date
      _fetchScheduleForDate(_selectedDate);
    }
  }

  // --- LOGIC TO DETERMINE CLASS STATUS - REMAINS THE SAME ---
  ClassStatus _getClassStatus(TeacherClass teacherClass) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDay = DateUtils.dateOnly(_selectedDate);

    if (selectedDay.isBefore(today)) {
      return ClassStatus.past;
    }

    if (selectedDay.isAfter(today)) {
      return ClassStatus.future;
    }

    // Only do time-based comparison if it's today
    final now = TimeOfDay.now();
    final startTime = DateTime(today.year, today.month, today.day, teacherClass.startTime.hour, teacherClass.startTime.minute);
    final endTime = DateTime(today.year, today.month, today.day, teacherClass.endTime.hour, teacherClass.endTime.minute);
    final nowTime = DateTime(today.year, today.month, today.day, now.hour, now.minute);

    if (nowTime.isAfter(endTime)) {
      return ClassStatus.past;
    } else if (!nowTime.isBefore(startTime) && nowTime.isBefore(endTime)) {
      return ClassStatus.current;
    } else {
      return ClassStatus.future;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final String title = isToday ? "Today's Classes" : DateFormat.yMMMd().format(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // ... (AppBar code remains the same)
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showCalendar,
          ),
        ],
      ),
      // --- MODIFIED: Body now handles loading and error states ---
      body: _buildBody(),
    );
  }

  // --- ADDED: Helper widget to build the body content ---
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Error: $_errorMessage',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[300], fontSize: 16),
          ),
        ),
      );
    }

    if (_classesForSelectedDate.isEmpty) {
      return Center(
        child: Text(
          'No classes scheduled for this day.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    // Your existing ListView.builder for displaying the schedule
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 40.0),
      itemCount: _classesForSelectedDate.length,
      itemBuilder: (context, index) {
        // ... (The rest of your ListView.builder and item rendering code remains exactly the same)
        final teacherClass = _classesForSelectedDate[index];
        final status = _getClassStatus(teacherClass);

        final isLast = index == _classesForSelectedDate.length - 1;

        Color backgroundColor;
        Color textColor;
        Color timelineColor;
        TextDecoration textDecoration = TextDecoration.none;
        FontWeight fontWeight;

        switch (status) {
          case ClassStatus.past:
            backgroundColor = Colors.grey[900]!;
            textColor = Colors.grey[600]!;
            timelineColor = Colors.grey[600]!;
            textDecoration = TextDecoration.lineThrough;
            fontWeight = FontWeight.normal;
            break;
          case ClassStatus.current:
            backgroundColor = const Color(0xFF4CAF50);
            textColor = Colors.black;
            timelineColor = Colors.white;
            fontWeight = FontWeight.bold;
            break;
          case ClassStatus.future:
            backgroundColor = Colors.white;
            textColor = Colors.black;
            timelineColor = Colors.white;
            fontWeight = FontWeight.normal;
            break;
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 2,
                        color: index == 0 ? Colors.transparent : timelineColor,
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: status == ClassStatus.current ? Colors.white : Colors.transparent,
                        border: Border.all(
                          color: timelineColor,
                          width: 2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast ? Colors.transparent : timelineColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                teacherClass.className,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: fontWeight,
                                  decoration: textDecoration,
                                ),
                              ),
                            ),
                            Text(
                              '${teacherClass.startTime.format(context)} - ${teacherClass.endTime.format(context)}',
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: fontWeight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          teacherClass.venue,
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                            decoration: textDecoration,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      },
    );
  }
}