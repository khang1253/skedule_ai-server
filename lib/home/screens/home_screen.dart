import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart'; // Đảm bảo đường dẫn đúng đến file main.dart

import 'package:skedule/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.insert(0, {"sender": "AI", "text": "Chào bạn, tôi có thể giúp gì cho lịch trình của bạn?"});
  }

  // === HÀM ĐĂNG XUẤT MỚI ===
  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Đã xảy ra lỗi khi đăng xuất'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  Future<void> _handleSubmitted(String text) async {
    // ... (Giữ nguyên toàn bộ logic của hàm này)
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.insert(0, {"sender": "You", "text": text});
      _isLoading = true;
    });

    try {
      const ngrokUrl = 'https://oversusceptibly-dire-maryrose.ngrok-free.dev/chat';
      final session = supabase.auth.currentSession;
      if (session == null) {
        setState(() { _messages.insert(0, {"sender": "AI", "text": "Lỗi: Phiên đăng nhập đã hết hạn."}); });
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
        aiResponseText = 'Lỗi: ${response.statusCode}. Không thể kết nối đến server.';
      }

      setState(() {
        _messages.insert(0, {"sender": "AI", "text": aiResponseText});
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, {"sender": "AI", "text": "Lỗi kết nối: $e"});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTextComposer() {
    // ... (Giữ nguyên code của widget này)
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skedule AI'),
        // === THÊM NÚT ĐĂNG XUẤT VÀO ĐÂY ===
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Đăng xuất',
          )
        ],
      ),
      body: Column(
        // ... (Giữ nguyên code phần body)
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
          _buildTextComposer(),
        ],
      ),
    );
  }
}