import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'loginview.dart';
import 'dart:async'; // Import for Timer
import 'teacher_attendance_page.dart';
import 'teacher_schedule_page.dart';

// Import your TeacherAttendancePage
// import 'teacher_attendance_page.dart'; // Uncomment and adjust path as needed

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

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String _teacherName = 'Loading...';
  TeacherClass? _nextClass; // Use the TeacherClass model
  final _storage = const FlutterSecureStorage();
  late Timer _timer;

  // --- 1. SIMULATED DATA (used for now) ---
  // This list is used while the backend logic is commented out.
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

  // --- 2. NEW BACKEND LOGIC (commented out) ---
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

    for (final classItem in _classes) {
      final startTime = DateTime(today.year, today.month, today.day, classItem.startTime.hour, classItem.startTime.minute);
      final nowTime = DateTime(today.year, today.month, today.day, now.hour, now.minute);

      if (nowTime.isBefore(startTime)) {
        upcomingClass = classItem;
        break;
      }
    }

    setState(() {
      _nextClass = upcomingClass;
    });
  }

  Future<void> _fetchTeacherData() async {
    try {
      final token = await _storage.read(key: 'auth_token');

      if (token == null) {
        print('No token found, navigating to login.');
        _logout();
        return;
      }

      final url = Uri.parse('http://192.168.0.104:3000/api/v1/student/profile');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _teacherName = data['name'] ?? 'Teacher';
        });
      } else if (response.statusCode == 401 && mounted) {
        print('Token is invalid or expired. Logging out.');
        _logout();
      } else {
        print('Failed to load teacher data. Status code: ${response.statusCode}');
        if (mounted) setState(() => _teacherName = 'Error');
      }
    } catch (e) {
      print('An error occurred while fetching teacher data: $e');
      if (mounted) setState(() => _teacherName = 'Error');
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'auth_token');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginView()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: _buildAppDrawer(),
      bottomNavigationBar: _buildBottomNavBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 40),
              _buildGreeting(),
              const SizedBox(height: 50),
              _buildNextClassCard(),
              const SizedBox(height: 50),
              _buildTakeAttendanceButton(),
              const SizedBox(height: 30),
              _buildTeacherStatsButton(),
              const Spacer(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'profile') {
              print('Profile selected');
            } else if (value == 'logout') {
              _logout();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'profile',
              child: Text('Profile'),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Text('Logout'),
            ),
          ],
          icon: const Icon(Icons.person, color: Colors.white, size: 30),
        ),
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 30),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hi,',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w300,
          ),
        ),
        Text(
          _teacherName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNextClassCard() {
    return GestureDetector(
      onTap: () {Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TeacherSchedulePage()),);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nextClass?.className ?? 'No upcoming classes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_nextClass != null)
                    Text(
                      _nextClass!.venue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  else
                    const Text(
                      'Enjoy your free time!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16), // Add spacing between title and time
            if (_nextClass != null)
              Text(
                '${_nextClass!.startTime.format(context)} - ${_nextClass!.endTime.format(context)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTakeAttendanceButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TeacherAttendancePage()),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Take\nattendance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'start attendance session',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.qr_code,
                color: Colors.white, size: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherStatsButton() {
    return GestureDetector(
      onTap: () {
        // Navigate to teacher statistics or analytics page
        print('Navigate to teacher statistics');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View attendance statistics',
              style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 10),
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.orange,
              child: Icon(Icons.analytics, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      backgroundColor: Colors.grey[900],
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF4CAF50),
            ),
            child: Text(
              'Teacher Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.white),
            title: const Text('My Schedule', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.analytics, color: Colors.white),
            title: const Text('Analytics', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.white),
            title: const Text('Students', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.grey, size: 30),
            onPressed: () {},
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TeacherAttendancePage()),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4CAF50),
              ),
              child: const Icon(Icons.qr_code,
                  color: Colors.white, size: 35),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_outlined, color: Colors.grey, size: 30),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
