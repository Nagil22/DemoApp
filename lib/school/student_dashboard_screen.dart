
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;

  const StudentDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
  });

  @override
  StudentDashboardScreenState createState() => StudentDashboardScreenState();
}

class StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _selectedIndex = 0;
  final List<Widget> _widgetOptions = [];

  @override
  void initState() {
    super.initState();
    _widgetOptions.addAll([
      _buildGradesSection(),
      _buildAttendanceSection(),
      _buildNotificationsSection(),
      _buildPaymentsSection(),
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.grade),
            label: 'Grades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Payments',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildGradesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('grades')
          .where('studentId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var grades = snapshot.data!.docs;

        return ListView.builder(
          itemCount: grades.length,
          itemBuilder: (context, index) {
            var grade = grades[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(grade['subject']),
              subtitle: Text('Grade: ${grade['grade']}'),
              trailing: Text('Date: ${DateFormat('yyyy-MM-dd').format((grade['date'] as Timestamp).toDate())}'),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: widget.userId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var attendanceRecords = snapshot.data!.docs;

        return ListView.builder(
          itemCount: attendanceRecords.length,
          itemBuilder: (context, index) {
            var record = attendanceRecords[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(DateFormat('yyyy-MM-dd').format((record['date'] as Timestamp).toDate())),
              subtitle: Text(record['status']),
              leading: Icon(
                record['status'] == 'Present' ? Icons.check_circle : Icons.cancel,
                color: record['status'] == 'Present' ? Colors.green : Colors.red,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var notifications = snapshot.data!.docs;

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            var notification = notifications[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(notification['title']),
              subtitle: Text(notification['message']),
              trailing: Text(DateFormat('yyyy-MM-dd – kk:mm').format((notification['timestamp'] as Timestamp).toDate())),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentsSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallets')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var walletData = snapshot.data!.data() as Map<String, dynamic>?;

        return Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('Current Balance'),
                subtitle: Text('\$${walletData?['balance'] ?? 0.0}'),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('userId', isEqualTo: widget.userId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var transactions = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      var transaction = transactions[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(transaction['description']),
                        subtitle: Text(DateFormat('yyyy-MM-dd – kk:mm').format((transaction['timestamp'] as Timestamp).toDate())),
                        trailing: Text('\$${transaction['amount']}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}