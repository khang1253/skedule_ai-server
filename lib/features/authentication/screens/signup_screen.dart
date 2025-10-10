// lib/features/authentication/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart'; // Đường dẫn đến file main.dart
import '../../../home/screens/home_screen.dart'; // Đường dẫn đến home_screen.dart

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // Thêm controller cho xác nhận mật khẩu
  bool _isLoading = false;


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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // Dispose controller mới
    super.dispose();
  }
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // --- KIỂM TRA NGƯỜI DÙNG TỒN TẠI ---
      final userExists = await supabase.rpc(
        'check_if_user_exists',
        params: {'user_email': email},
      );

      if (mounted && userExists == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tài khoản đã tồn tại. Vui lòng đăng nhập.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // --- ĐĂNG KÝ ---
      await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Vui lòng kiểm tra email để xác thực.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }

    } on AuthException catch (e) {
      // Các lỗi liên quan đến đăng ký / đăng nhập
      final msg = _translateAuthException(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );

    } on PostgrestException catch (e) {
      // Các lỗi truy vấn cơ sở dữ liệu (ví dụ: permission denied)
      String msg = 'Hệ thống không có quyền truy cập dữ liệu. Vui lòng thử lại sau.';
      if (e.message.contains('permission denied')) {
        msg = 'Tài khoản hiện không có quyền đọc dữ liệu người dùng.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );

    } catch (error) {
      // Các lỗi khác
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xảy ra lỗi không mong muốn. Vui lòng thử lại sau.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC3C9E4), // Màu nền giống LoginScreen
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildSignUpCard(context), // Xây dựng thẻ đăng ký
          ),
        ),
      ),
    );
  }

  // === WIDGET XÂY DỰNG THẺ ĐĂNG KÝ (TƯƠNG TỰ _buildLoginCard) ===
  Widget _buildSignUpCard(BuildContext context) {
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
      child: Form(
        key: _formKey,
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
            Text('Create your account', style: TextStyle(color: Colors.grey[600])), // Thay đổi text ở đây
            const SizedBox(height: 32),
            _buildTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'Vui lòng nhập email hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Password',
              controller: _passwordController,
              isObscure: true,
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Mật khẩu phải có ít nhất 6 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Confirm Password',
              controller: _confirmPasswordController, // Sử dụng controller riêng
              isObscure: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng xác nhận mật khẩu';
                }
                if (value != _passwordController.text) {
                  return 'Mật khẩu không khớp';
                }
                return null;
              },
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
                child: const Text('Sign Up', style: TextStyle(fontSize: 16, color: Colors.white)), // Text là Sign Up
              ),
            ),
            const SizedBox(height: 24),
            _buildDivider(), // Divider giống LoginScreen
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { /* TODO: Triển khai đăng ký Google */ },
                icon: Image.asset( // Sử dụng Image.asset cho logo Google
                  'assets/google_logo.png',
                  height: 24.0,
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
                const Text("Already have an account?"),
                TextButton(
                  onPressed: () {
                    // Quay lại màn hình đăng nhập
                    Navigator.of(context).pop();
                  },
                  child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A6C8B))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // === CÁC WIDGET HỖ TRỢ (GIỮ NGUYÊN TỪ LoginScreen) ===
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
        const SizedBox(height: 8),
        TextFormField( // Thay thế TextField bằng TextFormField để có validator
          controller: controller,
          obscureText: isObscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          validator: validator, // Thêm validator
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('OR CONTINUE WITH', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}