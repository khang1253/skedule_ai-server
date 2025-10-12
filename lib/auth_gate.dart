// lib/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/features/authentication/screens/login_screen.dart';
import 'package:skedule/features/authentication/screens/new_password_screen.dart';
// === IMPORT ĐÚNG FILE HOME MỚI ===
import 'package:skedule/home/screens/home_screen.dart';
import 'package:skedule/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    // StreamBuilder là nơi xử lý toàn bộ logic điều hướng
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 1. Bắt sự kiện PASSWORD_RECOVERY (Ưu tiên cao nhất)
        // Dẫn thẳng đến màn hình nhập mật khẩu mới.
        if (snapshot.hasData && snapshot.data!.event == AuthChangeEvent.passwordRecovery) {
          return const NewPasswordScreen();
        }

        // 2. Kiểm tra trạng thái ĐÃ ĐĂNG NHẬP
        // Session phải tồn tại và không phải là trạng thái recovery.
        if (snapshot.hasData && snapshot.data!.session != null) {
          // === ĐIỀU HƯỚNG TỚI MÀN HÌNH MỚI CHÍNH XÁC ===
          return const HomeScreen();
        }

        // 3. Mặc định: Trạng thái ĐĂNG XUẤT (hoặc các lỗi khác)
        else {
          return const LoginScreen();
        }
      },
    );
  }
}