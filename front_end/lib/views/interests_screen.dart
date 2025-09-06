import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  bool _isLoading = false;
  final Set<String> _selectedInterests = <String>{};

  // Controller for the search bar
  final _searchController = TextEditingController();
  // The list of interests that will be displayed and filtered
  List<String> _filteredInterests = [];

  final List<String> _interests = [
    'Artificial Intelligence',
    'Mathematics',
    'Robotics',
    'Programming',
    'Science',
    'Literature',
    'History',
    'Space Science',
    'Creative Writing',
    'Research',
    'Design',
    'Arts',
    'Communication',
    'Leadership',
    'Problem Solving',
    'Critical Thinking',
    'Creativity',
  ];

  @override
  void initState() {
    super.initState();
    // Initially, show all interests
    _filteredInterests = _interests;
    // Set up a listener to call the filter function whenever the text changes
    _searchController.addListener(_filterInterests);
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed
    _searchController.removeListener(_filterInterests);
    _searchController.dispose();
    super.dispose();
  }

  // Logic to filter the list of interests based on search query
  void _filterInterests() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInterests = _interests.where((interest) {
        return interest.toLowerCase().contains(query);
      }).toList();
    });
  }


  Future<void> _submitInterests() async {
    if (_isLoading || _selectedInterests.length < 5) return;

    setState(() {
      _isLoading = true;
    });

    // --- UI Navigation Logic ---
    // This simulates a successful API call and navigates to the home screen
    // to allow you to test the UI flow.
    print('Simulating API call...');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    print('Simulated success. Navigating to home.');

    // Set the flag to prevent this screen from showing again
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('interests_selected', true);

    _navigateToHome();

    // --- REAL BACKEND LOGIC ---
    // When your backend is ready, you can REMOVE the code above
    // and UNCOMMENT the code below.
    /*
    try {
      // --- Step 1: Gather Data in the App ---
      final selectedInterestsList = _selectedInterests.toList();
      print('User selected interests: $selectedInterestsList');
      // TODO: Replace with the actual student ID retrieved after login
      const studentId = 'STU001';

      // --- Step 2: Define the Backend API Endpoint ---
      // This is the URL for your Node.js server that will handle this request.
      final url = Uri.parse('https://api.yourapp.com/process-student-interests');

      final body = json.encode({
        'student_id': studentId,
        'interests': selectedInterestsList,
      });

      // --- Step 3: Detailed Backend Implementation Plan is in the comments above this function ---

      // --- Step 4: Make the HTTP Request from Flutter to Node.js ---
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // --- Step 5: Handle the Final Response in the App ---
      if (response.statusCode == 200) {
        print('Interests submitted and processed successfully!');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('interests_selected', true);
        _navigateToHome();
      } else {
        print('Failed to submit interests. Status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save interests. Please try again.')),
        );
      }

    } catch (e) {
      print('An error occurred: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again later.')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    */
  }

  void _navigateToHome() {
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedInterests.length >= 5;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar aligned to the right, its final position
            _buildProgressBar(Alignment.centerRight),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What are you passionate about?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select at least 5 interests to personalize your journey.",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // --- SEARCH BAR ADDED HERE ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search for interests...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Wrap(
                  spacing: 12.0,
                  runSpacing: 12.0,
                  children: _filteredInterests.map((interest) {
                    final isSelected = _selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedInterests.add(interest);
                          } else {
                            _selectedInterests.remove(interest);
                          }
                        });
                      },
                      // A darker, solid green for the unselected state
                      backgroundColor: Colors.green[800],
                      // The main, bright green for the selected state
                      selectedColor: const Color(0xFF4CAF50),
                      labelStyle: const TextStyle(
                        // Text is always white and bold
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        // Remove the border for a solid block look
                        side: BorderSide.none,
                      ),
                      // Adding padding for better visual appearance
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    );
                  }).toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canContinue ? _submitInterests : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    disabledBackgroundColor: Colors.grey.withOpacity(0.2),
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
                      : Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: canContinue ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

