import 'package:flutter/material.dart';
import 'student_scan.dart';
import 'leaderboard_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'loginview.dart';
import 'schedule_page.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'my_courses_page.dart';
import 'student_profile_page.dart';

// --- Data Model (Assuming Task class exists elsewhere, including for context) ---
class Task {
  final String title;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Task({required this.title, required this.startTime, required this.endTime});

  factory Task.fromApi(Map<String, dynamic> json) {
    TimeOfDay _parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return Task(
      title: json['course_name'] ?? 'Unknown Task',
      startTime: _parseTime(json['start_time']),
      endTime: _parseTime(json['end_time']),
    );
  }
}

// Define theme color for consistency
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kBackgroundColor = Colors.black;
const Color kCardColor = Color(0xFF1E1E1E); // A slightly lighter black for cards

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- All original state and logic is preserved ---
  String _userName = 'Loading...';
  Task? _currentTask;
  final _storage = const FlutterSecureStorage();
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUserData();
      _fetchSchedule();
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _fetchSchedule();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchSchedule() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return;

      final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final url = Uri.parse('http://10.252.6.161:3000/api/v1/student/schedule?date=$formattedDate');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> classesJson = data['classes'] ?? [];

        final List<Task> todaysTasks = classesJson
            .map((jsonItem) => Task.fromApi(jsonItem))
            .toList();

        _findCurrentTask(todaysTasks);

      } else {
        print('Failed to load schedule. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred while fetching the schedule: $e');
    }
  }

  void _findCurrentTask(List<Task> tasks) {
    final now = TimeOfDay.now();
    final today = DateTime.now();
    Task? activeTask;

    for (final task in tasks) {
      final startTime = DateTime(today.year, today.month, today.day, task.startTime.hour, task.startTime.minute);
      final endTime = DateTime(today.year, today.month, today.day, task.endTime.hour, task.endTime.minute);
      final nowTime = DateTime(today.year, today.month, today.day, now.hour, now.minute);

      if (!nowTime.isBefore(startTime) && nowTime.isBefore(endTime)) {
        activeTask = task;
        break;
      }
    }

    if(mounted) {
      setState(() {
        _currentTask = activeTask;
      });
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _logout();
        return;
      }

      final cachedName = await _storage.read(key: 'student_name');
      if (cachedName != null && mounted) {
        setState(() {
          _userName = cachedName;
        });
      }

      final url = Uri.parse('http://10.252.6.161:3000/api/v1/student/profile');
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
        await _storage.write(key: 'student_name', value: name);
        setState(() {
          _userName = name;
        });
      } else if (response.statusCode == 401 && mounted) {
        _logout();
      } else {
        if (mounted && cachedName == null) {
          setState(() => _userName = 'Error');
        }
      }
    } catch (e) {
      final cachedName = await _storage.read(key: 'student_name');
      if (mounted) {
        setState(() {
          _userName = cachedName ?? 'Error';
        });
      }
    }
  }

  // --- LOGOUT LOGIC IS HERE ---
  Future<void> _logout() async {
    // This line deletes the token, user name, and any other data you have stored.
    await _storage.deleteAll();

    // This ensures the widget is still on screen before navigating.
    if (mounted) {
      // Navigate to the login screen and remove all previous screens.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginView()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      drawer: _buildAppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanningPage())),
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
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
                _buildCurrentTaskCard(),
                const SizedBox(height: 30),
                _buildSectionHeader("Actions"),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: 'Mark Attendance',
                  icon: Icons.qr_code_scanner,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanningPage()));
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  title: 'View Leaderboard',
                  icon: Icons.leaderboard,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage()));
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: kCardColor,
            child: Icon(Icons.person, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $_userName',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Here's your schedule for today.",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTaskCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SchedulePage())),
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
              _currentTask?.title ?? 'No current task',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _currentTask != null
                  ? '${_currentTask!.startTime.format(context)} - ${_currentTask!.endTime.format(context)}'
                  : 'Enjoy your free time!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
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
            icon: const Icon(Icons.leaderboard_outlined, color: Colors.grey, size: 30),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage()));
            },
          ),
          const SizedBox(width: 48), // The space for the notch
          IconButton(
            icon: const Icon(Icons.book_outlined, color: Colors.grey, size: 30),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCoursesPage()));
            },
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
              'Navigation',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book, color: Colors.white70),
            title: const Text('My Courses', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCoursesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.white70),
            title: const Text('My Schedule', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SchedulePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.leaderboard, color: Colors.white70),
            title: const Text('Leaderboard', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage()));
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              // This is where the logout is triggered
              _logout();
            },
          ),
        ],
      ),
    );
  }
}