import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class StudentScanPage extends StatefulWidget {
  const StudentScanPage({super.key});

  @override
  State<StudentScanPage> createState() => _StudentScanPageState();
}

class _StudentScanPageState extends State<StudentScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;
  PermissionStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
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
    // Hide any currently displayed snackbar before showing a new one
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
    if (!_isScanning) return;
    setState(() => _isScanning = false);

    final String? qrCodeData = capture.barcodes.first.rawValue;
    if (qrCodeData == null) {
      _showSnackbar("Failed to read QR code.", isError: true);
      // --- FIX: Add cooldown for read failure ---
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _isScanning = true);
      return;
    }

    try {
      final data = jsonDecode(qrCodeData);
      final sessionId = data['sessionId'];
      final subjectCode = data['subjectCode'];

      if (sessionId == null || subjectCode == null) {
        throw const FormatException("Missing required data in QR code.");
      }

      print("✅ Successfully scanned QR Code:");
      print("   Session ID: $sessionId");
      print("   Subject Code: $subjectCode");

      _showSnackbar("Attendance Marked Successfully!");
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      print("❌ QR Code Error: $e");
      _showSnackbar("Invalid QR code format. Please try again.", isError: true);

      // --- FIX: THIS IS THE KEY CHANGE ---
      // Introduce a cooldown period before allowing another scan.
      // This gives the snackbar time to disappear.
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) {
        setState(() => _isScanning = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Camera Permission Handling UI ---
    if (_permissionStatus == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_permissionStatus != PermissionStatus.granted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Camera Permission Needed', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('This app needs camera access to scan QR codes.', style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (await Permission.camera.isPermanentlyDenied) {
                      openAppSettings();
                    } else {
                      _requestCameraPermission();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Grant Permission'),
                ),
              ],
            ),
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
                icon: Icon(state.torchState == TorchState.on ? Icons.flashlight_on : Icons.flashlight_off),
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
                border: Border.all(color: Colors.greenAccent.withOpacity(0.8), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
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
      // --- FIX: Removed the redundant .close() call ---
      Path()..addRRect(RRect.fromRectAndRadius(
          scanWindow, const Radius.circular(16))),
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

