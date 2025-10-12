// lib/widgets/ai_chat_bubble.dart

import 'package:flutter/material.dart';

class AiChatBubble extends StatelessWidget {
  const AiChatBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome, // Icon ngôi sao lấp lánh của AI
        color: Colors.white,
        size: 30,
      ),
    );
  }
}