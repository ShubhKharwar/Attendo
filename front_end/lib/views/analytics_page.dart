import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

// --- Data Model for Attendance ---
class AttendanceData {
  final String subject;
  final int classesAttended;
  final int totalClasses;
  final double percentage;

  AttendanceData({
    required this.subject,
    required this.classesAttended,
    required this.totalClasses,
  }) : percentage = totalClasses > 0 ? (classesAttended / totalClasses) : 0.0;

  factory AttendanceData.fromJson(Map<String, dynamic> json) {
    return AttendanceData(
      subject: json['course_name'] ?? 'Unknown Subject',
      classesAttended: json['classes_attended'] ?? 0,
      totalClasses: json['total_classes'] ?? 0,
    );
  }
}

// --- Theme Colors from Home Screen for Consistency ---
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kBackgroundColor = Colors.black;
const Color kCardColor = Color(0xFF1E1E1E);

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _storage = const FlutterSecureStorage();
  List<AttendanceData> _attendanceList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  // --- BACKEND LOGIC: FETCH ATTENDANCE DATA ---
  Future<void> _fetchAttendanceData() async {
    // --- MOCK DATA FOR UI DEVELOPMENT ---
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    setState(() {
      _attendanceList = [
        AttendanceData(subject: 'Artificial Intelligence', classesAttended: 18, totalClasses: 20), // 90%
        AttendanceData(subject: 'Robotics', classesAttended: 15, totalClasses: 22), // 68%
        AttendanceData(subject: 'Advanced Mathematics', classesAttended: 25, totalClasses: 25), // 100%
        AttendanceData(subject: 'Software Engineering', classesAttended: 11, totalClasses: 24), // 45%
        AttendanceData(subject: 'History of Science', classesAttended: 8, totalClasses: 10), // 80%
      ];
      _isLoading = false;
    });
  }

  // --- NEW HELPER FUNCTION TO DETERMINE COLOR ---
  Color _getProgressColor(double percentage) {
    if (percentage >= 0.75) {
      return kPrimaryColor; // Green for good attendance
    } else if (percentage >= 0.50) {
      return Colors.amber; // Amber/Yellow for average attendance
    } else {
      return Colors.redAccent; // Red for low attendance
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Attendance',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _attendanceList.length,
        itemBuilder: (context, index) {
          return _buildAttendanceCard(_attendanceList[index]);
        },
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceData data) {
    // Get the dynamic color based on the percentage
    final Color progressColor = _getProgressColor(data.percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.subject,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Present: ${data.classesAttended} / ${data.totalClasses}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '${(data.percentage * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  // Use the dynamic color here as well
                  color: progressColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: data.percentage,
            backgroundColor: Colors.grey[800],
            // Use the dynamic color for the progress bar
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

