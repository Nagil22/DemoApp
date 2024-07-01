import 'package:flutter/material.dart';

class MemberProfilesScreen extends StatelessWidget {
  const MemberProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Profiles'),
      ),
      body: const Center(
        child: Text('List of member profiles will be shown here'),
      ),
    );
  }
}
