import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolId;

  const AdminDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolId, required String schoolName,
  });

  @override
  AdminDashboardScreenState createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedIndex = 0;
  String _schoolName = '';
  Color _colorPrimary = Colors.blue;
  Color _colorSecondary = Colors.grey;

  @override
  void initState() {
    super.initState();
    _fetchSchoolConfiguration();
  }

  Future<void> _fetchSchoolConfiguration() async {
    final schoolDoc = await _firestore.collection('schools').doc(widget.schoolId).get();
    if (schoolDoc.exists) {
      final schoolConfig = schoolDoc.data()!;
      setState(() {
        _schoolName = schoolConfig['name'];
        _colorPrimary = Color(int.parse(schoolConfig['colorPrimary'].replaceFirst('#', '0xff')));
        _colorSecondary = Color(int.parse(schoolConfig['colorSecondary'].replaceFirst('#', '0xff')));
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primaryColor: _colorPrimary,
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: _colorSecondary),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin Dashboard - $_schoolName'),
          backgroundColor: _colorPrimary,
          actions: [
            IconButton(
              icon: Icon(Icons.notifications, color: _colorSecondary),
              onPressed: () {
                // TODO: Implement notification viewing functionality
              },
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Overview',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Users',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.payment),
              label: 'Payments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: _colorPrimary,
          unselectedItemColor: _colorSecondary,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewPage();
      case 1:
        return _buildUsersPage();
      case 2:
        return _buildPaymentsPage();
      case 3:
        return _buildNotificationsPage();
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _buildOverviewPage() {
    // TODO: Implement overview page
    return const Center(child: Text('Overview Page'));
  }

  Widget _buildUsersPage() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _showCreateUserDialog,
          child: const Text('Create New User'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('schools').doc(widget.schoolId).collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return ListView(
                children: snapshot.data!.docs.map((doc) {
                  final user = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(user['name']),
                    subtitle: Text(user['email']),
                    trailing: Text(user['role']),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsPage() {
    // TODO: Implement payments page
    return const Center(child: Text('Payments Page'));
  }

  Widget _buildNotificationsPage() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _showSendNotificationDialog,
          child: const Text('Send New Notification'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('schools').doc(widget.schoolId).collection('notifications').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return ListView(
                children: snapshot.data!.docs.map((doc) {
                  final notification = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(notification['title']),
                    subtitle: Text(notification['body']),
                    trailing: Text(notification['timestamp'].toDate().toString()),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateUserDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController roleController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async {
                try {
                  UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
                    email: emailController.text,
                    password: passwordController.text,
                  );

                  await _firestore.collection('schools').doc(widget.schoolId).collection('users').doc(userCredential.user!.uid).set({
                    'name': nameController.text,
                    'email': emailController.text,
                    'role': roleController.text,
                    'schoolId': widget.schoolId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User created successfully')),
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating user: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showSendNotificationDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Notification'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(labelText: 'Body'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Send'),
              onPressed: () async {
                try {
                  await _firestore.collection('schools').doc(widget.schoolId).collection('notifications').add({
                    'title': titleController.text,
                    'body': bodyController.text,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  await FirebaseMessaging.instance.subscribeToTopic('school_${widget.schoolId}');
                  await FirebaseMessaging.instance.sendMessage(
                    to: '/topics/school_${widget.schoolId}',
                    data: {
                      'title': titleController.text,
                      'body': bodyController.text,
                    },
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification sent successfully')),
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending notification: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}