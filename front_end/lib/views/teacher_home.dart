import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'loginview.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import 'teacher_attendance_page.dart';
import 'teacher_schedule_page.dart';
import 'teacher_upload_page.dart';

// --- Data Model & Color Constants ---
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

const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kBackgroundColor = Colors.black;
const Color kCardColor = Color(0xFF1E1E1E);

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String _teacherName = 'Loading...';
  TeacherClass? _nextClass;
  final _storage = const FlutterSecureStorage();
  late Timer _timer;

  // --- 1. SIMULATED DATA (from your logic) ---
  List<TeacherClass> _classes = [
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
  ];

  @override
  void initState() {
    super.initState();
    _fetchTeacherData();
    _findNextClass();
    // _fetchTeacherSchedule(); // Call this when you are ready to use the backend

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _findNextClass();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- 2. BACKEND LOGIC (from your code, commented out) ---
  /*
  Future<void> _fetchTeacherSchedule() async {
    print("Fetching teacher schedule from backend...");
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        print("No token for schedule fetch.");
        return;
      }

      // Replace with your actual teacher schedule endpoint
      final url = Uri.parse('http://192.168.0.104:3000/api/v1/teacher/schedule');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> scheduleData = json.decode(response.body);

        // Helper function to parse time strings like "14:30"
        TimeOfDay _parseTime(String time) {
          final parts = time.split(':');
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }

        // Map the JSON data to your TeacherClass model
        final List<TeacherClass> fetchedClasses = scheduleData.map((classData) {
          return TeacherClass(
            className: classData['className'],
            venue: classData['venue'],
            startTime: _parseTime(classData['startTime']),
            endTime: _parseTime(classData['endTime']),
          );
        }).toList();

        setState(() {
          _classes = fetchedClasses; // Replace the manual list with data from the database
        });

        _findNextClass(); // Update the next class display after fetching
        print("Teacher schedule fetched successfully!");

      } else {
        print('Failed to load teacher schedule. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred while fetching the teacher schedule: $e');
    }
  }
  */

  void _findNextClass() {
    final now = TimeOfDay.now();
    final today = DateTime.now();
    TeacherClass? upcomingClass;

    // Sort classes by start time to ensure the next one is found correctly
    _classes.sort((a, b) {
      final aDateTime = DateTime(today.year, today.month, today.day, a.startTime.hour, a.startTime.minute);
      final bDateTime = DateTime(today.year, today.month, today.day, b.startTime.hour, b.startTime.minute);
      return aDateTime.compareTo(bDateTime);
    });

    for (final classItem in _classes) {
      final startTime = DateTime(today.year, today.month, today.day, classItem.startTime.hour, classItem.startTime.minute);
      final nowTime = DateTime(today.year, today.month, today.day, now.hour, now.minute);

      if (nowTime.isBefore(startTime)) {
        upcomingClass = classItem;
        break; // Found the very next class, so we can stop looping
      }
    }

    if (mounted) {
      setState(() {
        _nextClass = upcomingClass;
      });
    }
  }

  Future<void> _fetchTeacherData() async {
    try {
      final token = await _storage.read(key: 'auth_token');

      if (token == null) {
        print('No token found, navigating to login.');
        _logout();
        return;
      }

      final cachedName = await _storage.read(key: 'teacher_name');
      if (cachedName != null && mounted) {
        setState(() {
          _teacherName = cachedName;
        });
      }

      final url = Uri.parse('http://192.168.0.104:3000/api/v1/student/profile'); // ⚠️ Should this be /teacher/profile ?

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final name = data['name'] ?? 'Teacher';
        await _storage.write(key: 'teacher_name', value: name);
        setState(() {
          _teacherName = name;
        });
      } else if (response.statusCode == 401 && mounted) {
        print('Token is invalid or expired. Logging out.');
        _logout();
      } else {
        print('Failed to load teacher data. Status code: ${response.statusCode}');
        if (mounted && cachedName == null) {
          setState(() => _teacherName = 'Error');
        }
      }
    } catch (e) {
      print('An error occurred while fetching teacher data: $e');
      final cachedName = await _storage.read(key: 'teacher_name');
      if (mounted) {
        setState(() {
          _teacherName = cachedName ?? 'Error';
        });
      }
    }
  }

  Future<void> _logout() async {
    await _storage.deleteAll(); // deleteAll is simpler and safer
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginView()),
            (Route<dynamic> route) => false,
      );
    }
  }

  // --- UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      drawer: _buildAppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherAttendancePage())),
        backgroundColor: kPrimaryColor,
        tooltip: 'Take Attendance',
        child: const Icon(Icons.qr_code_2, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildTopBar(),
                const SizedBox(height: 30),
                _buildGreeting(),
                const SizedBox(height: 30),
                _buildNextClassCard(),
                const SizedBox(height: 30),
                _buildSectionHeader("Tools"),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: 'Take Attendance',
                  icon: Icons.qr_code_scanner,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherAttendancePage()));
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  title: 'View Statistics',
                  icon: Icons.analytics,
                  onTap: () {
                    // Navigate to stats page
                  },
                ),
                const SizedBox(height: 100), // Space for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI HELPER WIDGETS ---
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const CircleAvatar(
          radius: 20,
          backgroundColor: kCardColor,
          child: Icon(Icons.person, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $_teacherName',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Here are your tasks for the day.",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildNextClassCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherSchedulePage())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nextClass?.className ?? 'No upcoming classes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _nextClass != null ? _nextClass!.venue : 'Enjoy your free time!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            if (_nextClass != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Starts at: ${_nextClass!.startTime.format(context)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BottomAppBar _buildBottomAppBar() {
    return BottomAppBar(
      color: kCardColor,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.grey, size: 30),
            onPressed: () {},
            tooltip: 'Statistics',
          ),
          const SizedBox(width: 48), // The space for the notch
          IconButton(
            icon: const Icon(Icons.people_outlined, color: Colors.grey, size: 30),
            onPressed: () {},
            tooltip: 'Students',
          ),
        ],
      ),
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      backgroundColor: kCardColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(color: kPrimaryColor),
            child: Text(
              'Teacher Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.white70),
            title: const Text('My Schedule', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherSchedulePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.white70),
            title: const Text('Upload Data', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherUploadPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics, color: Colors.white70),
            title: const Text('Analytics', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }
}