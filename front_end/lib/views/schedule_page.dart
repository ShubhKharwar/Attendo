import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'add_task_page.dart'; // Your page for adding tasks

// --- Task model and helper functions remain the same ---
class Task {
  final String title;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isOfficial;
  final String? taskType;    // 'class' or 'recommendation'
  final String? reasoning;   // Why recommended
  final String? urgencyLevel; // low, medium, high
  final String? taskId;      // For recommendations

  Task({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isOfficial = false,
    this.taskType,
    this.reasoning,
    this.urgencyLevel,
    this.taskId,
  });

  factory Task.fromApi(Map<String, dynamic> json) {
    TimeOfDay startTime = _parseTime(json['startTime'] ?? '00:00');
    TimeOfDay endTime = _calculateEndTime(startTime, json['duration'] ?? '0 minutes');

    return Task(
      title: json['subject'] ?? 'Unknown Class',
      startTime: startTime,
      endTime: endTime,
      isOfficial: json['isOfficial'] ?? (json['type'] == 'class'),
      taskType: json['type'] ?? 'class',
      reasoning: json['reasoning'],
      urgencyLevel: json['urgencyLevel'],
      taskId: json['taskId'],
    );
  }
}

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

enum TaskStatus { past, current, future }

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _selectedDate = DateTime.now();
  List<Task> _tasksForSelectedDate = [];
  late Timer _timer;
  bool _isLoading = true;
  String? _errorMessage;
  final _storage = const FlutterSecureStorage();
  List<Task> _userAddedTasks = [];

  // --- NEW: State to track the index of the expanded task ---
  int? _expandedTaskIndex;

  @override
  void initState() {
    super.initState();
    _fetchScheduleForDate(_selectedDate);
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- All backend and data fetching logic remains the same ---
  Future<void> _fetchScheduleForDate(DateTime date) async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _userAddedTasks.clear();
    _expandedTaskIndex = null;
  });

  final String formattedDate = DateFormat('yyyy-MM-dd').format(date);
  try {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final url = Uri.parse('http://192.168.0.102:3000/api/v1/student/schedule?date=$formattedDate');
    
    print('🗓️ Fetching schedule for SPECIFIC date: $formattedDate'); // Debug log
    
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (!mounted) return;
    
    print('📡 Response status: ${response.statusCode}'); // Debug log
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List classesJson = data['classes'] ?? [];
      
      // Enhanced logging
      int recommendationCount = classesJson.where((item) => item['type'] == 'recommendation').length;
      int classCount = classesJson.where((item) => item['type'] == 'class').length;
      
      print('📊 Schedule for $formattedDate:');
      print('   - Regular classes: $classCount');
      print('   - Recommendations: $recommendationCount');
      print('   - Total items: ${classesJson.length}');
      
      // Log each recommendation for debugging
      classesJson.where((item) => item['type'] == 'recommendation').forEach((rec) {
        print('   📝 Recommendation: ${rec['subject']} at ${rec['startTime']} (${rec['urgencyLevel']})');
      });
      
      List<Task> officialTasks = classesJson.map((jsonItem) => Task.fromApi(jsonItem)).toList();
      _updateAndSortTasks(officialTasks);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load schedule.');
    }
  } catch (e) {
    print('❌ Error fetching schedule for $formattedDate: $e');
    if (!mounted) return;
    setState(() {
      _errorMessage = e.toString();
      _tasksForSelectedDate = [];
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  void _updateAndSortTasks(List<Task> officialTasks) {
    setState(() {
      _tasksForSelectedDate = [...officialTasks, ..._userAddedTasks];
      _tasksForSelectedDate.sort((a, b) {
        double aTime = a.startTime.hour + a.startTime.minute / 60.0;
        double bTime = b.startTime.hour + b.startTime.minute / 60.0;
        return aTime.compareTo(bTime);
      });
    });
  }
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
      _fetchScheduleForDate(_selectedDate);
    }
  }
  void _addTask(Task newTask) {
    _userAddedTasks.add(newTask);
    List<Task> officialTasks = _tasksForSelectedDate.where((task) => task.isOfficial).toList();
    _updateAndSortTasks(officialTasks);
  }
  Future<void> _removeTask(Task task) async {
    if (task.isOfficial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Official college classes cannot be removed.')),
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
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );

    if (confirmed == true) {
      _userAddedTasks.remove(task);
      List<Task> officialTasks = _tasksForSelectedDate.where((task) => task.isOfficial).toList();
      _updateAndSortTasks(officialTasks);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task "${task.title}" removed.')));
    }
  }
  TaskStatus _getTaskStatus(Task task) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDay = DateUtils.dateOnly(_selectedDate);
    if (selectedDay.isBefore(today)) return TaskStatus.past;
    if (selectedDay.isAfter(today)) return TaskStatus.future;
    final now = TimeOfDay.now();
    final startTime = DateTime(today.year, today.month, today.day, task.startTime.hour, task.startTime.minute);
    final endTime = DateTime(today.year, today.month, today.day, task.endTime.hour, task.endTime.minute);
    final nowTime = DateTime(today.year, today.month, today.day, now.hour, now.minute);
    if (nowTime.isAfter(endTime)) return TaskStatus.past;
    if (!nowTime.isBefore(startTime) && nowTime.isBefore(endTime)) return TaskStatus.current;
    return TaskStatus.future;
  }
  // --- END of unchanged logic ---

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
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [IconButton(icon: const Icon(Icons.calendar_today, color: Colors.white), onPressed: _showCalendar)],
      ),
      // --- MODIFIED: Added GestureDetector to collapse card on outside tap ---
      body: GestureDetector(
        onTap: () {
          // If a card is expanded, tapping outside collapses it
          if (_expandedTaskIndex != null) {
            setState(() {
              _expandedTaskIndex = null;
            });
          }
        },
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newTask = await Navigator.push<Task>(context, MaterialPageRoute(builder: (context) => const AddTaskPage()));
          if (newTask != null) _addTask(newTask);
        },
        label: const Text('Add Task'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));
    if (_errorMessage != null) return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('Error: $_errorMessage', textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300], fontSize: 16))));
    if (_tasksForSelectedDate.isEmpty) return Center(child: Text('No tasks scheduled for this day.', style: TextStyle(color: Colors.grey[600], fontSize: 16)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 100.0),
      itemCount: _tasksForSelectedDate.length,
      itemBuilder: (context, index) {
        final task = _tasksForSelectedDate[index];
        final status = _getTaskStatus(task);
        final isLast = index == _tasksForSelectedDate.length - 1;
        // --- NEW: Check if the current task is the expanded one ---
        final bool isExpanded = _expandedTaskIndex == index;

        Color backgroundColor, textColor, timelineColor;
        TextDecoration textDecoration = TextDecoration.none;
        FontWeight fontWeight;

        switch (status) {
          case TaskStatus.past:
            backgroundColor = Colors.grey[900]!; textColor = Colors.grey[600]!; timelineColor = Colors.grey[600]!; textDecoration = TextDecoration.lineThrough; fontWeight = FontWeight.normal;
            break;
          case TaskStatus.current:
            backgroundColor = const Color(0xFF4CAF50); textColor = Colors.black; timelineColor = Colors.white; fontWeight = FontWeight.bold;
            break;
          case TaskStatus.future:
            backgroundColor = Colors.white; textColor = Colors.black; timelineColor = Colors.white; fontWeight = FontWeight.normal;
            break;
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline connector UI remains the same
              SizedBox(
                width: 20,
                child: Column(children: [
                  Expanded(child: Container(width: 2, color: index == 0 ? Colors.transparent : timelineColor)),
                  Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: status == TaskStatus.current ? Colors.white : Colors.transparent, border: Border.all(color: timelineColor, width: 2))),
                  Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : timelineColor)),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  // --- MODIFIED: GestureDetector now toggles expansion state ---
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        // If already expanded, collapse it. Otherwise, expand it.
                        _expandedTaskIndex = isExpanded ? null : index;
                      });
                    },
                    onLongPress: () => _removeTask(task),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(isExpanded ? 24 : 50)), // Change radius on expand
                      // --- NEW: AnimatedSize for smooth transition ---
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: isExpanded
                            ? _buildExpandedContent(task, textColor, fontWeight, context)
                            : _buildCollapsedContent(task, textColor, fontWeight, textDecoration, context),
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

  // --- NEW: Widget for the collapsed card content ---
  Widget _buildCollapsedContent(Task task, Color textColor, FontWeight fontWeight, TextDecoration textDecoration, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            task.title,
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: fontWeight, decoration: textDecoration),
            overflow: TextOverflow.ellipsis, // Truncates long text
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${task.startTime.format(context)} - ${task.endTime.format(context)}',
          style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14, fontWeight: fontWeight),
        ),
      ],
    );
  }

  // --- NEW: Widget for the expanded card content ---
  Widget _buildExpandedContent(Task task, Color textColor, FontWeight fontWeight, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Important for AnimatedSize
      children: [
        Text(
          task.title, // No truncation
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: fontWeight),
        ),
        // --- Display reasoning for recommended tasks ---
        if (task.taskType == 'recommendation' && task.reasoning != null && task.reasoning!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.reasoning!,
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${task.startTime.format(context)} - ${task.endTime.format(context)}',
            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14, fontWeight: fontWeight),
          ),
        ),
      ],
    );
  }
}