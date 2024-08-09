import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;

  const TeacherDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
  });

  @override
  TeacherDashboardScreenState createState() => TeacherDashboardScreenState();
}

class TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedIndex = 0;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Dashboard - ${widget.username}'),
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
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Assignments'),
          BottomNavigationBarItem(icon: Icon(Icons.grade), label: 'Grades'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Attendance'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildAssignmentsSection();
      case 1:
        return _buildGradesSection();
      case 2:
        return buildCalendarSection();
      case 3:
        return _buildAttendanceSection();
      default:
        return const Center(child: Text('Unknown section'));
    }
  }

  Widget _buildAssignmentsSection() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _uploadAssignment,
          child: const Text('Upload Assignment'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('assignments')
                .where('teacherId', isEqualTo: widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['title']),
                    subtitle: Text(data['description']),
                    trailing: Text(DateFormat('yyyy-MM-dd').format(data['dueDate'].toDate())),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGradesSection() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _uploadGrades,
          child: const Text('Upload Grades'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('grades')
                .where('teacherId', isEqualTo: widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['studentName']),
                    subtitle: Text(data['subject']),
                    trailing: Text(data['grade'].toString()),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildCalendarSection() {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
        ),
        ElevatedButton(
          onPressed: () => _addActivity(_selectedDay ?? _focusedDay),
          child: const Text('Add Activity'),
        ),
      ],
    );
  }

  Widget _buildAttendanceSection() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _markAttendance,
          child: const Text('Mark Attendance'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('teacherId', isEqualTo: widget.userId)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['studentName']),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(data['date'].toDate())),
                    trailing: Text(data['status']),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _uploadAssignment() {
    // Implement assignment upload logic
  }

  void _uploadGrades() {
    // Implement grade upload logic
  }

  void _addActivity(DateTime day) {
    // Implement activity addition logic
  }

  void _markAttendance() {
    // Implement attendance marking logic
  }
}
