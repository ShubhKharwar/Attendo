import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'views/onboardingscreen.dart';
import 'views/home.dart';

// Global variable to store the onboarding status
bool showOnboarding = true;

Future<void> main() async {
  // Ensure that widget binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  showOnboarding = true;
  //prefs.getBool('onboarding_complete') ?? true

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
      ),
      // If onboarding is not complete, show the OnboardingScreen, otherwise show the HomeScreen
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
