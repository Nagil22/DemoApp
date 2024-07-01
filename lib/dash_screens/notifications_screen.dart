import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.announcement),
            title: Text('Announcement'),
            subtitle: Text('New update available!'),
          ),
          ListTile(
            leading: Icon(Icons.notification_important),
            title: Text('Notice'),
            subtitle: Text('Server maintenance tonight.'),
          ),
          ListTile(
            leading: Icon(Icons.message),
            title: Text('Message'),
            subtitle: Text('Meeting scheduled at 3 PM.'),
          ),
        ],
      ),
    );
  }
}
