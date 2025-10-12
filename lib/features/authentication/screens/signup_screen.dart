// lib/features/authentication/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/main.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- CÁC HÀM LOGIC (Giữ nguyên) ---
  void _showSnack(String message, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final userExists = await supabase.rpc(
        'check_if_user_exists',
        params: {'user_email': email},
      );

      if (mounted && userExists == true) {
        _showSnack('Tài khoản đã tồn tại. Vui lòng đăng nhập.', color: Colors.orange);
        return;
      }

      await supabase.auth.signUp(email: email, password: password);

      if (mounted) {
        _showSnack('Đăng ký thành công! Vui lòng kiểm tra email để xác thực.', color: Colors.green);
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showSnack('Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            child: _buildSignUpCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Form(
        key: _formKey,
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
            const Text('Create your account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(height: 32),
            _buildTextField(
              label: 'Email', controller: _emailController, keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Password', controller: _passwordController, isObscure: true,
              validator: (v) => (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Confirm Password', controller: _confirmPasswordController, isObscure: true,
              validator: (v) => (v != _passwordController.text) ? 'Mật khẩu không khớp' : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6C8B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Sign Up', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?"),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A6C8B))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS PHỤ (Giữ nguyên) ---
  Widget _buildTextField({required String label, required TextEditingController controller, bool isObscure = false, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller, obscureText: isObscure, keyboardType: keyboardType,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true, fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
        validator: validator,
      ),
    ]);
  }
}