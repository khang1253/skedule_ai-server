import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- Import the package
import 'features/authentication/screens/login_screen.dart';

// The main function now needs to be `async`
Future<void> main() async {
  // This line is required to ensure that everything is set up
  // before we initialize Supabase.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase

  await Supabase.initialize(
    url: 'https://qlajfnrhmrrztiwvzlim.supabase.co',       // <-- Paste your URL here
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsYWpmbnJobXJyenRpd3Z6bGltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4MTg4NTksImV4cCI6MjA3NTM5NDg1OX0.23JqnFRYtO8-SNGeXOlODtjgo-yGNXY_adbLo01vVGM', // <-- Paste your Anon Key here
  );

  runApp(const MyApp());
}

// The rest of your file (class MyApp, etc.) stays the same.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skedule App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6C8B)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}