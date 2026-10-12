import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() => runApp(const SbarApp());

class SbarApp extends StatelessWidget {
  const SbarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SBAR Handover',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF0B6E8A), useMaterial3: true),
        home: const LoginScreen(),
      );
}
