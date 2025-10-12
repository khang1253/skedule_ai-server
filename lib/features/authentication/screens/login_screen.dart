// lib/features/authentication/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/main.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
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

  // --- CÁC HÀM LOGIC (Giữ nguyên) ---
  String _translateAuthException(AuthException e) {
    if (e.message.contains('Invalid login credentials')) {
      return 'Email hoặc mật khẩu không chính xác.';
    }
    return 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _googleSignIn() async {
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.skedule://login-callback',
      );
    } on AuthException catch (e) {
      _showErrorSnackBar(_translateAuthException(e));
    }
  }

  Future<void> _signIn() async {
    setState(() { _isLoading = true; });
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      _showErrorSnackBar(_translateAuthException(e));
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  Future<void> _forgotPassword() async {
    final emailForReset = _emailController.text.trim();
    if (emailForReset.isEmpty || !emailForReset.contains('@')) {
      _showErrorSnackBar('Vui lòng nhập email của bạn vào ô Email trước.');
      return;
    }

    setState(() { _isLoading = true; });
    try {
      await supabase.auth.resetPasswordForEmail(
        emailForReset,
        redirectTo: 'io.supabase.skedule://login-callback',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi link đặt lại mật khẩu. Vui lòng kiểm tra email.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch(e) {
      _showErrorSnackBar(_translateAuthException(e));
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- GIAO DIỆN ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC3C9E4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildLoginCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // === THAY ĐỔI LOGO TẠI ĐÂY ===
          // Từ CircleAvatar...
          // const CircleAvatar(
          //   radius: 30, backgroundColor: Color(0xFF4A6C8B),
          //   child: Text('S', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          // ),
          // ...thành Image.asset
          Image.asset('assets/app_logo.jpg', height: 60),
          // =============================
          const SizedBox(height: 16),
          // Sửa lại tên app cho nhất quán
          const Text('Welcome to Skedule', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          Text('Sign in to your account', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 32),
          _buildTextField(label: 'Email', controller: _emailController),
          const SizedBox(height: 16),
          _buildTextField(label: 'Password', controller: _passwordController, isObscure: true),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _forgotPassword,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(color: Color(0xFF4A6C8B)),
              ),
            ),
          ),
          const SizedBox(height: 16),

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
              onPressed: _isLoading ? null : _googleSignIn,
              icon: Image.asset('assets/google_logo.png', height: 24.0, width: 24.0),
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
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SignUpScreen()));
                },
                child: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A6C8B))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGETS PHỤ (Giữ nguyên) ---
  Widget _buildTextField({required String label, required TextEditingController controller, bool isObscure = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
      const SizedBox(height: 8),
      TextField(
        controller: controller, obscureText: isObscure,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true, fillColor: Colors.grey[100],
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