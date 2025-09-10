import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:collection/collection.dart'; // Import for list equality

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
  PermissionStatus? _locationPermission;
  bool _isLocationServiceEnabled = false;
  Timer? _locationCheckTimer;

  String? _scannedSessionId;
  String? _scannedSubject;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    final serviceStatus = await Permission.location.serviceStatus;
    final isGpsOn = serviceStatus == ServiceStatus.enabled;
    if (mounted) {
      setState(() {
        _isLocationServiceEnabled = isGpsOn;
      });
    }

    if (!isGpsOn) {
      print("Location service is disabled. Starting periodic checker.");
      _startLocationServiceChecker();
      return;
    }

    _locationCheckTimer?.cancel();

    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (mounted) {
      setState(() {
        _cameraPermission = statuses[Permission.camera];
        _bluetoothPermission = statuses[Permission.bluetoothScan];
        _locationPermission = statuses[Permission.locationWhenInUse];
      });
    }
  }

  void _startLocationServiceChecker() {
    _locationCheckTimer?.cancel();
    _locationCheckTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
          print("Checking location service status...");
          final serviceStatus = await Permission.location.serviceStatus;
          if (serviceStatus == ServiceStatus.enabled) {
            print("Location service has been enabled by the user.");
            timer.cancel();
            await _checkAndRequestPermissions();
          }
        });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scannerController.dispose();
    _locationCheckTimer?.cancel();
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
      _showSnackbar("Checking classroom proximity...");
      bool beaconFound = await _searchForTeacherBeacon();

      if (!beaconFound) {
        _showSnackbar(
            "You are not close enough to the teacher. Please move closer.",
            isError: true);
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _isScanning = true;
            _isProcessing = false;
          });
        }
        return;
      }

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
    final completer = Completer<bool>();
    StreamSubscription? subscription;
    const String targetUuid = '74278bda-b644-4520-8f0c-720eaf059935';

    try {
      if (await FlutterBluePlus.isAvailable == false) {
        print("❌ Bluetooth not available");
        return false;
      }

      print("🔍 Starting specific beacon scan for UUID: $targetUuid");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

      subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          print(
              '   [DEBUG] Found device: ${result.device.remoteId} with RSSI: ${result.rssi}');
          bool isTeacherBeacon = _isMatchingBeacon(result, targetUuid);
          if (isTeacherBeacon) {
            print(
                '✅ Found our beacon pattern from device: ${result.device.remoteId}');
            if (result.rssi > -70) {
              print("   RSSI is strong enough: ${result.rssi}");
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            } else {
              print("   RSSI is too weak: ${result.rssi}");
            }
          }
        }
      });

      return await completer.future
          .timeout(const Duration(seconds: 8), onTimeout: () {
        print("⏰ Beacon scan timed out. No matching beacon found in proximity.");
        return false;
      });
    } catch (e) {
      print("❌ Beacon search error: $e");
      return false;
    } finally {
      print("🛑 Stopping beacon scan.");
      await FlutterBluePlus.stopScan();
      await subscription?.cancel();
    }
  }

  bool _isMatchingBeacon(ScanResult result, String targetUuid) {
    final manufacturerData = result.advertisementData.manufacturerData;
    if (manufacturerData.containsKey(76)) {
      final beaconData = manufacturerData[76]!;
      if (beaconData.length >= 23 &&
          beaconData[0] == 0x02 &&
          beaconData[1] == 0x15) {
        final receivedUuidBytes = beaconData.sublist(2, 18);
        final targetUuidBytes = _uuidToBytes(targetUuid);
        if (const ListEquality().equals(receivedUuidBytes, targetUuidBytes)) {
          return true;
        }
      }
    }
    return false;
  }

  List<int> _uuidToBytes(String uuid) {
    final strippedUuid = uuid.replaceAll('-', '');
    final bytes = <int>[];
    for (int i = 0; i < strippedUuid.length; i += 2) {
      final hexPair = strippedUuid.substring(i, i + 2);
      bytes.add(int.parse(hexPair, radix: 16));
    }
    return bytes;
  }

  Future<void> _callMarkAttendanceAPI() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final url =
    Uri.parse('http://192.168.0.110:3000/api/v1/student/markAttendance');
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
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to mark attendance');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while initial checks are running
    if (_cameraPermission == null ||
        _bluetoothPermission == null ||
        _locationPermission == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // NEW: UI to prompt user to enable location services
    if (!_isLocationServiceEnabled) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _buildPermissionUI(
            'Location Services Required',
            'Please enable location services to allow Bluetooth scanning for beacons.',
                () async {
              // This won't directly open the location settings,
              // but prompts the user to do so. The timer will detect the change.
              print("Prompting user to enable location.");
            },
            buttonText: 'Enable Location',
          ),
        ),
      );
    }

    // UI for missing permissions
    if (_cameraPermission != PermissionStatus.granted ||
        _bluetoothPermission != PermissionStatus.granted ||
        _locationPermission != PermissionStatus.granted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _buildPermissionUI(
            'Permissions Required',
            'Camera, Bluetooth, and Location permissions are needed for attendance scanning.',
            _openSettingsOrRequest,
          ),
        ),
      );
    }

    // Main scanner UI
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
              if (!state.isInitialized || !state.isRunning)
                return const SizedBox.shrink();
              return IconButton(
                color: Colors.white,
                icon: Icon(state.torchState == TorchState.on
                    ? Icons.flashlight_on
                    : Icons.flashlight_off),
                onPressed: () => _scannerController.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            scanWindow: scanWindow,
          ),
          ClipPath(
            clipper: ScannerOverlayClipper(scanWindow),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          Center(
            child: Container(
              width: scanWindow.width,
              height: scanWindow.height,
              decoration: BoxDecoration(
                border: Border.all(
                    color: _isProcessing
                        ? Colors.orange.withOpacity(0.8)
                        : Colors.greenAccent.withOpacity(0.8),
                    width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
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

  Future<void> _openSettingsOrRequest() async {
    if (await Permission.camera.isPermanentlyDenied ||
        await Permission.bluetoothScan.isPermanentlyDenied ||
        await Permission.locationWhenInUse.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      _checkAndRequestPermissions();
    }
  }

  Widget _buildPermissionUI(String title, String description, VoidCallback onRequest,
      {String buttonText = 'Grant Permissions'}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
            child: Text(buttonText),
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
      Path()
        ..addRRect(
            RRect.fromRectAndRadius(scanWindow, const Radius.circular(16))),
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

