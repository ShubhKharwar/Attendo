import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.grey[900],
      ),
      body: const Center(
        child: Text(
          'Leaderboard',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
