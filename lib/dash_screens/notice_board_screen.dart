import 'package:flutter/material.dart';

class NoticeBoardScreen extends StatelessWidget {
  const NoticeBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Board'),
      ),
      body: const Center(
        child: Text('Notices will be shown here'),
      ),
    );
  }
}
