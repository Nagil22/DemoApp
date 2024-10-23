import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/profile_screen.dart';
import '../dash_screens/payments_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolCode;
  final String schoolName;

  const StudentDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolCode,
    required this.schoolName,
  });

  @override
  StudentDashboardScreenState createState() => StudentDashboardScreenState();
}

List<IconData> navIcons = [
  Icons.dashboard,
  Icons.assignment,
  Icons.payment,
  Icons.person,
];
List<String> navTitle = [
  "Overview",
  "Assignments",
  "Payments",
  "Profile"
];


class StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _selectedIndex = 0;
  Color _accentColor = Colors.blue;
  int notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToAccentColorChanges();
    _listenToNotifications();
    _verifyUserData();
  }

  void _listenToAccentColorChanges() {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final accentColorHex = data['studentColor'] as String?;
        if (accentColorHex != null) {
          setState(() {
            _accentColor = Color(
                int.parse(accentColorHex.substring(1), radix: 16) + 0xFF000000);
          });
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print("Error listening to accent color changes: $error");
      }
    });
  }

  void _listenToNotifications() {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('notifications')
        .where('recipientIds', arrayContains: widget.userId)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        notificationCount = snapshot.docs
            .where((doc) => doc.data()['read'] == false)
            .length;
      });
    }, onError: (error) {
      if (kDebugMode) {
        print("Error listening to notifications: $error");
      }
    });
  }

  void _verifyUserData() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (kDebugMode) {
      print('User data: ${userDoc.data()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: _accentColor,
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: _accentColor),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              'Welcome, ${widget.username}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 20
              )
          ),
          // backgroundColor: _accentColor,
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.black),
                  onPressed: _showNotificationsDialog,
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            _getSelectedSection(),
            Align(alignment: Alignment.bottomCenter, child: _navBar())
        ]
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _navBar(){
    return Container(
        height: 65,
        margin: const EdgeInsets.only(
            right: 24,
            left: 24,
            bottom: 24
        ),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 20,
                  spreadRadius: 10
              )
            ]
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: navIcons.map((icon) {
            int index = navIcons.indexOf(icon);
            bool isSelected = _selectedIndex == index;
            return Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: (){
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(
                            top: 15,
                            bottom:0,
                            left: 30,
                            right: 30
                        ),
                        child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
                      ),
                      Text(
                          navTitle[index],
                          style: TextStyle(
                              color: isSelected ? Colors.blue : Colors.grey,
                              fontSize: 10
                          )
                      ),
                      const SizedBox(height: 15)
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        )
    );
  }

  Widget _getSelectedSection() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewSection();
      case 1:
        return _buildAssignmentsSection();
      case 2:
        return PaymentsScreen(
            userId: widget.userId, schoolCode: widget.schoolCode);
      case 3:
        return ProfileScreen(
          userId: widget.userId,
          username: widget.username,
          email: '', // Ensure this gets passed correctly
          userType: 'student',
          accentColor: _accentColor,
        );
      default:
        return _buildOverviewSection();
    }
  }

  Widget _buildOverviewSection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('schools')
          .where('code', isEqualTo: widget.schoolCode)
          .limit(1)
          .get(),
      builder: (context, schoolSnapshot) {
        if (schoolSnapshot.hasError) {
          return Center(child: Text('Error fetching school: ${schoolSnapshot.error}'));
        }

        if (schoolSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var schoolDocs = schoolSnapshot.data?.docs ?? [];
        if (schoolDocs.isEmpty) {
          return const Center(child: Text('No school found with the given school code.'));
        }

        var schoolDoc = schoolDocs.first;
        var schoolId = schoolDoc.id;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('classes')
              .where('studentIds', arrayContains: widget.userId)
              .snapshots(),
          builder: (context, classSnapshot) {
            if (classSnapshot.hasError) {
              return Center(child: Text('Error fetching classes: ${classSnapshot.error}'));
            }

            if (classSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var classes = classSnapshot.data?.docs ?? [];
            if (classes.isEmpty) {
              return const Center(child: Text('You are not enrolled in any classes yet.'));
            }

            return ListView.builder(
              itemCount: classes.length,
              itemBuilder: (context, index) {
                var classData = classes[index].data() as Map<String, dynamic>;
                var className = classData['name'] ?? 'Unnamed Class';
                var classId = classes[index].id;

                return ExpansionTile(
                  title: Text(className),
                  children: [
                    _buildClassGrades(classId),
                    _buildClassAttendance(classId),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildClassGrades(String classId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('grades')
          .where('classId', isEqualTo: classId)
          .where('studentId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const ListTile(
            title: Text('No grades available yet.'),
          );
        }

        var grades = snapshot.data!.docs;

        return Column(
          children: [
            const Text('Grades', style: TextStyle(fontWeight: FontWeight.bold)),
            ...grades.map((grade) {
              var gradeData = grade.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(gradeData['assignmentName'] ?? 'Unknown Assignment'),
                subtitle: Text('Type: ${gradeData['type'] ?? 'Unknown Type'}'),
                trailing: Text(
                  '${gradeData['score'] ?? 0}/${gradeData['totalPossibleScore'] ?? 0}',
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildClassAttendance(String classId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('studentId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const ListTile(
            title: Text('No attendance records available.'),
          );
        }

        var attendanceRecords = snapshot.data!.docs;

        return Column(
          children: [
            const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
            ...attendanceRecords.map((attendance) {
              var attendanceData = attendance.data() as Map<String, dynamic>;
              var date = (attendanceData['date'] as Timestamp).toDate();
              var formattedDate = DateFormat.yMMMd().format(date);
              return ListTile(
                title: Text('Date: $formattedDate'),
                trailing: Text(attendanceData['status'] ?? 'Unknown'),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildAssignmentsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('assignments')
          .where('studentIds', arrayContains: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching assignments: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var assignments = snapshot.data?.docs ?? [];
        if (assignments.isEmpty) {
          return const Center(child: Text('No assignments found.'));
        }

        return ListView.builder(
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            var assignmentData = assignments[index].data() as Map<String, dynamic>;
            var assignmentName = assignmentData['name'] ?? 'Unnamed Assignment';
            var dueDate = (assignmentData['dueDate'] as Timestamp).toDate();
            var formattedDueDate = DateFormat.yMMMd().format(dueDate);

            return ListTile(
              title: Text(assignmentName),
              subtitle: Text('Due: $formattedDueDate'),
            );
          },
        );
      },
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolCode)
              .collection('notifications')
              .where('recipientIds', arrayContains: widget.userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to fetch notifications: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var notifications = snapshot.data?.docs ?? [];
            if (notifications.isEmpty) {
              return const Center(child: Text('No notifications found.'));
            }

            return AlertDialog(
              title: const Text('Notifications'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    var notificationData =
                    notifications[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(notificationData['title'] ?? 'No Title'),
                      subtitle: Text(notificationData['message'] ?? 'No Message'),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Example in Flutter using Firestore
Future<void> getStudentGradeAndAttendance(String schoolId, String classId, String studentId) async {
  try {
    // Get grade
    var gradeSnapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('grades')
        .where('classId', isEqualTo: classId)
        .where('studentId', isEqualTo: studentId)
        .get();

    // Check if grade exists, otherwise show 0%
    if (gradeSnapshot.docs.isEmpty) {
      if (kDebugMode) {
        print('Grade: 0%');
      } // Display default value
    } else {
      // Display the actual grade
      if (kDebugMode) {
        print('Grade: ${gradeSnapshot.docs[0]['score']}');
      }
    }

    // Get attendance
    var attendanceSnapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('studentId', isEqualTo: studentId)
        .get();

    // Check if attendance exists, otherwise show default
    if (attendanceSnapshot.docs.isEmpty) {
      if (kDebugMode) {
        print('Attendance: 0%');
      } // Display default value
    } else {
      // Display the actual attendance record
      if (kDebugMode) {
        print('Attendance: ${attendanceSnapshot.docs.length} days present');
      }
    }

  } catch (e) {
    if (kDebugMode) {
      print('Error: ${e.toString()}');
    }
  }
}
