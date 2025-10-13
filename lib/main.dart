// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:skedule/auth_gate.dart';

// BỎ navigatorKey và hàm _listenForAuthEvents
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // KHÔNG CẦN GỌI HÀM LẮNG NGHE Ở ĐÂY NỮA
  // _listenForAuthEvents();

  runApp(const MyApp());
}

// HÀM _listenForAuthEvents ĐÃ BỊ XÓA

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skedule',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // KHÔNG CẦN navigatorKey ở đây nữa
      home: const AuthGate(),
    );
  }
}

final supabase = Supabase.instance.client;