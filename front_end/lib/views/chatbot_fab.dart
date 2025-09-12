import 'package:flutter/material.dart';
import 'chatbot_screen.dart'; // Import your chatbot screen

class ChatbotFab extends StatelessWidget {
  const ChatbotFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none, // Allow bubble to render outside the stack's bounds
      children: [
        // 1. The speech bubble with text, positioned above the mascot
        Positioned(
          bottom: 75, // Adjust this value to position the bubble correctly
          right: 20, // Increased this value to move the bubble further left
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Hi, how can I help you 😊',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),

        // 2. A custom painter for the bubble's tail, positioned between the bubble and mascot
        Positioned(
          bottom: 65, // Should be below the bubble and point to the mascot
          child: CustomPaint(
            painter: TrianglePainter(),
          ),
        ),

        // 3. The circular mascot button, which is the main interactive element
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatbotScreen()),
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 30,
              // --- IMPORTANT ---
              // Replace this with the path to your own mascot image
              backgroundImage: AssetImage('assets/images/chatbot_mascot.png'),
              backgroundColor: Colors.grey, // Fallback color if the image fails
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter to draw the small triangle (tail) of the speech bubble
class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(-8, 0); // Start left
    path.lineTo(8, 0); // Go right
    path.lineTo(0, 8); // Go down to a point
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

