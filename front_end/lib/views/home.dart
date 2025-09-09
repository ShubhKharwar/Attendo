import 'package:flutter/material.dart';
import 'student_scan.dart';
import 'leaderboard_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'loginview.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'Loading...';
  String _nextTask = 'Loading...';
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final token = await _storage.read(key: 'auth_token');

      if (token == null) {
        print('No token found, navigating to login.');
        _logout();
        return;
      }

      final url = Uri.parse('http://192.168.0.110:3000/api/v1/student/profile');

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
          _userName = data['name'] ?? 'User';
        });
      } else if (response.statusCode == 401 && mounted) {
        print('Token is invalid or expired. Logging out.');
        _logout();
      } else {
        print('Failed to load user data. Status code: ${response.statusCode}');
        if (mounted) setState(() => _userName = 'Error');
      }
    } catch (e) {
      print('An error occurred while fetching user data: $e');
      if (mounted) setState(() => _userName = 'Error');
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
      bottomNavigationBar: _buildBottomNavBar(), // Updated to new nav bar
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 30),
              _buildGreetingAndAttendance(),
              const SizedBox(height: 40),
              _buildNextTaskCard(),
              const SizedBox(height: 40),
              _buildMarkAttendanceButton(),
              const SizedBox(height: 20),
              _buildLeaderboardButton(),
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

  // --- WIDGETS BELOW ARE LARGELY UNCHANGED, EXCEPT FOR NAVIGATION ---

  Widget _buildGreetingAndAttendance() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Hi $_userName!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: const Center(
            child: Text(
              '75%\nATTENDANCE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextTaskCard() {
    return GestureDetector(
      onTap: () {
        print('Next task card tapped');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nextTask,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'is your next task',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
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
        // --- NAVIGATION CHANGE HERE ---
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StudentScanPage()),
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'see this months attendance',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 40),
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  // --- NEW BOTTOM NAVIGATION BAR ---
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
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.grey, size: 30),
            onPressed: () {},
          ),
          // Central, larger button
          GestureDetector(
            onTap: () {
              // --- NAVIGATION CHANGE HERE ---
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentScanPage()),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4CAF50),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 35),
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
