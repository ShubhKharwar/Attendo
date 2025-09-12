import 'package:flutter/material.dart';
import 'home.dart'; // Assuming home.dart is now home_screen.dart from previous context
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'interests_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'teacher_attendance_page.dart'; // Import the new page
import 'teacher_home.dart'; // Import the new TeacherHomeScreen

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

  @override
  void dispose() {
    _emailController.dispose();
    _rollNoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final rollNo = _rollNoController.text.trim();
      final password = _passwordController.text;

      // Note: Your backend should handle both student and admin logins at this endpoint
      final url = Uri.parse('http://192.168.0.105:3000/api/v1/student/signin');

      final body = json.encode({
        'email': email,
        'rollNo': rollNo, // The backend should interpret this as an ID for teachers
        'password': password,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200 && mounted) {
        print('Login Successful!');
        final responseData = json.decode(response.body);

        // --- 1. SAVE THE TOKEN ---
        final token = responseData['token'];
        if (token != null) {
          await _storage.write(key: 'auth_token', value: token);
          print('Token saved successfully!');
        } else {
          throw Exception('Token not found in response');
        }

        // --- 2. CHECK USER TYPE AND NAVIGATE ---
        final userType = responseData['userType']; // Expecting 'student' or 'admin'
        await _storage.write(key: 'user_role', value: userType);

        if (userType == 'student') {
          // Logic for students
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('rollNo', rollNo);

          final bool interestsHaveBeenSelected = responseData['interestsSelected'] ?? false;
          await prefs.setBool('interests_selected', interestsHaveBeenSelected);

          if (interestsHaveBeenSelected) {
            _navigateToHome();
          } else {
            _navigateToInterests();
          }
        } else if (userType == 'admin') {
          // Logic for admins/teachers
          _navigateToTeacherHome(); // Changed from _navigateToTeacherAttendance()
        } else {
          // Handle cases where userType is missing or invalid
          throw Exception('Invalid user type received from server');
        }

      } else {
        final errorMsg = json.decode(response.body)['message'] ?? 'Please check your credentials.';
        print('Login failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Failed: $errorMsg')),
          );
        }
      }
    } catch (e) {
      print('An error occurred during login: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again later.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToInterests() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const InterestsScreen()),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _navigateToTeacherAttendance() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TeacherAttendancePage()),
    );
  }

  // --- NEW NAVIGATION FUNCTION FOR ADMINS ---
  void _navigateToTeacherHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // <-- THE FIX IS HERE
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column( // This is the main Column
          children: [
            _buildProgressBar(Alignment.center),
            Expanded( // This widget takes up all available space
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Let's Sign In.!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Login to Your Account to Continue",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _rollNoController,
                      hintText: 'Roll No./ID(for teachers)',
                      icon: Icons.school_outlined,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          print('Forgot Password button tapped!');
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Sign In',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- The image is now outside the Expanded and SingleChildScrollView ---
            Padding(
              // Added padding for better spacing from the screen edge
              padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
              child: Center(
                child: Image.asset(
                  'assets/images/login_image.png', // Make sure this path is correct
                  height: 220, // <-- Increased the height
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(AlignmentGeometry alignment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: alignment,
        child: Container(
          width: 100,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50)),
        ),
      ),
    );
  }
}