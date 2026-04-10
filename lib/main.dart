import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nvctbcqazlhagmvnubtl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52Y3RiY3FhemxoYWdtdm51YnRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4NDI4NzMsImV4cCI6MjA4ODQxODg3M30.6YdjdANI-wnO58lVzyJ6XxNom8kVOIqtWU6TpVKHJoM',
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shawarma 4you',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return const DashboardPage(); // ✅ مسجل دخول
    } else {
      return const LoginPage(); // ❌ مش مسجل
    }
  }
}
