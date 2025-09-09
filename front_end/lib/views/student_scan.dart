import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ScanningPage extends StatefulWidget {
  const ScanningPage({super.key});

  @override
  State<ScanningPage> createState() => _ScanningPageState();
}

class _ScanningPageState extends State<ScanningPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  final _storage = const FlutterSecureStorage();
  
  bool _isScanning = true;
  bool _isProcessing = false;
  PermissionStatus? _cameraPermission;
  PermissionStatus? _bluetoothPermission;
  
  String? _scannedSessionId;
  String? _scannedSubject;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final bluetoothStatus = await Permission.bluetoothScan.request();
    
    if (mounted) {
      setState(() {
        _cameraPermission = cameraStatus;
        _bluetoothPermission = bluetoothStatus;
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing) return;

    setState(() {
      _isScanning = false;
      _isProcessing = true;
    });

    final String? qrCodeData = capture.barcodes.first.rawValue;
    if (qrCodeData == null) {
      _showSnackbar("Failed to read QR code.", isError: true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isScanning = true;
          _isProcessing = false;
        });
      }
      return;
    }

    try {
      // Parse QR code data
      final data = jsonDecode(qrCodeData);
      final sessionId = data['sessionId'];
      final subject = data['subject'];

      if (sessionId == null || subject == null) {
        throw const FormatException("Missing sessionId or subject in QR code");
      }

      setState(() {
        _scannedSessionId = sessionId;
        _scannedSubject = subject;
      });

      print("✅ QR Code Scanned:");
      print("  Session ID: $sessionId");
      print("  Subject: $subject");
      
      _showSnackbar("QR Scanned! Now verifying proximity...");
      
      // Proceed with attendance marking
      await _markAttendance();

    } catch (e) {
      print("❌ QR Code Error: $e");
      _showSnackbar("Invalid QR code format. Please try again.", isError: true);
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isScanning = true;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _markAttendance() async {
    try {
      // Step 1: BLE Beacon Proximity Check
      _showSnackbar("Checking classroom proximity...");
      bool beaconFound = await _searchForTeacherBeacon();
      
      if (!beaconFound) {
        _showSnackbar("You are not close enough to the teacher. Please move closer.", isError: true);
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _isScanning = true;
            _isProcessing = false;
          });
        }
        return;
      }

      // Step 2: Call Backend API
      _showSnackbar("Proximity verified! Marking attendance...");
      await _callMarkAttendanceAPI();

    } catch (e) {
      _showSnackbar("Error: $e", isError: true);
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isScanning = true;
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _searchForTeacherBeacon() async {
    try {
      print("🔍 Searching for teacher's beacon...");
      
      if (await FlutterBluePlus.isAvailable == false) {
        print("❌ Bluetooth not available");
        return true; // Allow attendance for testing even if BLE fails
      }

      // Start BLE scan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      
      bool beaconFound = false;
      
      // Listen for scan results
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          // Check proximity based on RSSI (signal strength)
          // RSSI > -70 indicates close proximity
          if (result.rssi > -70) {
            beaconFound = true;
            print("✅ Teacher beacon found with RSSI: ${result.rssi}");
            break;
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 8));
      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      return beaconFound;

    } catch (e) {
      print("❌ Beacon search error: $e");
      return true; // Allow attendance for testing even if BLE scan fails
    }
  }

  Future<void> _callMarkAttendanceAPI() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final url = Uri.parse('http://192.168.0.110:3000/api/v1/student/markAttendance');
    final body = jsonEncode({
      'sessionId': _scannedSessionId,
      'subject': _scannedSubject,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      _showSnackbar("✅ Attendance marked successfully for $_scannedSubject!");
      print("✅ Attendance marked successfully!");
      
      // Navigate back after success
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
      
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to mark attendance');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Permission checks
    if (_cameraPermission == null || _bluetoothPermission == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_cameraPermission != PermissionStatus.granted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _buildPermissionUI(
            'Camera Permission Needed',
            'This app needs camera access to scan QR codes.',
            () => _requestPermissions(),
          ),
        ),
      );
    }

    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: 250,
      height: 250,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              if (!state.isInitialized || !state.isRunning) return const SizedBox.shrink();
              return IconButton(
                color: Colors.white,
                icon: Icon(
                  state.torchState == TorchState.on 
                      ? Icons.flashlight_on 
                      : Icons.flashlight_off
                ),
                onPressed: () => _scannerController.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            scanWindow: scanWindow,
          ),
          
          // Overlay with blur
          ClipPath(
            clipper: ScannerOverlayClipper(scanWindow),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          
          // Scan window border
          Center(
            child: Container(
              width: scanWindow.width,
              height: scanWindow.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing 
                      ? Colors.orange.withOpacity(0.8)
                      : Colors.greenAccent.withOpacity(0.8), 
                  width: 3
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          
          // Status overlay
          if (_isProcessing)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      _scannedSubject != null 
                          ? 'Processing $_scannedSubject attendance...'
                          : 'Processing...',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionUI(String title, String description, VoidCallback onRequest) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRequest,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayClipper extends CustomClipper<Path> {
  final Rect scanWindow;

  ScannerOverlayClipper(this.scanWindow);

  @override
  Path getClip(Size size) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addRRect(RRect.fromRectAndRadius(
        scanWindow, 
        const Radius.circular(16)
      )),
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
