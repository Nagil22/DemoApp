import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolId;

  const AdminDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolId,
  });

  @override
  AdminDashboardScreenState createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  Future<void> sendNotification() async {
    final title = _titleController.text;
    final body = _bodyController.text;

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body cannot be empty')),
      );
      return;
    }

    // Add notification to Firestore
    await firestore.collection('notifications').add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Send FCM notification
    await FirebaseMessaging.instance.subscribeToTopic('all');
    await FirebaseMessaging.instance.sendMessage(
      to: '/topics/all',
      data: {
        'title': title,
        'body': body,
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification sent')),
    );

    _titleController.clear();
    _bodyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard - ${widget.username}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.white
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('School Management', Icons.school, _buildSchoolManagementWidget),
            _buildSection('User Management', Icons.people, _buildUserManagementWidget),
            _buildSection('Class Management', Icons.class_, _buildClassManagementWidget),
            _buildSection('Payment Management', Icons.payment, _buildPaymentManagementWidget),
            _buildSection('Notifications', Icons.notifications, _buildNotificationsWidget),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget Function() contentBuilder) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.blue.withOpacity(1),
      shape:  RoundedRectangleBorder(
          // side:  BorderSide(color: Colors.black.withOpacity(0.2), width: 1.0),
          borderRadius: BorderRadius.circular(10.0)
      ),
        child:
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(icon),
            title: Text(title),
            // textColor: Colors.blue,
            collapsedTextColor: Colors.white,
            iconColor: Colors.blue,
            collapsedIconColor: Colors.white,
            backgroundColor: Colors.white,
            children: [contentBuilder()],
          ),
        )
    );
  }

  Widget _buildSchoolManagementWidget() {
    return Column(
      children: [
        ListTile(
          title: const Text('School Information'),
          trailing: const Icon(Icons.info),
          onTap: () => _navigateToSchoolInfo(),
        ),
        ListTile(
          title: const Text('Update School Settings'),
          trailing: const Icon(Icons.settings),
          onTap: () => _navigateToSchoolSettings(),
        ),
      ],
    );
  }

  Widget _buildUserManagementWidget() {
    return Column(
      children: [
        ListTile(
          title: const Text('Create User Account'),
          trailing: const Icon(Icons.add),
          onTap: () => _navigateToCreateUser(),
        ),
        ListTile(
          title: const Text('Manage Users'),
          trailing: const Icon(Icons.edit),
          onTap: () => _navigateToManageUsers(),
        ),
      ],
    );
  }

  Widget _buildClassManagementWidget() {
    return Column(
      children: [
        ListTile(
          title: const Text('Create Class'),
          trailing: const Icon(Icons.add),
          onTap: () => _navigateToCreateClass(),
        ),
        ListTile(
          title: const Text('Manage Classes'),
          trailing: const Icon(Icons.edit),
          onTap: () => _navigateToManageClasses(),
        ),
      ],
    );
  }

  Widget _buildPaymentManagementWidget() {
    return Column(
      children: [
        ListTile(
          title: const Text('Payment Overview'),
          trailing: const Icon(Icons.dashboard),
          onTap: () => _navigateToPaymentOverview(),
        ),
        ListTile(
          title: const Text('Manage Payments'),
          trailing: const Icon(Icons.edit),
          onTap: () => _navigateToManagePayments(),
        ),
      ],
    );
  }

  Widget _buildNotificationsWidget() {
    return Column(
      children: [
        ListTile(
          title: const Text('Send Notification'),
          trailing: const Icon(Icons.send),
          onTap: () => _showSendNotificationDialog(),
        ),
        ListTile(
          title: const Text('Notification History'),
          trailing: const Icon(Icons.history),
          onTap: () => _navigateToNotificationHistory(),
        ),
      ],
    );
  }

  void _showSendNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Notification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Body'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                sendNotification();
                Navigator.of(context).pop();
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSchoolInfo() {
    // Navigate to school info screen
  }

  void _navigateToSchoolSettings() {
    // Navigate to school settings screen
  }

  void _navigateToCreateUser() {
    // Navigate to create user screen
  }

  void _navigateToManageUsers() {
    // Navigate to manage users screen
  }

  void _navigateToCreateClass() {
    // Navigate to create class screen
  }

  void _navigateToManageClasses() {
    // Navigate to manage classes screen
  }

  void _navigateToPaymentOverview() {
    // Navigate to payment overview screen
  }

  void _navigateToManagePayments() {
    // Navigate to manage payments screen
  }

  void _navigateToNotificationHistory() {
    // Navigate to notification history screen
  }
}
