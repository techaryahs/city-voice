import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';

class RaiseVoicePage extends StatefulWidget {
  const RaiseVoicePage({super.key});

  @override
  State<RaiseVoicePage> createState() => _RaiseVoicePageState();
}

class _RaiseVoicePageState extends State<RaiseVoicePage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  File? _image;
  bool isLoading = false;

  final dbRef = FirebaseDatabase.instance.ref("posts");

  // 📸 Pick Image (LOCAL ONLY)
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  // 🔥 Save post (NO STORAGE, only DB)
  Future<void> uploadPost() async {
    if (_descController.text.isEmpty || _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add description & image")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await dbRef.push().set({
        "description": _descController.text,
        "location": _locationController.text,
        "image_local_path": _image!.path, // ✅ local path only
        "timestamp": DateTime.now().toString(),
      });

      setState(() {
        _image = null;
        _descController.clear();
        _locationController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved locally 🚀")),
      );
    } catch (e) {
      print(e);
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Raise Voice"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.campaign, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Raise Voice",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Description
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "What's the issue?",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 16),

            // Image picker
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _image == null
                    ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 40),
                    Text("Add a photo"),
                  ],
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Location
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: "Add Location",
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 20),

            // Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : uploadPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Raise Voice"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}