import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'add_task_page.dart'; // Your page for adding tasks

// --- MODIFIED: Task model with a factory constructor for API data ---
class Task {
  final String title;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isOfficial;

  Task({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isOfficial = false,
  });

  // --- ADDED: Factory constructor to parse from API response ---
  factory Task.fromApi(Map<String, dynamic> json) {
    TimeOfDay startTime = _parseTime(json['startTime'] ?? '00:00');
    TimeOfDay endTime = _calculateEndTime(startTime, json['duration'] ?? '0 minutes');

    return Task(
      title: json['subject'] ?? 'Unknown Class',
      startTime: startTime,
      endTime: endTime,
      isOfficial: true, // All tasks from the API are official
    );
  }
}

// --- ADDED: Helper functions to parse time from your backend's format ---
TimeOfDay _parseTime(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return const TimeOfDay(hour: 0, minute: 0);
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

TimeOfDay _calculateEndTime(TimeOfDay startTime, String duration) {
  final minutesToAdd = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  final now = DateTime.now();
  final startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
  final endDateTime = startDateTime.add(Duration(minutes: minutesToAdd));
  return TimeOfDay.fromDateTime(endDateTime);
}

// Enum remains the same
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

  // --- ADDED: State for API calls and local user tasks ---
  bool _isLoading = true;
  String? _errorMessage;
  final _storage = const FlutterSecureStorage();
  List<Task> _userAddedTasks = []; // To hold tasks added by the user in the current session

  // --- REMOVED: The hardcoded _allSchedules map is no longer needed ---

  @override
  void initState() {
    super.initState();
    _fetchScheduleForDate(_selectedDate); // Fetch live data on initial load
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
      _userAddedTasks.clear(); // Clear personal tasks when changing days
    });

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      // 2. Format the date and construct the correct URL for the student endpoint
      final String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      // IMPORTANT: Replace 'YOUR_SERVER_IP' with your actual IP address
      final url = Uri.parse('http://192.168.0.104:3000/api/v1/student/schedule?date=$formattedDate');

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

        // Convert the API response into a list of official Task objects
        List<Task> officialTasks = classesJson.map((jsonItem) => Task.fromApi(jsonItem)).toList();

        // Update the UI with the fetched tasks
        _updateAndSortTasks(officialTasks);

      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load schedule.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _tasksForSelectedDate = []; // Clear data on error
      });
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- ADDED: Helper to combine official API tasks and local user tasks ---
  void _updateAndSortTasks(List<Task> officialTasks) {
    setState(() {
      // Combine the two lists
      _tasksForSelectedDate = [...officialTasks, ..._userAddedTasks];
      // Sort the combined list by start time
      _tasksForSelectedDate.sort((a, b) {
        double aTime = a.startTime.hour + a.startTime.minute / 60.0;
        double bTime = b.startTime.hour + b.startTime.minute / 60.0;
        return aTime.compareTo(bTime);
      });
    });
  }

  // --- MODIFIED: Calendar function now triggers the API fetch ---
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
      // Fetch live data for the newly selected date
      _fetchScheduleForDate(_selectedDate);
    }
  }

  // --- MODIFIED: _addTask now only handles user-added tasks ---
  void _addTask(Task newTask) {
    // Add the new personal task to our in-memory list
    _userAddedTasks.add(newTask);

    // Get the current list of official classes from the main state
    List<Task> officialTasks = _tasksForSelectedDate.where((task) => task.isOfficial).toList();

    // Re-combine the official classes with the updated personal task list and refresh the UI
    _updateAndSortTasks(officialTasks);
  }

  // --- MODIFIED: _removeTask now only handles user-added tasks ---
  Future<void> _removeTask(Task task) async {
    if (task.isOfficial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Official college classes cannot be removed.')),
      );
      return;
    }

    // Confirmation dialog logic remains the same...
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
      // Remove the task from our personal list
      _userAddedTasks.remove(task);

      // Re-combine and refresh the UI
      List<Task> officialTasks = _tasksForSelectedDate.where((task) => task.isOfficial).toList();
      _updateAndSortTasks(officialTasks);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task "${task.title}" removed.')),
      );
    }
  }

  // Task status logic remains the same
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
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showCalendar,
          ),
        ],
      ),
      // --- MODIFIED: Body now handles loading, error, and data states ---
      body: _buildBody(),
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

  // --- ADDED: Helper widget to build the body based on the current state ---
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

    if (_tasksForSelectedDate.isEmpty) {
      return Center(
        child: Text(
          'No tasks scheduled for this day.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    // Your existing ListView.builder for displaying the schedule
    return ListView.builder(
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
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: fontWeight,
                                decoration: textDecoration,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
    );
  }
}