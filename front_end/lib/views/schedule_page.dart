import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart'; // Import for date formatting
import 'add_task_page.dart'; // Import the new page

// Data model for a single schedule task
class Task {
  final String title;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isOfficial; // To distinguish between college classes and user tasks

  Task({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isOfficial = false, // Default to not being an official class
  });
}

// Enum to represent the status of a task
enum TaskStatus { past, current, future }

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // --- STATE MANAGEMENT ---
  DateTime _selectedDate = DateTime.now();
  List<Task> _tasksForSelectedDate = [];
  late Timer _timer;

  // --- DATA SIMULATION FOR MULTIPLE DAYS ---
  // In a real app, this data would come from your database.
  final Map<DateTime, List<Task>> _allSchedules = {
    // Today's Schedule
    DateTime.now(): [
      Task(title: 'DBMS Class', startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 10, minute: 0), isOfficial: true),
      Task(title: 'DSA Class', startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 11, minute: 30), isOfficial: true),
      Task(title: 'Music Class', startTime: const TimeOfDay(hour: 12, minute: 0), endTime: const TimeOfDay(hour: 13, minute: 0)),
      Task(title: 'CP Lab', startTime: const TimeOfDay(hour: 14, minute: 0), endTime: const TimeOfDay(hour: 16, minute: 0), isOfficial: true),
      Task(title: 'Gym', startTime: const TimeOfDay(hour: 17, minute: 30), endTime: const TimeOfDay(hour: 18, minute: 30)),
    ],
    // Yesterday's Schedule
    DateTime.now().subtract(const Duration(days: 1)): [
      Task(title: 'History Lecture', startTime: const TimeOfDay(hour: 11, minute: 0), endTime: const TimeOfDay(hour: 12, minute: 30), isOfficial: true),
      Task(title: 'Project Work', startTime: const TimeOfDay(hour: 14, minute: 0), endTime: const TimeOfDay(hour: 17, minute: 0)),
    ],
    // Tomorrow's Schedule
    DateTime.now().add(const Duration(days: 1)): [
      Task(title: 'Physics Lab', startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 13, minute: 0), isOfficial: true),
      Task(title: 'Study Group', startTime: const TimeOfDay(hour: 15, minute: 0), endTime: const TimeOfDay(hour: 16, minute: 30)),
    ]
  };


  @override
  void initState() {
    super.initState();
    _loadTasksForSelectedDate();
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

  // --- CORRECTED FUNCTION TO LOAD TASKS FOR THE SELECTED DATE ---
  void _loadTasksForSelectedDate() {
    DateTime normalizedDate = DateUtils.dateOnly(_selectedDate);

    // --- DATABASE LOGIC (COMMENTED OUT) ---
    /*
    Future<void> _fetchScheduleForDate(DateTime date) async {
      print("Fetching schedule for ${DateFormat.yMd().format(date)}...");
      try {
        final token = await _storage.read(key: 'auth_token');
        if (token == null) return;

        // Example endpoint: /api/v1/student/schedule?date=2025-09-10
        final url = Uri.parse('http://192.168.0.104/api/v1/student/schedule?date=${DateFormat('yyyy-MM-dd').format(date)}');
        final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

        if (response.statusCode == 200 && mounted) {
          // Parse the response and update the state
          // ...
          setState(() {
            // _tasksForSelectedDate = parsedTasks;
          });
        }
      } catch (e) {
        print("Error fetching schedule for date: $e");
      }
    }
    // Instead of the map lookup below, you would call:
    // await _fetchScheduleForDate(_selectedDate);
    */

    // --- FIX: Safely find and assign tasks ---
    DateTime? matchingKey;
    for (var key in _allSchedules.keys) {
      if (DateUtils.isSameDay(key, normalizedDate)) {
        matchingKey = key;
        break;
      }
    }

    setState(() {
      if (matchingKey != null) {
        _tasksForSelectedDate = _allSchedules[matchingKey]!;
      } else {
        // If no schedule is found for the selected date, show an empty list.
        _tasksForSelectedDate = [];
      }
    });
  }


  // --- NEW: FUNCTION TO SHOW THE CALENDAR ---
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
      _loadTasksForSelectedDate();
    }
  }

  void _addTask(Task newTask) {
    // Logic remains mostly the same, but now it adds to the map
    DateTime normalizedDate = DateUtils.dateOnly(_selectedDate);

    // Create a mutable copy of the tasks for the selected day
    List<Task> tasksForDay = List<Task>.from(_allSchedules[normalizedDate] ?? []);

    // Perform conflict check and removal
    tasksForDay.removeWhere((existingTask) {
      final today = _selectedDate;
      DateTime newStartTime = DateTime(today.year, today.month, today.day, newTask.startTime.hour, newTask.startTime.minute);
      DateTime newEndTime = DateTime(today.year, today.month, today.day, newTask.endTime.hour, newTask.endTime.minute);
      DateTime existingStartTime = DateTime(today.year, today.month, today.day, existingTask.startTime.hour, existingTask.startTime.minute);
      DateTime existingEndTime = DateTime(today.year, today.month, today.day, existingTask.endTime.hour, existingTask.endTime.minute);
      return newStartTime.isBefore(existingEndTime) && newEndTime.isAfter(existingStartTime);
    });

    // Add new task and sort
    tasksForDay.add(newTask);
    tasksForDay.sort((a, b) {
      double aTime = a.startTime.hour + a.startTime.minute / 60.0;
      double bTime = b.startTime.hour + b.startTime.minute / 60.0;
      return aTime.compareTo(bTime);
    });

    // Update the main schedule map and the currently displayed list
    setState(() {
      _allSchedules[normalizedDate] = tasksForDay;
      _tasksForSelectedDate = tasksForDay;
    });
  }

  Future<void> _removeTask(Task task) async {
    if (task.isOfficial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Official college classes cannot be removed.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to remove the task "${task.title}"?', style: const TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        DateTime normalizedDate = DateUtils.dateOnly(_selectedDate);
        _allSchedules[normalizedDate]?.remove(task);
        _loadTasksForSelectedDate(); // Refresh the displayed list
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.title}" removed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- UPDATED: LOGIC TO DETERMINE TASK STATUS BASED ON SELECTED DATE ---
  TaskStatus _getTaskStatus(Task task) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDay = DateUtils.dateOnly(_selectedDate);

    if (selectedDay.isBefore(today)) {
      return TaskStatus.past;
    }

    if (selectedDay.isAfter(today)) {
      return TaskStatus.future;
    }

    // Only do time-based comparison if it's today
    final now = TimeOfDay.now();
    final startTime = DateTime(today.year, today.month, today.day, task.startTime.hour, task.startTime.minute);
    final endTime = DateTime(today.year, today.month, today.day, task.endTime.hour, task.endTime.minute);
    final nowTime = DateTime(today.year, today.month, today.day, now.hour, now.minute);

    if (nowTime.isAfter(endTime)) {
      return TaskStatus.past;
    } else if (!nowTime.isBefore(startTime) && nowTime.isBefore(endTime)) {
      return TaskStatus.current;
    } else {
      return TaskStatus.future;
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- DYNAMIC APP BAR TITLE ---
    final bool isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final String title = isToday ? "Today's Schedule" : DateFormat.yMMMd().format(_selectedDate);

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
        // --- NEW: CALENDAR BUTTON ---
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showCalendar,
          ),
        ],
      ),
      body: _tasksForSelectedDate.isEmpty
          ? Center(
        child: Text(
          'No tasks scheduled for this day.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 100.0),
        itemCount: _tasksForSelectedDate.length,
        itemBuilder: (context, index) {
          final task = _tasksForSelectedDate[index];
          final status = _getTaskStatus(task);

          final isLast = index == _tasksForSelectedDate.length - 1;

          Color backgroundColor;
          Color textColor;
          Color timelineColor;
          TextDecoration textDecoration = TextDecoration.none;
          FontWeight fontWeight;

          switch (status) {
            case TaskStatus.past:
              backgroundColor = Colors.grey[900]!;
              textColor = Colors.grey[600]!;
              timelineColor = Colors.grey[600]!;
              textDecoration = TextDecoration.lineThrough;
              fontWeight = FontWeight.normal;
              break;
            case TaskStatus.current:
              backgroundColor = const Color(0xFF4CAF50);
              textColor = Colors.black;
              timelineColor = Colors.white;
              fontWeight = FontWeight.bold;
              break;
            case TaskStatus.future:
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
                          color: status == TaskStatus.current ? Colors.white : Colors.transparent,
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
                    child: GestureDetector(
                      onLongPress: () {
                        _removeTask(task);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: fontWeight,
                                decoration: textDecoration,
                              ),
                            ),
                            Text(
                              '${task.startTime.format(context)} - ${task.endTime.format(context)}',
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: fontWeight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newTask = await Navigator.push<Task>(
            context,
            MaterialPageRoute(builder: (context) => const AddTaskPage()),
          );

          if (newTask != null) {
            _addTask(newTask);
          }
        },
        label: const Text('Add Task'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

