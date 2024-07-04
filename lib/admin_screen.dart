import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'screens/school_dashboard_screen.dart';
import 'screens/company_dashboard_screen.dart';
import 'screens/party_dashboard_screen.dart';   // Import Party Dashboard

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  AdminPanelScreenState createState() => AdminPanelScreenState();
}

class AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _notificationTitleController = TextEditingController();
  final TextEditingController _notificationBodyController = TextEditingController();
  final TextEditingController _calendarTitleController = TextEditingController();
  final TextEditingController _calendarDescriptionController = TextEditingController();
  DateTime _calendarDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // Increase to accommodate Dashboard tab
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          backgroundColor: Colors.black,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Notifications'),
              Tab(text: 'Calendar'),
              Tab(text: 'User Levels'),
              Tab(text: 'Dashboards'), // Add Dashboard Tab
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildNotificationsTab(context),
            _buildCalendarTab(context),
            _buildUserLevelsTab(context),
            _buildDashboardsTab(context), // Add Dashboards Tab Content
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SchoolDashboardScreen(username: '', userId: '',)),
              );
            },
            child: const Text('View Student Dashboard'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CompanyDashboardScreen(username: '', userId: '',)),
              );
            },
            child: const Text('View Employee Dashboard'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PartyDashboardScreen(username: '', userId: '',)),
              );
            },
            child: const Text('View Party Dashboard'),
          ),
        ],
      ),
    );
  }

  // Push Notifications Tab
  Widget _buildNotificationsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _notificationTitleController,
            decoration: const InputDecoration(labelText: 'Notification Title'),
          ),
          TextField(
            controller: _notificationBodyController,
            decoration: const InputDecoration(labelText: 'Notification Body'),
          ),
          ElevatedButton(
            onPressed: () {
              _sendNotification(context);
            },
            child: const Text('Send Notification'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var notifications = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    var notification = notifications[index];
                    return ListTile(
                      title: Text(notification['title']),
                      subtitle: Text(notification['body']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Send Notification
  void _sendNotification(BuildContext context) {
    final String title = _notificationTitleController.text.trim();
    final String body = _notificationBodyController.text.trim();
    if (title.isNotEmpty && body.isNotEmpty) {
      FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'timestamp': Timestamp.now(),
      }).then((value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification "$title" sent.')),
        );
        _notificationTitleController.clear();
        _notificationBodyController.clear();
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send notification: $error')),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
    }
  }

  // Calendar Tab
  Widget _buildCalendarTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _calendarTitleController,
            decoration: const InputDecoration(labelText: 'Event Title'),
          ),
          TextField(
            controller: _calendarDescriptionController,
            decoration: const InputDecoration(labelText: 'Event Description'),
          ),
          ElevatedButton(
            onPressed: () {
              _pickDate(context);
            },
            child: Text('Select Date: ${_calendarDate.toLocal()}'.split(' ')[0]),
          ),
          ElevatedButton(
            onPressed: () {
              _addCalendarEvent(context);
            },
            child: const Text('Add Event'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('calendar').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var events = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    var event = events[index];
                    var eventDate = (event['date'] as Timestamp).toDate();
                    return ListTile(
                      title: Text(event['title']),
                      subtitle: Text(event['description']),
                      trailing: Text(DateFormat('yyyy-MM-dd').format(eventDate)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Pick Date
  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _calendarDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != _calendarDate) {
      setState(() {
        _calendarDate = pickedDate;
      });
    }
  }

  // Add Calendar Event
  void _addCalendarEvent(BuildContext context) {
    final String title = _calendarTitleController.text.trim();
    final String description = _calendarDescriptionController.text.trim();
    if (title.isNotEmpty && description.isNotEmpty) {
      FirebaseFirestore.instance.collection('calendar').add({
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(_calendarDate),
      }).then((value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event "$title" added.')),
        );
        _calendarTitleController.clear();
        _calendarDescriptionController.clear();
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add event: $error')),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
    }
  }

  // User Levels Tab
  Widget _buildUserLevelsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: _roleController,
            decoration: const InputDecoration(labelText: 'Level'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateUserLevel(context);
            },
            child: const Text('Update Level'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var users = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index];
                    return ListTile(
                      title: Text(user['username']),
                      subtitle: Text('Level: ${user['role']}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Update User Level
  void _updateUserLevel(BuildContext context) {
    final String username = _usernameController.text.trim();
    final String role = _roleController.text.trim();
    if (username.isNotEmpty && role.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').where('username', isEqualTo: username).get().then((querySnapshot) {
        if (querySnapshot.docs.isNotEmpty) {
          querySnapshot.docs.first.reference.update({'role': role}).then((value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Level updated for $username.')),
            );
            _usernameController.clear();
            _roleController.clear();
          }).catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update level: $error')),
            );
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found.')),
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
    }
  }
}
