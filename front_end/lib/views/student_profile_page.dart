import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Profile Page Content',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}