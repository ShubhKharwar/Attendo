import 'package:flutter/material.dart';

// --- New Theme Colors ---
const Color kAppbarColor = Colors.black;
const Color kBackgroundColor = Colors.black;
const Color kMainTopicColor = Color(0xFF4CAF50);
const Color kSubTopicColor = Colors.yellow;
const Color kLineColor = Colors.purpleAccent;
const Color kAppBarTextColor = Colors.white;
const Color kBlockTextColor = Colors.black87;

// The main screen widget that displays the roadmap
class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor, // Changed to new background color
      appBar: AppBar(
        title: const Text(
          'Operating Systems Roadmap', // Changed title text
          style: TextStyle(fontWeight: FontWeight.bold, color: kAppBarTextColor), // Changed title color
        ),
        backgroundColor: kAppbarColor, // Changed to new app bar color
        elevation: 4,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kAppBarTextColor), // Changed icon color
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // InteractiveViewer allows for panning and zooming
      body: InteractiveViewer(
        constrained: false, // Allows the content to be larger than the viewport
        boundaryMargin: const EdgeInsets.all(80.0), // Ample boundary for smoother panning
        minScale: 0.1,
        maxScale: 4.0,
        child: SizedBox(
          width: 1400, // Width to ensure all content is visible
          height: 1600, // Height for vertical scrolling content
          child: CustomPaint(
            painter: RoadmapPainter(),
            child: const RoadmapContent(),
          ),
        ),
      ),
    );
  }
}

// Widget that holds the content of the roadmap
class RoadmapContent extends StatelessWidget {
  const RoadmapContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Using a Stack to position the roadmap items freely
    return Stack(
      clipBehavior: Clip.none, // Prevents clipping of children at the stack's boundary
      children: [
        // Each Positioned widget places a block at a specific location
        // --- Introduction Section ---
        const Positioned(
          top: 50,
          left: 50,
          child: RoadmapBlock(
              text: '1. Introduction', width: 200, isMainTopic: true),
        ),
        const Positioned(
          top: 30,
          left: 350,
          child: RoadmapBlock(text: 'Operating system and function'),
        ),
        const Positioned(
          top: 100,
          left: 350,
          child: RoadmapBlock(text: 'Evolution of operating system'),
        ),
        const Positioned(
          top: 170,
          left: 350,
          child: RoadmapBlock(text: 'System protection'),
        ),

        // --- Concurrent Processes Section ---
        const Positioned(
          top: 300,
          left: 50,
          child: RoadmapBlock(
              text: '2. Concurrent Processes', width: 250, isMainTopic: true),
        ),
        const Positioned(
          top: 280,
          left: 400,
          child: RoadmapBlock(text: 'Process concept'),
        ),
        const Positioned(
          top: 350,
          left: 400,
          child: RoadmapBlock(text: 'Principle of Concurrency'),
        ),
        const Positioned(
          top: 420,
          left: 400,
          child: RoadmapBlock(text: 'Producer Consumer Problem'),
        ),
        const Positioned(
            top: 280,
            left: 650,
            child: RoadmapBlock(text: 'Critical Section problem')),
        const Positioned(
            top: 350, left: 650, child: RoadmapBlock(text: 'Semaphores')),

        // --- CPU Scheduling Section ---
        const Positioned(
          top: 550,
          left: 50,
          child: RoadmapBlock(
              text: 'CPU Scheduling', width: 200, isMainTopic: true),
        ),
        const Positioned(
          top: 530,
          left: 350,
          child: RoadmapBlock(text: 'Scheduling Concept'),
        ),
        const Positioned(
          top: 600,
          left: 350,
          child: RoadmapBlock(text: 'Performance Criteria'),
        ),
        const Positioned(
          top: 670,
          left: 350,
          child: RoadmapBlock(text: 'Scheduling Algorithm'),
        ),

        // --- Deadlock Section ---
        const Positioned(
          top: 800,
          left: 50,
          child:
          RoadmapBlock(text: '3. Deadlock', width: 150, isMainTopic: true),
        ),
        const Positioned(
          top: 780,
          left: 300,
          child: RoadmapBlock(text: 'System Model'),
        ),
        const Positioned(
          top: 850,
          left: 300,
          child: RoadmapBlock(text: 'Deadlock Characterization'),
        ),
        const Positioned(
          top: 920,
          left: 300,
          child: RoadmapBlock(text: 'Prevention, Avoidance, Detection'),
        ),

        // --- Memory Management Section ---
        const Positioned(
          top: 1050,
          left: 50,
          child: RoadmapBlock(
              text: '4. Memory Management', width: 280, isMainTopic: true),
        ),
        const Positioned(
          top: 1030,
          left: 430,
          child: RoadmapBlock(text: 'Base machine, Resident monitor'),
        ),
        const Positioned(
          top: 1100,
          left: 430,
          child: RoadmapBlock(text: 'Paging, Segmentation'),
        ),
        const Positioned(
          top: 1170,
          left: 430,
          child: RoadmapBlock(text: 'Virtual memory concept'),
        ),

        // --- I/O Management & Disk Scheduling ---
        const Positioned(
          top: 1300,
          left: 50,
          child: RoadmapBlock(
              text: '5. I/O & Disk Scheduling', width: 280, isMainTopic: true),
        ),
        const Positioned(
          top: 1280,
          left: 430,
          child: RoadmapBlock(text: 'I/O devices and organization'),
        ),
        const Positioned(
          top: 1350,
          left: 430,
          child: RoadmapBlock(text: 'DISK I/O, Buffering'),
        ),

        // --- File System ---
        const Positioned(
          top: 1450,
          left: 50,
          child: RoadmapBlock(
              text: 'File System', width: 180, isMainTopic: true),
        ),
        const Positioned(
          top: 1430,
          left: 330,
          child: RoadmapBlock(text: 'File Concept, File Organization'),
        ),
        const Positioned(
          top: 1500,
          left: 330,
          child: RoadmapBlock(text: 'File Sharing, Implementation Issues'),
        ),

        // --- Case Studies Section ---
        const Positioned(
          top: 1050,
          left: 800,
          child: RoadmapBlock(
              text: '6. Case Studies', width: 200, isMainTopic: true),
        ),
        const Positioned(
          top: 1030,
          left: 1050,
          child: RoadmapBlock(text: 'Windows'),
        ),
        const Positioned(
          top: 1100,
          left: 1050,
          child: RoadmapBlock(text: 'Linux and Unix'),
        ),
      ],
    );
  }
}

// A reusable widget for the blocks in the roadmap
class RoadmapBlock extends StatelessWidget {
  final String text;
  final double width;
  final bool isMainTopic;

  const RoadmapBlock({
    super.key,
    required this.text,
    this.width = 250,
    this.isMainTopic = false,
  });

  @override
  Widget build(BuildContext context) {
    // Using InkWell to make the block tappable in the future
    return InkWell(
      // onTap: () {
      //   // TODO: Implement hyperlink navigation
      //   print('$text tapped!');
      // },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isMainTopic ? kMainTopicColor : kSubTopicColor, // Themed colors
          border: Border.all(color: kLineColor, width: 1.5), // Themed border
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: kLineColor.withOpacity(0.5), // Orange glow for dark theme
              spreadRadius: 2,
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isMainTopic ? FontWeight.bold : FontWeight.normal,
            color: kBlockTextColor, // Themed text color
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// Custom painter to draw the connecting lines for the roadmap
class RoadmapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kLineColor // Themed line color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dottedPaint = Paint()
      ..color = kLineColor.withOpacity(0.7) // Themed dotted line color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Helper function to draw a path with dashes
    void drawDashedLine(Path path, Paint paint) {
      const dashWidth = 5.0;
      const dashSpace = 3.0;
      final pathMetrics = path.computeMetrics();
      for (final metric in pathMetrics) {
        double distance = 0.0;
        while (distance < metric.length) {
          canvas.drawPath(
            metric.extractPath(distance, distance + dashWidth),
            paint,
          );
          distance += dashWidth + dashSpace;
        }
      }
    }

    // --- Lines for Introduction ---
    Path path1 = Path();
    path1.moveTo(255, 75);
    path1.cubicTo(300, 75, 320, 55, 345, 55);
    drawDashedLine(path1, dottedPaint);

    Path path2 = Path();
    path2.moveTo(255, 75);
    path2.cubicTo(300, 75, 320, 125, 345, 125);
    drawDashedLine(path2, dottedPaint);

    Path path3 = Path();
    path3.moveTo(255, 75);
    path3.cubicTo(300, 75, 320, 195, 345, 195);
    drawDashedLine(path3, dottedPaint);

    // --- Line connecting Introduction to Concurrent Processes ---
    canvas.drawLine(const Offset(150, 105), const Offset(150, 295), paint);

    // --- Lines for Concurrent Processes ---
    Path path4 = Path();
    path4.moveTo(305, 325);
    path4.cubicTo(350, 325, 370, 305, 395, 305);
    drawDashedLine(path4, dottedPaint);

    Path path5 = Path();
    path5.moveTo(305, 325);
    path5.cubicTo(350, 325, 370, 375, 395, 375);
    drawDashedLine(path5, dottedPaint);

    Path path6 = Path();
    path6.moveTo(305, 325);
    path6.cubicTo(350, 325, 370, 445, 395, 445);
    drawDashedLine(path6, dottedPaint);

    canvas.drawLine(const Offset(525, 305), const Offset(645, 305), paint);
    canvas.drawLine(const Offset(525, 375), const Offset(645, 375), paint);

    // --- Line connecting Concurrent Processes to CPU Scheduling ---
    canvas.drawLine(const Offset(150, 355), const Offset(150, 545), paint);

    // --- Lines for CPU Scheduling ---
    Path path7 = Path();
    path7.moveTo(255, 575);
    path7.cubicTo(300, 575, 320, 555, 345, 555);
    drawDashedLine(path7, dottedPaint);

    Path path8 = Path();
    path8.moveTo(255, 575);
    path8.cubicTo(300, 575, 320, 625, 345, 625);
    drawDashedLine(path8, dottedPaint);

    // ADDED: Line for "Scheduling Algorithm"
    Path path_cpu_3 = Path();
    path_cpu_3.moveTo(255, 575);
    path_cpu_3.cubicTo(300, 575, 320, 695, 345, 695);
    drawDashedLine(path_cpu_3, dottedPaint);

    // --- Line connecting CPU Scheduling to Deadlock ---
    canvas.drawLine(const Offset(150, 605), const Offset(150, 795), paint);

    // --- Lines for Deadlock ---
    Path path9 = Path();
    path9.moveTo(205, 825);
    path9.cubicTo(250, 825, 270, 805, 295, 805);
    drawDashedLine(path9, dottedPaint);

    Path path10 = Path();
    path10.moveTo(205, 825);
    path10.cubicTo(250, 825, 270, 875, 295, 875);
    drawDashedLine(path10, dottedPaint);

    // ADDED: Line for "Prevention, Avoidance, Detection"
    Path path_deadlock_3 = Path();
    path_deadlock_3.moveTo(205, 825);
    path_deadlock_3.cubicTo(250, 825, 270, 945, 295, 945);
    drawDashedLine(path_deadlock_3, dottedPaint);

    // --- Line connecting Deadlock to Memory Management ---
    canvas.drawLine(const Offset(150, 855), const Offset(150, 1045), paint);

    // --- Lines for Memory Management ---
    Path path11 = Path();
    path11.moveTo(335, 1075);
    path11.cubicTo(380, 1075, 400, 1055, 425, 1055);
    drawDashedLine(path11, dottedPaint);

    Path path12 = Path();
    path12.moveTo(335, 1075);
    path12.cubicTo(380, 1075, 400, 1125, 425, 1125);
    drawDashedLine(path12, dottedPaint);

    // ADDED: Line for "Virtual memory concept"
    Path path_mem_3 = Path();
    path_mem_3.moveTo(335, 1075);
    path_mem_3.cubicTo(380, 1075, 400, 1195, 425, 1195);
    drawDashedLine(path_mem_3, dottedPaint);

    // --- Line connecting Memory Management to I/O ---
    canvas.drawLine(const Offset(150, 1105), const Offset(150, 1295), paint);

    // --- Lines for I/O Management ---
    Path path13 = Path();
    path13.moveTo(335, 1325);
    path13.cubicTo(380, 1325, 400, 1305, 425, 1305);
    drawDashedLine(path13, dottedPaint);

    // ADDED: Line for "DISK I/O, Buffering"
    Path path_io_2 = Path();
    path_io_2.moveTo(335, 1325);
    path_io_2.cubicTo(380, 1325, 400, 1375, 425, 1375);
    drawDashedLine(path_io_2, dottedPaint);


    // --- Line connecting I/O to File System ---
    canvas.drawLine(const Offset(150, 1355), const Offset(150, 1445), paint);

    // --- Lines for File System ---
    Path path14 = Path();
    path14.moveTo(235, 1475);
    path14.cubicTo(280, 1475, 300, 1455, 325, 1455);
    drawDashedLine(path14, dottedPaint);

    // ADDED: Line for "File Sharing, Implementation Issues"
    Path path_fs_2 = Path();
    path_fs_2.moveTo(235, 1475);
    path_fs_2.cubicTo(280, 1475, 300, 1525, 325, 1525);
    drawDashedLine(path_fs_2, dottedPaint);

    // --- Line connecting Memory Management to Case Studies ---
    canvas.drawLine(
        const Offset(570, 1075), const Offset(795, 1075), paint);

    // --- Lines for Case Studies ---
    Path path15 = Path();
    path15.moveTo(1005, 1075);
    path15.cubicTo(1020, 1075, 1030, 1055, 1045, 1055);
    drawDashedLine(path15, dottedPaint);

    // ADDED: Line for "Linux and Unix"
    Path path_cs_2 = Path();
    path_cs_2.moveTo(1005, 1075);
    path_cs_2.cubicTo(1020, 1075, 1030, 1125, 1045, 1125);
    drawDashedLine(path_cs_2, dottedPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

