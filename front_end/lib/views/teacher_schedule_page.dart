import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart'; // Import for date formatting

// Data model for a teacher's class
class TeacherClass {
  final String className;
  final String venue;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  TeacherClass({
    required this.className,
    required this.venue,
    required this.startTime,
    required this.endTime,
  });
}

// Enum to represent the status of a class
enum ClassStatus { past, current, future }

class TeacherSchedulePage extends StatefulWidget {
  const TeacherSchedulePage({super.key});

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  // --- STATE MANAGEMENT ---
  DateTime _selectedDate = DateTime.now();
  List<TeacherClass> _classesForSelectedDate = [];
  late Timer _timer;

  // --- DATA SIMULATION FOR MULTIPLE DAYS ---
  // In a real app, this data would come from your database.
  final Map<DateTime, List<TeacherClass>> _allSchedules = {
    // Today's Schedule
    DateTime.now(): [
      TeacherClass(
        className: 'Database Management Systems',
        venue: 'Room 301, CS Block',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      ),
      TeacherClass(
        className: 'Data Structures & Algorithms',
        venue: 'Lab 2, IT Block',
        startTime: const TimeOfDay(hour: 11, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 30),
      ),
      TeacherClass(
        className: 'Software Engineering',
        venue: 'Room 205, Main Block',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
      ),
      TeacherClass(
        className: 'Computer Networks',
        venue: 'Room 401, CS Block',
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 30),
      ),
    ],
    // Yesterday's Schedule
    DateTime.now().subtract(const Duration(days: 1)): [
      TeacherClass(
        className: 'Operating Systems',
        venue: 'Room 202, CS Block',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
      ),
      TeacherClass(
        className: 'Computer Graphics',
        venue: 'Lab 3, IT Block',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 0),
      ),
    ],
    // Tomorrow's Schedule
    DateTime.now().add(const Duration(days: 1)): [
      TeacherClass(
        className: 'Machine Learning',
        venue: 'Room 405, CS Block',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 0),
      ),
      TeacherClass(
        className: 'Artificial Intelligence',
        venue: 'Room 303, CS Block',
        startTime: const TimeOfDay(hour: 15, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 30),
      ),
    ]
  };

  @override
  void initState() {
    super.initState();
    _loadClassesForSelectedDate();
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

  // --- FUNCTION TO LOAD CLASSES FOR THE SELECTED DATE ---
  void _loadClassesForSelectedDate() {
    DateTime normalizedDate = DateUtils.dateOnly(_selectedDate);

    // --- DATABASE LOGIC (COMMENTED OUT) ---
    /*
    Future<void> _fetchScheduleForDate(DateTime date) async {
      print("Fetching teacher schedule for ${DateFormat.yMd().format(date)}...");
      try {
        final token = await _storage.read(key: 'auth_token');
        if (token == null) return;

        // Example endpoint: /api/v1/teacher/schedule?date=2025-09-10
        final url = Uri.parse('http://192.168.0.104/api/v1/teacher/schedule?date=${DateFormat('yyyy-MM-dd').format(date)}');
        final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

        if (response.statusCode == 200 && mounted) {
          // Parse the response and update the state
          // ...
          setState(() {
            // _classesForSelectedDate = parsedClasses;
          });
        }
      } catch (e) {
        print("Error fetching teacher schedule for date: $e");
      }
    }
    // Instead of the map lookup below, you would call:
    // await _fetchScheduleForDate(_selectedDate);
    */

    // --- Find and assign classes ---
    DateTime? matchingKey;
    for (var key in _allSchedules.keys) {
      if (DateUtils.isSameDay(key, normalizedDate)) {
        matchingKey = key;
        break;
      }
    }

    setState(() {
      if (matchingKey != null) {
        _classesForSelectedDate = _allSchedules[matchingKey]!;
      } else {
        // If no schedule is found for the selected date, show an empty list.
        _classesForSelectedDate = [];
      }
    });
  }

  // --- FUNCTION TO SHOW THE CALENDAR ---
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
      _loadClassesForSelectedDate();
    }
  }

  // --- LOGIC TO DETERMINE CLASS STATUS BASED ON SELECTED DATE ---
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
    // --- DYNAMIC APP BAR TITLE ---
    final bool isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final String title = isToday ? "Today's Classes" : DateFormat.yMMMd().format(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
        // --- CALENDAR BUTTON ---
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showCalendar,
          ),
        ],
      ),
      body: _classesForSelectedDate.isEmpty
          ? Center(
        child: Text(
          'No classes scheduled for this day.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 40.0),
        itemCount: _classesForSelectedDate.length,
        itemBuilder: (context, index) {
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
      ),
    );
  }
}
