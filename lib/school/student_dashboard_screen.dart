import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/profile_screen.dart';
import '../dash_screens/payments_screen.dart';
import '../dash_screens/messaging_screen.dart';

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
  String? _userEmail;
  late int _unreadMessageCount = 0;
  final String userType = 'student';


  @override
  void initState() {
    super.initState();
    _listenToAccentColorChanges();
    _listenToNotifications();
    _verifyUserData();
    _fetchUserEmail();
    _listenToUnreadMessages();
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
            _accentColor = Color(int.parse(accentColorHex.substring(1), radix: 16) + 0xFF000000);
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
            .where((doc) {
          var readMap = doc.data()['read'] as Map<String, dynamic>? ?? {};
          return !(readMap[widget.userId] ?? false);
        })
            .length;
      });
    }, onError: (error) {
      if (kDebugMode) {
        print('Error listening to notifications: $error');
      }
      // Handle error silently
    });
  }

  void _markNotificationAsRead(String notificationId) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true}).then((_) {
      // Update the local notification count
      setState(() {
        notificationCount = notificationCount > 0 ? notificationCount - 1 : 0;
      });
    }).catchError((error) {
      if (kDebugMode) {
        print("Error marking notification as read: $error");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notification as read: $error')),
      );
    });
  }


  void _listenToUnreadMessages() {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('messages')
        .where('recipientId', isEqualTo: widget.userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _unreadMessageCount = snapshot.docs.length;
      });
    }, onError: (error) {
      if (kDebugMode) {
        print('Error listening to messages: $error');
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


  void _fetchUserEmail() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userEmail = userData['email'] as String?;
        });
        if (_userEmail != null) {
          _listenToParentRequests();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user email: $e');
      }
    }
  }


  Future<void> acceptParentRequest(String requestId, String parentId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get the request document reference
        final requestRef = FirebaseFirestore.instance
            .collection('childRequests')
            .doc(requestId);

        // Get the current user document reference
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId);

        // Get the current user data to check existing parentIds
        DocumentSnapshot userDoc = await transaction.get(userRef);
        List<String> currentParentIds = List<String>.from(userDoc.get('parentIds') ?? []);

        // Only add the parent if not already in the list
        if (!currentParentIds.contains(parentId)) {
          currentParentIds.add(parentId);
        }

        // Update both documents in the transaction
        transaction.update(requestRef, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(userRef, {
          'parentIds': currentParentIds,
        });
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parent request accepted successfully')),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error accepting parent request: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}');
          print('Firebase error message: ${e.message}');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting request: ${e.toString()}')),
      );
    }
  }

// Add this cleanup method to call when needed
  Future<void> cleanupUserConnections() async {
    try {
      // Sign out the user
      await FirebaseAuth.instance.signOut();

      // Clear Firestore cache
      await FirebaseFirestore.instance.clearPersistence();

      // Navigate to login screen or restart app
      // Add your navigation logic here

    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up user connections: $e');
      }
    }
  }

  void _listenToParentRequests() {
    if (_userEmail != null) {
      FirebaseFirestore.instance
          .collection('childRequests')
          .where('childEmail', isEqualTo: _userEmail)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        // Handle parent requests
      }, onError: (error) {
        if (kDebugMode) {
          print('Error listening to parent requests: $error');
        }
      });
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
                  fontSize: 20,
                  color: Colors.white
              )
          ),
          backgroundColor: _accentColor,
          actions: [
            _buildNotificationIcon(),
            _buildMessageIcon(),
          ],
        ),
        body: Stack(
            children: [
              _getSelectedSection(),
              Align(
                  alignment: Alignment.bottomCenter,
                  child: _navBar()
              )
            ]
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
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
    );
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
        return PaymentsScreen(userId: widget.userId, schoolCode: widget.schoolCode);
      case 3:
        return ProfileScreen(
          userId: widget.userId,
          username: widget.username,
          email: _userEmail ?? '',
          userType: 'student',
          accentColor: _accentColor,
        );
      default:
        return _buildOverviewSection();
    }
  }

  Widget _buildMessageIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.message, color: Colors.white),
          onPressed: _showCommunicationHubDialog,
        ),
        if (_unreadMessageCount > 0)
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
                '$_unreadMessageCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }


  void _showCommunicationHubDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Communication Hub',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => UniversalMessagingScreen(
                          userId: widget.userId,
                          schoolId: widget.schoolCode,
                          userType: userType,
                          username: widget.username,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.message, size: 20.0),
                      const SizedBox(width: 8.0),
                      Text(
                        'Messages ${_unreadMessageCount > 0 ? "($_unreadMessageCount unread)" : "(0 unread)"}',
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          return Center(
              child: Text('Error fetching school: ${schoolSnapshot.error}'));
        }

        if (schoolSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var schoolDocs = schoolSnapshot.data?.docs ?? [];
        if (schoolDocs.isEmpty) {
          return const Center(
              child: Text('No school found with the given school code.'));
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
              return Center(child: Text(
                  'Error fetching classes: ${classSnapshot.error}'));
            }

            if (classSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var classes = classSnapshot.data?.docs ?? [];
            if (classes.isEmpty) {
              return const Center(
                  child: Text('You are not enrolled in any classes yet.'));
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
                title: Text(
                    gradeData['assignmentName'] ?? 'Unknown Assignment'),
                subtitle: Text('Type: ${gradeData['type'] ?? 'Unknown Type'}'),
                trailing: Text(
                  '${gradeData['score'] ??
                      0}/${gradeData['totalPossibleScore'] ?? 0}',
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
            const Text(
                'Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
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
          .orderBy('dueDate')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var assignments = snapshot.data?.docs ?? [];
        if (assignments.isEmpty) {
          return const Center(child: Text('No assignments found'));
        }

        return ListView.builder(
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            var assignment = assignments[index].data() as Map<String, dynamic>;
            var dueDate = (assignment['dueDate'] as Timestamp).toDate();
            var isOverdue = dueDate.isBefore(DateTime.now());

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: ListTile(
                leading: Icon(
                  isOverdue ? Icons.warning : Icons.assignment,
                  color: isOverdue ? Colors.red : Colors.grey,
                ),
                title: Text(assignment['name'] ?? 'Unnamed Assignment'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Due: ${DateFormat.yMMMd().add_jm().format(dueDate)}'),
                    if (assignment['description'] != null)
                      Text(
                        assignment['description'],
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (assignment['type'] != null)
                      Text(
                        'Type: ${assignment['type']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                trailing: assignment['submitted'] == true
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : isOverdue
                    ? const Text('Overdue', style: TextStyle(color: Colors.red))
                    : const Text('Pending'),
              ),
            );
          },
        );
      },
    );
  }
// Update notifications dialog to include parent requests
  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
                ),
                Flexible(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(widget.schoolCode)
                        .collection('notifications')
                        .where('recipientIds', arrayContains: widget.userId)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, notificationSnapshot) {
                      if (notificationSnapshot.hasError) {
                        return const Text('Something went wrong');
                      }

                      if (notificationSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Add parent requests stream
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('childRequests')
                            .where('childEmail', isEqualTo: _userEmail)
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, requestSnapshot) {
                          List<Widget> notificationItems = [];

                          // Add parent requests
                          if (requestSnapshot.hasData && requestSnapshot.data!.docs.isNotEmpty) {
                            notificationItems.addAll(
                              requestSnapshot.data!.docs.map((doc) {
                                var data = doc.data() as Map<String, dynamic>;
                                return Card(
                                  margin: const EdgeInsets.all(8.0),
                                  child: ListTile(
                                    leading: const Icon(Icons.family_restroom),
                                    title: const Text('Parent Connection Request'),
                                    subtitle: Text('From: ${data['parentId']}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          child: const Text('Accept'),
                                          onPressed: () => acceptParentRequest(doc.id, data['parentId']),
                                        ),
                                        TextButton(
                                          child: const Text('Decline'),
                                          onPressed: () {
                                            // Implement decline functionality
                                            FirebaseFirestore.instance
                                                .collection('childRequests')
                                                .doc(doc.id)
                                                .update({'status': 'rejected'});
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            );
                          }

                          // Add regular notifications
                          notificationItems.addAll(
                            notificationSnapshot.data!.docs.map((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              return Card(
                                margin: const EdgeInsets.all(8.0),
                                child: ListTile(
                                  title: Text(data['title'] ?? 'No title'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['body'] ?? 'No content'),
                                      Text(
                                        DateFormat('MMM d, y HH:mm')
                                            .format((data['timestamp'] as Timestamp).toDate()),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  trailing: data['read'] == false
                                      ? TextButton(
                                    onPressed: () => _markNotificationAsRead(doc.id),
                                    child: const Text('Mark as Read'),
                                  )
                                      : null,
                                ),
                              );
                            }),
                          );

                          return ListView(
                            shrinkWrap: true,
                            children: notificationItems,
                          );
                        },
                      );
                    },
                  ),
                ),
                TextButton(
                  child: const Text('Close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
// Example in Flutter using Firestore
  Future<void> getStudentGradeAndAttendance(String schoolId, String classId,
      String studentId) async {
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
}
