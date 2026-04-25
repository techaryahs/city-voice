import 'package:cityvoice/view/screens/admin/admin_dashboard_screen.dart';
import 'package:cityvoice/view/screens/landing_screen.dart';
import 'package:cityvoice/view/screens/users/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    requestPermissions(); // 🔥 call on app start
  }

  // 🔥 Permission Request Function
  Future<void> requestPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'City Voice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      // 🔥 Auth-aware routing: skip sign-in if user is already logged in
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Waiting for Firebase to restore auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              ),
            );
          }

          final user = snapshot.data;

          // ✅ User is logged in — send them to the right screen
          if (user != null) {
            if (user.email == 'admin@cityvoice.com') {
              return const AdminDashboardScreen();
            }
            return const MainScreen();
          }

          // ❌ Not logged in — show landing/sign-in flow
          return const LandingScreen();
        },
      ),
    );
  }
}