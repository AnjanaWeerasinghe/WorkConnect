import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebugLoginScreen extends StatefulWidget {
  const DebugLoginScreen({super.key});

  @override
  State<DebugLoginScreen> createState() => _DebugLoginScreenState();
}

class _DebugLoginScreenState extends State<DebugLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = 'Ready to authenticate';

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Attempting login...';
    });

    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      setState(() {
        _statusMessage = 'Login successful! User: ${result.user?.email}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Login failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _testRegister() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Attempting registration...';
    });

    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      setState(() {
        _statusMessage = 'Registration successful! User: ${result.user?.email}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Registration failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Login Screen'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current Auth State: ${FirebaseAuth.instance.currentUser?.email ?? "Not signed in"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: $_statusMessage',
              style: TextStyle(
                color: _statusMessage.contains('failed') ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _testLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('TEST LOGIN', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('TEST REGISTER', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                setState(() {
                  _statusMessage = 'Signed out successfully';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('SIGN OUT', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}