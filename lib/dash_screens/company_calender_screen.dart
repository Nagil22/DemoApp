import 'package:flutter/material.dart';

class CompanyCalendarScreen extends StatelessWidget {
  const CompanyCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Calendar'),
      ),
      body: const Center(
        child: Text('Company calendar will be shown here'),
      ),
    );
  }
}
