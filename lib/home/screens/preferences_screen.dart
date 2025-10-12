// lib/screens/preferences/preferences_sheet.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/main.dart'; // Để lấy biến supabase

class PreferencesSheet extends StatelessWidget {
  const PreferencesSheet({super.key});

  // --- HÀM LOGIC LOGOUT ---
  Future<void> _signOut(BuildContext context) async {
    // Đóng bottom sheet trước khi thực hiện logout để tránh lỗi context
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    try {
      await supabase.auth.signOut();
      // AuthGate sẽ tự động phát hiện thay đổi và điều hướng về màn hình Login
    } on AuthException catch (e) {
      // Xử lý nếu có lỗi trong quá trình logout (hiếm gặp)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi đăng xuất: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- GIAO DIỆN ---
  @override
  Widget build(BuildContext context) {
    // Lấy thông tin người dùng hiện tại (dữ liệu giả, sẽ thay bằng Supabase sau)
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? 'john.doe@example.com';
    final userName = user?.userMetadata?['name'] ?? 'John Doe';
    final userInitials = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'JD';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),
          const SizedBox(height: 16),
          // Tabs (hiện tại chỉ là giao diện)
          _buildTabs(),
          const SizedBox(height: 24),

          // --- PHẦN CHÍNH: TÀI KHOẢN ---
          const Text('Account Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),

          _buildAccountInfoCard(userInitials, userName, userEmail),
          const SizedBox(height: 16),

          _buildInfoTile(icon: Icons.email_outlined, text: userEmail),
          _buildInfoTile(icon: Icons.calendar_today_outlined, text: 'Member Since January 2024'), // Dữ liệu giả

          const Divider(height: 32),

          _buildActionTile(
            context: context,
            icon: Icons.person_outline,
            text: 'Edit Profile',
            onTap: () { /* TODO: Mở màn hình chỉnh sửa profile */ },
          ),

          // === NÚT LOGOUT ===
          _buildActionTile(
            context: context,
            icon: Icons.logout,
            text: 'Sign Out',
            color: Colors.red,
            onTap: () => _signOut(context), // Gọi hàm logout khi nhấn
          ),

          const SizedBox(height: 24),
          const Center(child: Text('Skedule v1.0.0', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  // --- CÁC WIDGET PHỤ ---
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.settings_outlined),
        const SizedBox(width: 8),
        const Text('Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton('Account', isSelected: true),
          _buildTabButton('Settings'),
          _buildTabButton('Theme'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, {bool isSelected = false}) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.white : Colors.transparent,
          foregroundColor: isSelected ? const Color(0xFF4A6C8B) : Colors.grey.shade700,
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildAccountInfoCard(String initials, String name, String email) {
    return Card(
      color: const Color(0xFF4A6C8B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Text(initials, style: const TextStyle(color: Color(0xFF4A6C8B), fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(email, style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), onPressed: () {}),
              ],
            ),
            const Divider(color: Colors.white30, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('127', 'Tasks Done'),
                _buildStat('12', 'Day Streak'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Free Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildInfoTile({required IconData icon, required String text}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade700),
        title: Text(text),
      ),
    );
  }

  Widget _buildActionTile({required BuildContext context, required IconData icon, required String text, Color? color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).iconTheme.color),
      title: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}