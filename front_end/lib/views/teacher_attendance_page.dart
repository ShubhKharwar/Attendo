import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'beacon_control.dart';
import 'loginview.dart';

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({Key? key}) : super(key: key);

  @override
  _TeacherAttendancePageState createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final BeaconControl _beaconControl = BeaconControl();
  final Uuid _uuid = const Uuid();
  final _storage = const FlutterSecureStorage();
  
  // Subject selection
  String? _selectedSubject;
  final List<String> _subjects = [
    'CS101', 'MATH201', 'PHY301', 'ENG101', 
    'CHEM201', 'BIO101', 'HIST101', 'ECON201'
  ];
  
  // Beacon configuration
  final String beaconUuid = '74278bda-b644-4520-8f0c-720eaf059935';
  final int major = 1;
  final int minor = 101;

  Future<void> _logout() async {
    await _storage.delete(key: 'auth_token');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginView()),
        (Route route) => false,
      );
    }
  }

  Future<void> _onGenerateQR() async {
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a subject first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generate session ID and create QR data with proper structure
    final String sessionId = _uuid.v4();
    final Map<String, String> qrData = {
      'sessionId': sessionId,
      'subject': _selectedSubject!,
    };
    
    final String qrJsonString = jsonEncode(qrData);
    
    // Start beacon
    await _beaconControl.startBeacon(beaconUuid, major, minor);
    
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StopAttendancePage(
          qrData: qrJsonString,
          subject: _selectedSubject!,
          sessionId: sessionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Teacher Dashboard", 
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Subject Selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Subject:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedSubject,
                      hint: const Text(
                        'Choose a subject',
                        style: TextStyle(color: Colors.grey),
                      ),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      underline: Container(),
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSubject = newValue;
                        });
                      },
                      items: _subjects.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // QR Code Icon
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 180,
                      color: _selectedSubject != null 
                          ? const Color(0xFF4CAF50) 
                          : Colors.grey,
                    ),
                    const SizedBox(height: 20),
                    if (_selectedSubject != null)
                      Text(
                        'Ready to generate QR for $_selectedSubject',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Generate QR Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedSubject != null 
                        ? const Color(0xFF4CAF50) 
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _selectedSubject != null ? _onGenerateQR : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Generate QR & Start Session',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StopAttendancePage extends StatelessWidget {
  final String qrData;
  final String subject;
  final String sessionId;
  
  const StopAttendancePage({
    Key? key,
    required this.qrData,
    required this.subject,
    required this.sessionId,
  }) : super(key: key);

  Future<void> _onStopAttendance(BuildContext context) async {
    final beaconControl = BeaconControl();
    await beaconControl.stopBeacon();
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _logout(BuildContext context) async {
    final storage = const FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginView()),
        (Route route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("$subject Session", 
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            
            // Session info
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Active Session',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subject,
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session ID: ${sessionId.substring(0, 8)}...',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // QR Code
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                  gapless: false,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Students can scan to mark attendance',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            
            const Spacer(),
            
            // Stop button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => _onStopAttendance(context),
                  child: const Text(
                    'Stop Attendance Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
