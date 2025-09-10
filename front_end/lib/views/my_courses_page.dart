import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

// --- MODIFIED: The fromJson factory is no longer needed ---
class Course {
  final String subjectCode;

  Course({
    required this.subjectCode,
  });
}


class MyCoursesPage extends StatefulWidget {
  const MyCoursesPage({super.key});

  @override
  State<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends State<MyCoursesPage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  String? _errorMessage;
  List<Course> _courses = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCourses();
    });
  }

  // --- MODIFIED: This function now calls the /courses endpoint ---
  Future<void> _fetchCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) throw Exception('Not logged in');

      // 1. URL is now pointing to the /courses endpoint
      final url = Uri.parse('http://192.168.0.104:3000/api/v1/student/courses');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        // 2. The response is a direct list of strings, so we decode it as such
        final List<dynamic> courseCodes = json.decode(response.body);

        // 3. We map the list of strings directly to Course objects
        setState(() {
          _courses = courseCodes
              .map((code) => Course(subjectCode: code as String))
              .toList();
          _isLoading = false;
        });
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load courses.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        // --- MODIFIED: Back button color is explicitly set ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), // Ensures icon is white
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),

        // --- MODIFIED: Title text and style are updated ---
        title: const Text(
          'My Courses', // Changed text
          style: TextStyle(
            color: Colors.white, // Set text color to white
            fontWeight: FontWeight.bold, // Make text bold for visibility
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)));
    }
    if (_courses.isEmpty) {
      return const Center(child: Text('No courses found.', style: TextStyle(color: Colors.white)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        return _buildCourseCard(course);
      },
    );
  }

  Widget _buildCourseCard(Course course) {
    // This UI part does not need any changes
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/course_image.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.school, color: Colors.grey, size: 50);
                      },
                    ),
                    Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter
                          )
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          course.subjectCode,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.subjectCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () { /* TODO: Handle Roadmap */ },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)
                            )
                        ),
                        child: const Text('Roadmap'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () { /* TODO: Handle Syllabus */ },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)
                            )
                        ),
                        child: const Text('Syllabus'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}