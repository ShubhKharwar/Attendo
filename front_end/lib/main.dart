import 'package:attendo/views/loginview.dart';
import 'package:attendo/views/teacher_attendance_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'views/onboardingscreen.dart';
import 'views/home.dart';

Future<void> main() async {
  // This is the only thing needed in main now.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.black,
      ),
      // The AuthWrapper will decide which screen to show first.
      home: const AuthWrapper(),
    );
  }
}

// This new widget will handle all the startup logic.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Use FlutterSecureStorage to check for the auth token
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    // Check the status as soon as the widget is initialized
    _checkStatusAndNavigate();
  }

  Future<void> _checkStatusAndNavigate() async {
    // 1. Check if onboarding is complete
    final prefs = await SharedPreferences.getInstance();
    // We check for 'onboarding_complete' being true. If it's null or false, we show onboarding.
    final bool onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    // 2. Check if the user is logged in (e.g., by checking for a token)
    final String? authToken = await _storage.read(key: 'auth_token');

    // Ensure the widget is still mounted before navigating
    if (!mounted) return;

    // --- Navigation Logic ---
    if (!onboardingComplete) {
      // If onboarding has never been completed, go to OnboardingScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
      // If onboarding is complete, check if the user is logged in
      if (authToken != null) {
        // If a token exists, the user is logged in -> go to HomeScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // If no token, the user is not logged in -> go to LoginView
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginView()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while we're checking the status.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}