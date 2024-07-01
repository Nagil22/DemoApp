import 'package:flutter/material.dart';

class PartyCalendarScreen extends StatelessWidget {
  const PartyCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Calendar'),
      ),
      body: const Center(
        child: Text('Party calendar will be shown here'),
      ),
    );
  }
}
