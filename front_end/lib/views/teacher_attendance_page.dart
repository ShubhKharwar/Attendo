import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'beacon_control.dart';


class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({Key? key}) : super(key: key);

  @override
  _TeacherAttendancePageState createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final BeaconControl _beaconControl = BeaconControl();
  final Uuid _uuid = const Uuid();

  // Example iBeacon UUID and IDs; replace if needed
  final String beaconUuid = '74278bda-b644-4520-8f0c-720eaf059935';
  final int major = 1;
  final int minor = 101;

  /// Generates a unique session ID, starts the beacon, and navigates to the
  /// page that displays the QR code.
  Future<void> _onGenerateQR() async {
    // Generate a unique identifier for the attendance session.
    // This data will be embedded in the QR code.
    final String sessionQrData = _uuid.v4();

    // Start broadcasting the beacon signal for this session.
    await _beaconControl.startBeacon(beaconUuid, major, minor);

    // Ensure the widget is still mounted before navigating.
    if (!mounted) return;

    // Navigate to the next screen to display the QR code and the stop button.
    // The session data is passed to the next page.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StopAttendancePage(qrData: sessionQrData),
      ),
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
            // A placeholder icon to represent QR code generation
            const Expanded(
              child: Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 180,
                  color: Color(0xFF4CAF50),
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

/// This page displays the generated QR code for the attendance session
/// and provides a button to stop the session.
class StopAttendancePage extends StatelessWidget {
  final String qrData;

  const StopAttendancePage({Key? key, required this.qrData}) : super(key: key);

  /// Stops the beacon broadcast and pops the current page to end the session.
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Display the live QR code
            Center(
              // The QrImageView widget from the qr_flutter package renders the QR code.
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 220.0,
                // Add a white background to the QR code for better scannability.
                backgroundColor: Colors.white,
                gapless: false,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan to mark attendance',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),
            // Stop Attendance Button
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
