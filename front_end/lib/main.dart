import 'package:attendo/views/teacher_attendance_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'views/onboardingscreen.dart';
import 'views/home.dart';
import 'views/interests_screen.dart';
import 'views/teacher_attendance_page.dart';

// Global variable to store the onboarding status
bool showOnboarding = true;

Future<void> main() async {
  // Ensure that widget binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  // If 'onboarding_complete' is null (first launch), it will default to true.
  // If it's false, it means onboarding was done, so we show the home screen flow.
  // We'll set the initial screen in the app itself.
  //showOnboarding = prefs.getBool('onboarding_complete') ?? true;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Onboarding Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.black, // Consistent background
      ),
      // If onboarding is not complete, show the OnboardingScreen, otherwise show the HomeScreen
      home: TeacherAttendancePage(),
      //showOnboarding ? const OnboardingScreen() : const HomeScreen()
    );
  }
}

