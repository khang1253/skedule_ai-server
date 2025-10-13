import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. IMPORT PACKAGE CẦN THIẾT

// Sử dụng class để code sạch sẽ hơn
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  // === Quản lý State ===
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // State cho việc ghi âm
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // State cho việc phát âm thanh
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Thêm tin nhắn chào mừng ban đầu
    if (_messages.isEmpty) {
      _messages.insert(0, ChatMessage(text: "Chào bạn, tôi có thể giúp gì cho lịch trình của bạn?", isUser: false));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- HÀM XỬ LÝ LOGIC ---

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã xảy ra lỗi khi đăng xuất'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  /// Gửi request đến server AI với văn bản hoặc file âm thanh
  Future<void> _sendMessage({String? text, String? audioFilePath}) async {
    // Kiểm tra xem có nội dung để gửi không
    if ((text == null || text.isEmpty) && audioFilePath == null) return;

    if(text != null) _textController.clear();

    setState(() {
      if(text != null) _messages.insert(0, ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    try {
      // Lấy Access Token từ Supabase
      final session = supabase.auth.currentSession;
      if (session == null) {
        _signOut();
        return;
      }
      final accessToken = session.accessToken;

      // 2. LẤY URL TỪ FILE .ENV
      final serverUrl = dotenv.env['AI_SERVER_URL'];

      // *** DÒNG CODE CHẨN ĐOÁN MỚI ***
      // In ra URL mà ứng dụng đang thực sự sử dụng.
      print("--- DEBUG: Đang cố gắng kết nối đến AI Server tại: $serverUrl ---");

      if (serverUrl == null || serverUrl.isEmpty) {
        _addMessageToChat("Lỗi cấu hình: Vui lòng kiểm tra biến AI_SERVER_URL trong file .env.", isUser: false);
        setState(() => _isLoading = false);
        return;
      }

      var request = http.MultipartRequest('POST', Uri.parse('$serverUrl/chat'));

      // THÊM HEADER CHO SUPABASE AUTH
      request.headers['Authorization'] = 'Bearer $accessToken';

      // *** THAY ĐỔI QUAN TRỌNG: THÊM HEADER ĐỂ BỎ QUA CẢNH BÁO CỦA NGROK ***
      request.headers['ngrok-skip-browser-warning'] = 'true';

      if (text != null) {
        request.fields['prompt'] = text;
      } else if (audioFilePath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'audio_file',
          audioFilePath,
          contentType: MediaType('audio', 'm4a'),
        ));
      }

      // *** THAY ĐỔI QUAN TRỌNG: THÊM TIMEOUT CHO REQUEST ***
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          // Ném ra một lỗi cụ thể khi hết thời gian chờ
          throw TimeoutException('Kết nối đến server AI quá lâu, vui lòng thử lại.');
        },
      );

      String responseText;
      if (streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();

        // *** THAY ĐỔI QUAN TRỌNG: SỬA LẠI CÁCH GIẢI MÃ JSON ***
        final decodedResponse = jsonDecode(responseBody);

        responseText = decodedResponse['text_response'] ?? 'Lỗi: Không nhận được phản hồi.';
        final String audioBase64 = decodedResponse['audio_base_64'] ?? '';

        if (audioBase64.isNotEmpty) {
          _playAudio(audioBase64);
        }
      } else {
        responseText = 'Lỗi server: ${streamedResponse.statusCode}.';
      }
      _addMessageToChat(responseText, isUser: false);
    } on TimeoutException catch (e) {
      // Bắt lỗi timeout cụ thể
      _addMessageToChat("Lỗi: ${e.message}", isUser: false);
    } catch (e) {
      // Bắt các lỗi kết nối khác
      _addMessageToChat("Lỗi kết nối: $e", isUser: false);
      print("--- DEBUG: Lỗi chi tiết: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  /// Bắt đầu hoặc dừng ghi âm
  Future<void> _handleRecord() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() => _isRecording = false);
        _addMessageToChat("Đang xử lý giọng nói...", isUser: true);
        _sendMessage(audioFilePath: path);
      }
    } else {
      if (await Permission.microphone.request().isGranted) {
        final dir = await getApplicationDocumentsDirectory();
        await _audioRecorder.start(const RecordConfig(), path: '${dir.path}/recording.m4a');
        setState(() => _isRecording = true);
      } else {
        _addMessageToChat("Quyền truy cập micro đã bị từ chối.", isUser: false);
      }
    }
  }

  /// Giải mã Base64 và phát âm thanh
  Future<void> _playAudio(String base64Audio) async {
    try {
      setState(() => _isPlaying = true);
      final audioBytes = base64Decode(base64Audio);
      await _audioPlayer.play(BytesSource(audioBytes));
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      print("Lỗi phát audio: $e");
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  /// Thêm tin nhắn vào danh sách để hiển thị
  void _addMessageToChat(String text, {required bool isUser}) {
    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: isUser));
    });
  }

  // --- GIAO DIỆN ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skedule AI'),
        actions: [
          if (_isPlaying)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.volume_up, color: Colors.blue),
            ),
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
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
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
              onSubmitted: _isLoading ? null : (text) => _sendMessage(text: text),
              decoration: const InputDecoration.collapsed(hintText: 'Nhập hoặc giữ nút micro để nói...'),
              enabled: !_isLoading,
            ),
          ),
          IconButton(
            icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic),
            onPressed: _isLoading ? null : _handleRecord,
            color: _isRecording ? Colors.redAccent : Theme.of(context).primaryColor,
            iconSize: 28,
          ),
          IconButton(
            icon: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.0)) : const Icon(Icons.send),
            onPressed: _isLoading ? null : () => _sendMessage(text: _textController.text),
          )
        ],
      ),
    );
  }
}

