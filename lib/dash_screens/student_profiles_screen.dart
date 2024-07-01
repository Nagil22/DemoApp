import 'package:flutter/material.dart';

class StudentProfilesScreen extends StatelessWidget {
  const StudentProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profiles'),
      ),
      body: const Center(
        child: Text('List of student profiles will be shown here'),
      ),
    );
  }
}
