// lib/features/authentication/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Thêm hàm này vào bên trong class State của bạn

String _translateAuthException(AuthException e) {
  // Mặc định là một câu thông báo chung
  String friendlyMessage = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';

  if (e.message.contains('Invalid login credentials')) {
    friendlyMessage = 'Email hoặc mật khẩu không chính xác.';
  } else if (e.message.contains('User already registered')) {
    friendlyMessage = 'Email này đã được đăng ký. Vui lòng chọn email khác.';
  } else if (e.message.contains('Password should be at least 6 characters')) {
    friendlyMessage = 'Mật khẩu phải có ít nhất 6 ký tự.';
  }
  // Bạn có thể thêm các trường hợp khác ở đây

  return friendlyMessage;
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _isLoading = true; });

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      if (mounted) {
        // Gọi hàm biên dịch trước khi hiển thị
        final friendlyMessage = _translateAuthException(e);
        _showErrorSnackBar(friendlyMessage);
      }
    }  finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC3C9E4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildLoginCard(context), // <<< Bây giờ hàm này đã có nội dung
          ),
        ),
      ),
    );
  }

  // === PHỤC HỒI LẠI GIAO DIỆN CỦA BẠN ===
  Widget _buildLoginCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF4A6C8B),
            child: Text('S', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          const Text('Welcome to Skedule', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          Text('Sign in to your account', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 32),
          _buildTextField(label: 'Email', controller: _emailController),
          const SizedBox(height: 16),
          _buildTextField(label: 'Password', controller: _passwordController, isObscure: true),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6C8B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sign In', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () { /* TODO: Google Sign In */ },
              icon: Image.asset(
                'assets/google_logo.png',
                height: 24.0, // Thêm chiều cao để logo không quá lớn
                width: 24.0,
              ),
              label: const Text('Continue with Google', style: TextStyle(color: Color(0xFF333333), fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                  );
                },
                child: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A6C8B))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, bool isObscure = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        obscureText: isObscure,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }

  Widget _buildDivider() {
    return Row(children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text('OR CONTINUE WITH', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ),
      const Expanded(child: Divider()),
    ]);
  }
}