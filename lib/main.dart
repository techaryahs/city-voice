import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // 🔥 Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Firebase Boolean Test'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref("test/value");

  bool firebaseValue = false;

  @override
  void initState() {
    super.initState();

    // 🔥 Listen to real-time changes
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data != null) {
        setState(() {
          firebaseValue = data as bool;
        });
      }
    });
  }

  // 🔥 Toggle value and send to Firebase
  void _toggleValue() async {
    bool newValue = !firebaseValue;

    await _dbRef.set(newValue);

    setState(() {
      firebaseValue = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "Firebase Boolean Value:",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),

            // 🔥 Display value
            Text(
              firebaseValue ? "TRUE ✅" : "FALSE ❌",
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            // 🔥 Toggle Button
            ElevatedButton(
              onPressed: _toggleValue,
              child: const Text("Toggle Firebase Value"),
            ),
          ],
        ),
      ),
    );
  }
}