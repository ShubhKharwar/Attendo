import 'package:flutter/material.dart';
import 'beacon_control.dart';

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({Key? key}) : super(key: key);

  @override
  _TeacherAttendancePageState createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final BeaconControl _beaconControl = BeaconControl();

  // Example iBeacon UUID and IDs; replace if needed
  final String beaconUuid = '74278bda-b644-4520-8f0c-720eaf059935';
  final int major = 1;
  final int minor = 101;

  Future<void> generate_qr() async {
    // TODO: Add your QR code generation logic here.
  }

  Future<void> _onGenerateQR() async {
    await generate_qr();
    await _beaconControl.startBeacon(beaconUuid, major, minor);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StopAttendancePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // QR code icon placeholder
            Expanded(
              child: Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 180,
                  color: const Color(0xFF4CAF50),
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
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _onGenerateQR,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Generate QR',
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
  const StopAttendancePage({Key? key}) : super(key: key);

  Future<void> _onStopAttendance(BuildContext context) async {
    final beaconControl = BeaconControl();
    await beaconControl.stopBeacon();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Expanded(
              child: Center(
                child: Icon(Icons.qr_code_scanner, size: 150, color: const Color(0xFF4CAF50)),
              ),
            ),
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
                    'Stop Attendance',
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
