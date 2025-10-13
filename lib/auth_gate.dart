// lib/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:skedule/home/screens/home_screen.dart'; // Sửa đường dẫn nếu cần
import 'package:skedule/features/authentication/screens/login_screen.dart';
import 'package:skedule/features/authentication/screens/new_password_screen.dart'; // Import màn hình mới
import 'package:skedule/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;

  // Biến cờ để theo dõi trạng thái khôi phục mật khẩu
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();

    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      // Nếu sự kiện là passwordRecovery, bật cờ và build lại UI
      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _isPasswordRecovery = true;
        });
      }
      // Nếu người dùng đăng xuất (sau khi đổi pass xong), tắt cờ và build lại UI
      else if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _isPasswordRecovery = false;
        });
      }
      // Với các sự kiện khác như đăng nhập, chỉ cần build lại
      else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ưu tiên cao nhất: Nếu đang trong luồng khôi phục mật khẩu,
    // luôn hiển thị màn hình NewPasswordScreen.
    if (_isPasswordRecovery) {
      return const NewPasswordScreen();
    }

    // Logic cũ: Kiểm tra session để quyết định giữa HomeScreen và LoginScreen
    final session = supabase.auth.currentSession;
    if (session != null) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}