import 'package:flutter/material.dart';
import 'package:draggable_fab/draggable_fab.dart';
import 'package:skedule/home/screens/calendar_screen.dart'; // <<< ĐÃ THÊM DÒNG NÀY
import 'package:skedule/home/screens/ai_agent_screen.dart';
import 'package:skedule/home/screens/dashboard_page.dart';
import 'package:skedule/home/screens/preferences_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // === THAY ĐỔI Ở ĐÂY ===
  // Thay thế widget giữ chỗ bằng CalendarScreen thật
  static final List<Widget> _mainPages = <Widget>[
    const DashboardPage(),
    const CalendarScreen(),
    const Center(child: Text('Notes Page')),
  ];
  // =====================

  void _showPreferencesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const PreferencesSheet();
      },
    );
  }

  void _onNavItemTapped(int index) {
    if (index == 3) {
      _showPreferencesSheet();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _mainPages,
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 90),
              child: FloatingActionButton(
                heroTag: 'ai_fab',
                mini: true,
                backgroundColor: Colors.purple,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AiAgentScreen()),
                  );
                },
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: DraggableFab(
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF4A6C8B),
          onPressed: () {
            // TODO: Mở màn hình tạo task mới
          },
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          // === SỬA LỖI Ở ĐÂY ===
          // Chỉ cần một "mainAxisAlignment:"
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', index: 0),
            _buildNavItem(icon: Icons.calendar_month_rounded, label: 'Calendar', index: 1),
            const SizedBox(width: 48), // Khoảng trống cho FAB chính
            _buildNavItem(icon: Icons.note_alt_rounded, label: 'Notes', index: 2),
            _buildNavItem(icon: Icons.settings_rounded, label: 'Preferences', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index && index != 3;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? const Color(0xFF4A6C8B) : Colors.grey.shade400,
        size: 28,
      ),
      onPressed: () => _onNavItemTapped(index),
      tooltip: label,
    );
  }
}
