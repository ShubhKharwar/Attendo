import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'beacon_control.dart';
import 'loginview.dart';

// --- Color Constants for Consistent Theming ---
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kBackgroundColor = Colors.black;
const Color kCardColor = Color(0xFF1E1E1E);

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({Key? key}) : super(key: key);

  @override
  _TeacherAttendancePageState createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  // --- All original logic is preserved ---
  final BeaconControl _beaconControl = BeaconControl();
  final Uuid _uuid = const Uuid();
  final _storage = const FlutterSecureStorage();

  PermissionStatus? _bluetoothAdvertisePermission;
  String? _selectedSubject;
  final List<String> _subjects = [
    'CS101', 'MATH201', 'PHY301', 'ENG101',
    'CHEM201', 'BIO101', 'HIST101', 'ECON201'
  ];

  final String beaconUuid = '74278bda-b644-4520-8f0c-720eaf059935';
  final int major = 1;
  final int minor = 101;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // --- All original methods remain unchanged ---
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();
    if (mounted) {
      setState(() {
        _bluetoothAdvertisePermission = statuses[Permission.bluetoothAdvertise];
      });
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

    final String sessionId = _uuid.v4();
    final Map<String, String> qrData = {
      'sessionId': sessionId,
      'subject': _selectedSubject!,
    };
    final String qrJsonString = jsonEncode(qrData);

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
    if (_bluetoothAdvertisePermission == null) {
      return const Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_bluetoothAdvertisePermission != PermissionStatus.granted) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(
          child: _buildPermissionUI(
            'Bluetooth Permission Needed',
            'This app needs permission to broadcast a beacon signal for attendance.',
                () async {
              if (await Permission.bluetoothAdvertise.isPermanentlyDenied) {
                await openAppSettings();
              } else {
                _requestPermissions();
              }
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildTopBar(context),
                const SizedBox(height: 30),
                const Text('Start Attendance Session',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                const Text('1. Select Subject',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildSubjectDropdown(),
                const SizedBox(height: 40),
                Center(
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 150,
                    color: _selectedSubject != null ? kPrimaryColor : Colors.grey[800],
                  ),
                ),
                if (_selectedSubject != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                          'Ready to start session for $_selectedSubject',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16)),
                    ),
                  ),
                const SizedBox(height: 40),
                _buildGenerateButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Text("Take Attendance", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 40), // Placeholder to balance the back button
      ],
    );
  }

  Widget _buildSubjectDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButton<String>(
        value: _selectedSubject,
        hint: const Text('Choose a subject', style: TextStyle(color: Colors.grey)),
        dropdownColor: kCardColor,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        underline: Container(), // Hides the default underline
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
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
    );
  }

  Widget _buildGenerateButton() {
    bool isEnabled = _selectedSubject != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? kPrimaryColor : Colors.grey[800],
          foregroundColor: isEnabled ? Colors.black : Colors.grey[600],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: isEnabled ? _onGenerateQR : null,
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Generate QR & Start Session',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }

  Widget _buildPermissionUI(String title, String description, VoidCallback onRequest) {
    // This UI remains visually consistent with the theme
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRequest,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
}

// --- Second Page: Stop Attendance ---

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTopBar(context),
              const Spacer(),
              _buildSessionInfoCard(),
              const SizedBox(height: 30),
              _buildQrCode(),
              const SizedBox(height: 24),
              const Text('Students can scan to mark attendance',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              _buildStopButton(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // When the user presses back, the session should stop.
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
          onPressed: () => _onStopAttendance(context),
        ),
        Expanded(
          child: Text("Active: $subject",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 40), // Balance the back button
      ],
    );
  }

  Widget _buildSessionInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text('Session Active',
              style: TextStyle(color: Colors.grey[300], fontSize: 16)),
          const SizedBox(height: 8),
          Text(subject,
              style: const TextStyle(
                  color: kPrimaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('ID: ${sessionId.substring(0, 8)}...',
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQrCode() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: 220.0,
        backgroundColor: Colors.white,
        gapless: false,
      ),
    );
  }

  Widget _buildStopButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _onStopAttendance(context),
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('Stop Attendance Session',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}