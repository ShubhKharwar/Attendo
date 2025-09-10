import 'package:flutter/material.dart';
import 'student_scan.dart';
import 'leaderboard_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'loginview.dart';
import 'schedule_page.dart'; // Import the new schedule page
import 'dart:async'; // Import for Timer

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'Loading...';
  Task? _currentTask; // Use the Task model
  final _storage = const FlutterSecureStorage();
  late Timer _timer;

  // --- 1. SIMULATED DATA (used for now) ---
  // This list is used while the backend logic is commented out.
  List<Task> _tasks = [
    Task(title: 'DBMS Class', startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 10, minute: 0)),
    Task(title: 'DSA Class', startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 11, minute: 30)),
    Task(title: 'Music Class', startTime: const TimeOfDay(hour: 12, minute: 0), endTime: const TimeOfDay(hour: 13, minute: 0)),
    Task(title: 'CP Lab', startTime: const TimeOfDay(hour: 14, minute: 0), endTime: const TimeOfDay(hour: 16, minute: 0)),
    Task(title: 'Gym', startTime: const TimeOfDay(hour: 17, minute: 30), endTime: const TimeOfDay(hour: 18, minute: 30)),
    Task(title: 'Family Time', startTime: const TimeOfDay(hour: 19, minute: 0), endTime: const TimeOfDay(hour: 21, minute: 0)),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _findCurrentTask();
    // _fetchSchedule(); // Call this when you are ready to use the backend

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _findCurrentTask();
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
  Future<void> _fetchSchedule() async {
    print("Fetching schedule from backend...");
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        print("No token for schedule fetch.");
        return;
      }

      // Replace with your actual schedule endpoint
      final url = Uri.parse('http://192.168.0.104:3000/api/v1/student/schedule');

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

        // Map the JSON data to your Task model
        final List<Task> fetchedTasks = scheduleData.map((taskData) {
          return Task(
            title: taskData['title'],
            startTime: _parseTime(taskData['startTime']),
            endTime: _parseTime(taskData['endTime']),
          );
        }).toList();

        setState(() {
          _tasks = fetchedTasks; // Replace the manual list with data from the database
        });

        _findCurrentTask(); // Update the current task display after fetching
        print("Schedule fetched successfully!");

      } else {
        print('Failed to load schedule. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred while fetching the schedule: $e');
    }
  }
  */

  void _findCurrentTask() {
    final now = TimeOfDay.now();
    final today = DateTime.now();
    Task? activeTask;

    for (final task in _tasks) {
      final startTime = DateTime(today.year, today.month, today.day, task.startTime.hour, task.startTime.minute);
      final endTime = DateTime(today.year, today.month, today.day, task.endTime.hour, task.endTime.minute);
      final nowTime = DateTime(today.year, today.month, today.day, now.hour, now.minute);

      if (!nowTime.isBefore(startTime) && nowTime.isBefore(endTime)) {
        activeTask = task;
        break;
      }
    }

    setState(() {
      _currentTask = activeTask;
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final token = await _storage.read(key: 'auth_token');

      if (token == null) {
        print('No token found, navigating to login.');
        _logout();
        return;
      }

      // Try to load cached name first
      final cachedName = await _storage.read(key: 'student_name');
      if (cachedName != null && mounted) {
        setState(() {
          _userName = cachedName;
        });
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
        final name = data['name'] ?? 'User';

        // Cache the name for future use
        await _storage.write(key: 'student_name', value: name);

        setState(() {
          _userName = name;
        });
      } else if (response.statusCode == 401 && mounted) {
        print('Token is invalid or expired. Logging out.');
        _logout();
      } else {
        print('Failed to load user data. Status code: ${response.statusCode}');
        // Only show error if we don't have cached data
        if (mounted && cachedName == null) {
          setState(() => _userName = 'Error');
        }
      }
    } catch (e) {
      print('An error occurred while fetching user data: $e');
      // Try to get cached name before showing error
      final cachedName = await _storage.read(key: 'student_name');
      if (mounted) {
        setState(() {
          _userName = cachedName ?? 'Error';
        });
      }
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'student_name'); // Clear cached name
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
              _buildNextTaskCard(),
              const SizedBox(height: 50),
              _buildMarkAttendanceButton(),
              const SizedBox(height: 30),
              _buildLeaderboardButton(),
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
          _userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNextTaskCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SchedulePage()),
        );
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
                    _currentTask?.title ?? 'No current task',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_currentTask == null)
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
            if (_currentTask != null)
              Text(
                '${_currentTask!.startTime.format(context)} - ${_currentTask!.endTime.format(context)}',
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

  Widget _buildMarkAttendanceButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScanningPage()),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark your\nattendance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'see this month\'s attendance',
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
            child: const Icon(Icons.qr_code_scanner,
                color: Colors.white, size: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LeaderboardPage()),
        );
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
              'Your leaderboard rank is 15!',
              style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 10),
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.blue,
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
              'Navigation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pages, color: Colors.white),
            title: const Text('Page 1', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.pages, color: Colors.white),
            title: const Text('Page 2', style: TextStyle(color: Colors.white)),
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
            icon:
            const Icon(Icons.emoji_events_outlined, color: Colors.grey, size: 30),
            onPressed: () {},
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScanningPage()),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4CAF50),
              ),
              child: const Icon(Icons.qr_code_scanner,
                  color: Colors.white, size: 35),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.book_outlined, color: Colors.grey, size: 30),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
