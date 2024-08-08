import 'package:demo/screens/company_dashboard_screen.dart';
import 'package:demo/screens/party_dashboard_screen.dart';
import 'package:demo/screens/school_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  AdminPanelScreenState createState() => AdminPanelScreenState();
}

class AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    NotificationsScreen(),
    CalendarScreen(),
    UserManagementScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.black,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SchoolDashboardScreen(username: '', userId: '')),
              );
            },
            child: const Text('View Student Dashboard'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CompanyDashboardScreen(username: '', userId: '')),
              );
            },
            child: const Text('View Employee Dashboard'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PoliticalPartyDashboardScreen(username: '', userId: '')),
              );
            },
            child: const Text('View Party Dashboard'),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController notificationTitleController = TextEditingController();
    final TextEditingController notificationBodyController = TextEditingController();

    void sendNotification(BuildContext context) {
      final String title = notificationTitleController.text.trim();
      final String body = notificationBodyController.text.trim();
      if (title.isNotEmpty && body.isNotEmpty) {
        FirebaseFirestore.instance.collection('notifications').add({
          'title': title,
          'body': body,
          'timestamp': Timestamp.now(),
        }).then((value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notification "$title" sent.')),
          );
          notificationTitleController.clear();
          notificationBodyController.clear();
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: notificationTitleController,
            decoration: const InputDecoration(labelText: 'Notification Title'),
          ),
          TextField(
            controller: notificationBodyController,
            decoration: const InputDecoration(labelText: 'Notification Body'),
          ),
          ElevatedButton(
            onPressed: () {
              sendNotification(context);
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
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  final TextEditingController _calendarTitleController = TextEditingController();
  final TextEditingController _calendarDescriptionController = TextEditingController();
  DateTime _calendarDate = DateTime.now();

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

  @override
  Widget build(BuildContext context) {
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
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController roleController = TextEditingController();

    void updateUserLevel(BuildContext context) {
      final String username = usernameController.text.trim();
      final String role = roleController.text.trim();
      if (username.isNotEmpty && role.isNotEmpty) {
        FirebaseFirestore.instance.collection('users').where('username', isEqualTo: username).get().then((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            querySnapshot.docs.first.reference.update({'role': role}).then((value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Level updated for $username.')),
              );
              usernameController.clear();
              roleController.clear();
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: roleController,
            decoration: const InputDecoration(labelText: 'Level'),
          ),
          ElevatedButton(
            onPressed: () {
              updateUserLevel(context);
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
}
