import 'package:flutter/material.dart';
import 'home.dart'; // The final destination after login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers to get the text from the input fields
  final _emailController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    _emailController.dispose();
    _rollNoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Backend Integration Point ---
  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final rollNo = _rollNoController.text.trim();
    final password = _passwordController.text;

    // --- TODO: Add your backend logic here ---
    // 1. Validate the inputs (e.g., check if they are not empty).
    // 2. Send the data to your backend API for authentication.
    //    Example using http package:
    //    try {
    //      final response = await http.post(
    //        Uri.parse('https://your-api.com/login'),
    //        body: {
    //          'email': email,
    //          'roll_no': rollNo,
    //          'password': password,
    //        },
    //      );
    //      if (response.statusCode == 200) {
    //        // Login successful, navigate to home
    //        _navigateToHome();
    //      } else {
    //        // Handle login failure (e.g., show a snackbar with an error)
    //        ScaffoldMessenger.of(context).showSnackBar(
    //          SnackBar(content: Text('Login Failed: ${response.body}')),
    //        );
    //      }
    //    } catch (e) {
    //      // Handle network or other errors
    //       ScaffoldMessenger.of(context).showSnackBar(
    //        SnackBar(content: Text('An error occurred: $e')),
    //      );
    //    }
    //
    // For now, we'll just print the data and navigate.
    print('Signing in with:');
    print('Email: $email');
    print('Roll No: $rollNo');
    print('Password: $password');

    // On successful login from backend, navigate to the home screen
    _navigateToHome();
  }

  void _navigateToHome() {
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
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
                "Login to Your Account to Continue your Courses",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),

              // Email Text Field
              _buildTextField(
                controller: _emailController,
                hintText: 'Email',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 20),

              // Roll No. Text Field
              _buildTextField(
                controller: _rollNoController,
                hintText: 'Roll No. (e.g., year/branch_code/no.)',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 20),

              // Password Text Field
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

              //forgot password button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password logic
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

              // Sign In Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50), // Green color
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
