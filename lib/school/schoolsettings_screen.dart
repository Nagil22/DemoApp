import 'package:flutter/material.dart';

class SchoolSettingsScreen extends StatelessWidget {
  final String schoolId;

  const SchoolSettingsScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School Settings')),
      body: const Center(child: Text('Settings will be implemented here')),
    );
  }
}
