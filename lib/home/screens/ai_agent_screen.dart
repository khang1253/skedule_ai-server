// lib/home/screens/ai_agent_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/main.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_messages.isEmpty) {
      _messages.insert(0, {"sender": "AI", "text": "Chào bạn, tôi có thể giúp gì cho lịch trình của bạn?"});
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();

      // QUAN TRỌNG: Đóng màn hình AI để AuthGate có thể điều hướng từ Home
      if (mounted) {
        Navigator.of(context).pop();
      }

    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã xảy ra lỗi khi đăng xuất'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.isEmpty) return;
    _textController.clear();
    setState(() {
      _messages.insert(0, {"sender": "You", "text": text});
      _isLoading = true;
    });

    try {
      // !!! QUAN TRỌNG: Đảm bảo URL này là URL MỚI NHẤT từ ngrok !!!
      const ngrokUrl = 'https://oversusceptibly-dire-maryrose.ngrok-free.dev/chat';

      final session = supabase.auth.currentSession;
      if (session == null) {
        _signOut(); // Tự động đăng xuất nếu hết hạn
        return;
      }
      final accessToken = session.accessToken;

      final response = await http.post(
        Uri.parse(ngrokUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'prompt': text}),
      );

      String aiResponseText;
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        aiResponseText = data['response'] ?? 'Lỗi: Không nhận được phản hồi.';
      } else {
        aiResponseText = 'Lỗi server: ${response.statusCode}. Vui lòng kiểm tra lại kết nối và URL ngrok.';
      }

      setState(() {
        _messages.insert(0, {"sender": "AI", "text": aiResponseText});
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, {"sender": "AI", "text": "Lỗi kết nối: Không thể gọi đến server. Vui lòng kiểm tra ngrok và server Python."});
      });
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skedule AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Đăng xuất',
          )
        ],
      ),
      body: Column(
        children: [
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (_, int index) {
                final message = _messages[index];
                final isUserMessage = message['sender'] == 'You';
                return Align(
                  alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
                    decoration: BoxDecoration(
                      color: isUserMessage ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(message['text'] ?? ''),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Flexible(
            child: TextField(
              controller: _textController,
              onSubmitted: _isLoading ? null : _handleSubmitted,
              decoration: const InputDecoration.collapsed(hintText: 'Nhập yêu cầu cho AI...'),
              enabled: !_isLoading,
            ),
          ),
          IconButton(
            icon: _isLoading ? const CircularProgressIndicator() : const Icon(Icons.send),
            onPressed: _isLoading ? null : () => _handleSubmitted(_textController.text),
          )
        ],
      ),
    );
  }
}