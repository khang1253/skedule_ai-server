// lib/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/features/authentication/screens/login_screen.dart';
import 'package:skedule/home/screens/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data?.session;

        // KIỂM TRA MỚI: Người dùng có session VÀ đã xác thực email
        if (session != null && session.user.emailConfirmedAt != null) {
          return const HomeScreen();
        }
        // Các trường hợp còn lại (chưa đăng nhập, hoặc có đăng nhập nhưng chưa xác thực)
        else {
          return const LoginScreen();
        }
      },
    );
  }
}