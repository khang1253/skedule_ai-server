import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- Add this line
import 'package:skedule/home/screens/home_screen.dart';

// STEP 1: Convert to a StatefulWidget
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // STEP 2: Create TextEditingControllers
  // We add _ to make them private to this class
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // It's good practice to dispose of controllers when the widget is removed
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC3C9E4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLoginCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF4A6C8B),
            child: Text(
              'S',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome to Skedule',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to your account',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // STEP 3: Attach the controllers to the TextFields
          _buildTextField(
            label: 'Email',
            controller: _emailController, // Attach email controller
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Password',
            controller: _passwordController, // Attach password controller
            isObscure: true,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: () async { // Make the function async
                  // Get the text from the controllers
                  final email = _emailController.text.trim();
                  final password = _passwordController.text.trim();

                  // Show a loading indicator (optional but good UX)
                  // TODO: Add a loading indicator

                  try {
                    // This is the Supabase sign-in call
                    final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(
                      email: email,
                      password: password,
                    );

                    // If we reach here, sign-in was successful
                    final user = res.user;
                    print('Sign-in successful for: ${user?.email}');

                    if (mounted) { // A best-practice check
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );
                    }

                  } catch (e) {
                    // If an error occurs (e.g., wrong password), it will be caught here
                    print('Error signing in: $e');

                    // TODO: Show a user-friendly error dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sign-in failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },

              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6C8B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement Google Sign In logic
              },
              // NOTE: For this to work, you need a 'assets' folder with a 'google_logo.png' image
              // For now, we'll just show an icon.
              icon: const Icon(Icons.g_mobiledata),
              label: const Text(
                'Continue with Google',
                style: TextStyle(color: Color(0xFF333333), fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to Sign Up screen
                },
                child: const Text(
                  'Sign up',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A6C8B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Updated helper method to accept a controller
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isObscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller, // Assign the controller here
          obscureText: isObscure,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
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
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}