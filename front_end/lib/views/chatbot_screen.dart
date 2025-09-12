import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

// --- Theme Colors ---
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kBackgroundColor = Colors.black;
const Color kUserBubbleColor = kPrimaryColor;
const Color kBotBubbleColor = Color(0xFF2E2E2E);
const Color kTextFieldColor = Color(0xFF1E1E1E);

// --- Data Model ---
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

// --- Main Chat Screen Widget ---
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load the personalized initial message when the screen is first built
    _loadInitialMessage();
  }

  // --- NEW: Function to load student name and set initial message ---
  Future<void> _loadInitialMessage() async {
    final studentName = await _storage.read(key: 'student_name') ?? 'there';
    final welcomeText =
        "Hi $studentName, I'm Squirrels, your new AI assistant for all your needs and don't worry I actually work.";

    setState(() {
      _messages.add(ChatMessage(text: welcomeText, isUser: false));
    });
  }

  // Function to handle sending a message
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user's message to the list
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) throw Exception('Authentication token not found.');

      final url = Uri.parse('http://192.168.0.105:3000/api/v1/student/chatbot');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'query': text}),
      );

      String botResponseText;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        botResponseText = data['response'] ?? 'Sorry, I could not understand that.';
      } else {
        final errorData = json.decode(response.body);
        botResponseText = "Error: ${errorData['message'] ?? 'Something went wrong.'}";
      }

      // Add bot's response to the list
      setState(() {
        _messages.add(ChatMessage(text: botResponseText, isUser: false));
      });

    } catch (e) {
      // Handle network errors or other exceptions
      setState(() {
        _messages.add(ChatMessage(text: "Could not connect to the server. Please check your connection.", isUser: false));
      });
      print('Chatbot error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  // Function to scroll to the end of the message list
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'How can I help you?',
          style: TextStyle(color: Colors.white), // Set title color to white
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), // Set icon color to white
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                color: kPrimaryColor,
                backgroundColor: kBackgroundColor,
              ),
            ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  // Widget to build a single message bubble
  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: message.isUser ? kUserBubbleColor : kBotBubbleColor,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  // Widget for the text input field at the bottom
  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: kBackgroundColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: kTextFieldColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: const Icon(Icons.send, color: kPrimaryColor),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

