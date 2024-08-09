import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateClassScreen extends StatefulWidget {
  final String schoolId;

  const CreateClassScreen({super.key, required this.schoolId});

  @override
  CreateClassScreenState createState() => CreateClassScreenState();
}

class CreateClassScreenState extends State<CreateClassScreen> {
  final TextEditingController _nameController = TextEditingController();

  void _createClass() {
    FirebaseFirestore.instance.collection('Schools').doc(widget.schoolId).collection('Classes').add({
      'name': _nameController.text,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class created')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Class')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Class Name'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createClass,
              child: const Text('Create Class'),
            ),
          ],
        ),
      ),
    );
  }
}
