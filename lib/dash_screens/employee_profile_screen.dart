import 'package:flutter/material.dart';

class EmployeeProfilesScreen extends StatelessWidget {
  const EmployeeProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Profiles'),
      ),
      body: const Center(
        child: Text('List of employee profiles will be shown here'),
      ),
    );
  }
}
