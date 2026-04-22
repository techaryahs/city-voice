import 'package:cityvoice/view/screens/landing_screen.dart';
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
      home: const LandingScreen(),
    );
  }
}