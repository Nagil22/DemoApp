//admin_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatelessWidget {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  AdminPanelScreen({super.key});

  void _createPendingUser(BuildContext context) {
    final String username = _usernameController.text.trim();
    final String role = _roleController.text.trim();

    if (username.isNotEmpty && role.isNotEmpty) {
      FirebaseFirestore.instance.collection('pending_users').add({
        'username': username,
        'role': role,
      }).then((value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pending user $username created.')),
        );
        _usernameController.clear();
        _roleController.clear();
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create pending user: $error')),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => _createPendingUser(context),
                child: const Text('Create Pending User'),
            ),
          ],
        ),
      ),
    );
  }
}
