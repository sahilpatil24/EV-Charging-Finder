import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  bool isLoading = true;
  bool isEditing = false;
  String? photoUrl;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      usernameController.text = data["username"] ?? "";
      phoneController.text = data["phone"] ?? "";
      addressController.text = data["address"] ?? "";
      photoUrl = data["photoUrl"];
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveProfile() async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .set({
      "username": usernameController.text,
      "phone": phoneController.text,
      "address": addressController.text,
      "photoUrl": photoUrl,
    }, SetOptions(merge: true));

    setState(() {
      isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile Updated ✅")),
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null || user == null) return;

    final file = File(picked.path);

    setState(() {
      _imageFile = file;
    });

    /// Upload to Firebase Storage
    final ref = FirebaseStorage.instance
        .ref()
        .child("profile_pictures")
        .child("${user!.uid}.jpg");

    await ref.putFile(file);

    final downloadUrl = await ref.getDownloadURL();

    /// Save URL to Firestore
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .update({
      "photoUrl": downloadUrl,
    });

    setState(() {
      photoUrl = downloadUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile picture updated 📸")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
              });
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            /// Profile Avatar
            GestureDetector(
              onTap: isEditing ? pickImage : null,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.green,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : (photoUrl != null
                    ? NetworkImage(photoUrl!) as ImageProvider
                    : null),
                child: (_imageFile == null && photoUrl == null)
                    ? const Icon(Icons.person, size: 55, color: Colors.white)
                    : null,
              ),
            ),


            const SizedBox(height: 15),

            Text(
              user?.email ?? "",
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            /// Username
            isEditing
                ? TextField(
              controller: usernameController,
              decoration:
              const InputDecoration(labelText: "Username"),
            )
                : ListTile(
              title: const Text("Username"),
              subtitle: Text(usernameController.text),
            ),

            /// Phone
            isEditing
                ? TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration:
              const InputDecoration(labelText: "Phone"),
            )
                : ListTile(
              title: const Text("Phone"),
              subtitle: Text(phoneController.text),
            ),

            /// Address
            isEditing
                ? TextField(
              controller: addressController,
              maxLines: 2,
              decoration:
              const InputDecoration(labelText: "Address"),
            )
                : ListTile(
              title: const Text("Address"),
              subtitle: Text(addressController.text),
            ),

            const SizedBox(height: 30),

            /// Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                if (isEditing)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saveProfile,
                      child: const Text("Save"),
                    ),
                  ),

                const SizedBox(width: 15),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pop(context);
                    },
                    child: const Text("Logout"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}