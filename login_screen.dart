import 'package:flutter/material.dart';
import '../services/api.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController(text: 'nurse1');
  final pass = TextEditingController(text: 'nurse123');
  String? error;
  bool busy = false;

  Future<void> _go() async {
    setState(() { busy = true; error = null; });
    try {
      await api.login(user.text, pass.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeShell()));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.medical_services, size: 56),
                const SizedBox(height: 8),
                Text('SBAR Handover', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextField(controller: user, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 16),
                FilledButton(onPressed: busy ? null : _go, child: Text(busy ? 'Signing in...' : 'Sign in')),
                const SizedBox(height: 8),
                const Text('Backend offline? The app falls back to demo data.', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      );
}
