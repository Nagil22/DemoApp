import 'package:demo/school/service/student_ops.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/profile_screen.dart';
import '../dash_screens/payments_screen.dart';
import '../dash_screens/messaging_screen.dart';
import 'grade_calculator.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolCode;
  final String schoolName;
  final String schoolType;

  const StudentDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolCode,
    required this.schoolName,
    required this.schoolType,
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
  late final StudentOperations _studentOps;
  Map<String, dynamic>? _academicRecord;
  List<Map<String, dynamic>>? _pendingAssignments;
  bool _isLoading = true;
  String? _currentSemester;


  @override
  void initState() {
    super.initState();
    _studentOps = StudentOperations();
    _initializeStudentData();
    _listenToAcademicUpdates();

    // Keep your existing initState calls
    if (widget.schoolType == 'primary') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPrimaryAccessRestriction();
      });
    } else {
      _listenToAccentColorChanges();
      _listenToNotifications();
      _verifyUserData();
      _fetchUserEmail();
      _listenToUnreadMessages();
    }
  }



  Future<void> _initializeStudentData() async {
    try {
      // Get academic record
      final academicRecord = await _studentOps.getAcademicRecord(
        schoolId: widget.schoolCode,
        studentId: widget.userId,
        schoolType: widget.schoolType,
      );

      // Get current semester/term
      _currentSemester = await _getCurrentAcademicPeriod();

      // Get pending assignments
      final assignments = await _studentOps.getPendingAssignments(
        schoolId: widget.schoolCode,
        studentId: widget.userId,
      );

      if (mounted) {
        setState(() {
          _academicRecord = academicRecord;
          _pendingAssignments = assignments;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing student data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _getCurrentAcademicPeriod() async {
    try {
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .get();

      final academicPeriod = schoolDoc.data()?['academicPeriod'] ?? {};
      return academicPeriod['current'] ??
          (widget.schoolType == 'university' ? 'First Semester' : 'First Term');
    } catch (e) {
      debugPrint('Error getting academic period: $e');
      return widget.schoolType == 'university' ? 'First Semester' : 'First Term';
    }
  }
  void _listenToAcademicUpdates() {
    // Listen for academic record changes
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('academic_records')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() => _academicRecord = snapshot.data());
      }
    });

    // Listen for new assignments
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('assignments')
        .where('studentIds', arrayContains: widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final now = DateTime.now();
        final pending = snapshot.docs
            .where((doc) => (doc.data()['dueDate'] as Timestamp)
            .toDate()
            .isAfter(now))
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        setState(() => _pendingAssignments = pending);
      }
    });
  }

  // University-specific course registration
  Future<void> _handleCourseRegistration(List<String> selectedCourseIds) async {
    if (widget.schoolType != 'university') return;

    try {
      await _studentOps.registerForCourses(
        schoolId: widget.schoolCode,
        studentId: widget.userId,
        courseIds: selectedCourseIds,
        semester: _currentSemester!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course registration successful')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    }
  }

  // Assignment submission handling
  Future<void> _submitAssignment(String assignmentId, Map<String, dynamic> submission) async {
    try {
      await _studentOps.submitAssignment(
        schoolId: widget.schoolCode,
        studentId: widget.userId,
        assignmentId: assignmentId,
        submission: submission,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    }
  }

  // Parent connection handling
  Future<void> _handleParentRequest(String requestId, String parentId, String action) async {
    try {
      await _studentOps.handleParentRequest(
        requestId: requestId,
        action: action,
        studentId: widget.userId,
        parentId: parentId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parent request ${action}ed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error handling request: $e')),
        );
      }
    }
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

  // Add these methods to your StudentDashboardScreenState class

  Widget _buildSecondaryAcademicSummary() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .doc(widget.schoolCode)
                  .collection('grades')
                  .where('studentId', isEqualTo: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                var grades = snapshot.data!.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList();

                var gradeCalculation = GradeCalculator.calculateGrade('secondary', grades);

                return Column(
                  children: [
                    _buildSummaryTile(
                      'Overall Average',
                      (gradeCalculation['average'] as double).toStringAsFixed(1),
                      Icons.grade,
                    ),
                    _buildSummaryTile(
                      'Subjects',
                      gradeCalculation['totalSubjects'].toString(),
                      Icons.book,
                    ),

                    _buildSummaryTile(
                      'Attendance Rate',
                      '${_calculateAttendanceRate()}%',
                      Icons.calendar_today,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniversityAcademicSummary() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .doc(widget.schoolCode)
                  .collection('grades')
                  .where('studentId', isEqualTo: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                var grades = snapshot.data!.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList();

                var gradeCalculation = GradeCalculator.calculateGrade('university', grades);

                return Column(
                  children: [
                    _buildSummaryTile(
                      'Current GPA',
                      (gradeCalculation['gpa'] as double).toStringAsFixed(2),
                      Icons.school,
                    ),
                    _buildSummaryTile(
                      'Credits Completed',
                      gradeCalculation['totalCredits'].toString(),
                      Icons.credit_card,
                    ),
                    _buildSummaryTile(
                      'Quality Points',
                      gradeCalculation['qualityPoints'].toString(),
                      Icons.grade,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseDetails(Map<String, dynamic> classData) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Course: ${classData['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Code: ${classData['code'] ?? 'N/A'}'),
            Text('Credits: ${classData['credits'] ?? 'N/A'}'),
            Text('Instructor: ${classData['teacherName'] ?? 'N/A'}'),
            if (classData['prerequisites'] != null)
              Text('Prerequisites: ${classData['prerequisites']}'),
            if (classData['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Description: ${classData['description']}'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamSchedule(String classId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('classes')
          .doc(classId)
          .collection('exams')
          .where('date', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var exams = snapshot.data!.docs;
        if (exams.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No upcoming exams'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Upcoming Exams',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exams.length,
              itemBuilder: (context, index) {
                var exam = exams[index].data() as Map<String, dynamic>;
                var examDate = (exam['date'] as Timestamp).toDate();

                return ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(exam['title'] ?? 'Untitled Exam'),
                  subtitle: Text(
                    'Date: ${DateFormat('MMM dd, yyyy').format(examDate)}\n'
                        'Time: ${DateFormat('hh:mm a').format(examDate)}',
                  ),
                  trailing: Text(
                    exam['type'] ?? 'Exam',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: _accentColor),
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  double _calculateAttendanceRate() {
    // Implement attendance rate calculation
    return 0.0; // Placeholder return
  }



  @override
  Widget build(BuildContext context) {
    if (widget.schoolType == 'primary') {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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

  void _showPrimaryAccessRestriction() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Access Restricted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Primary school students do not have direct access to the dashboard.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please ask your parent to access your academic information.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Return to login
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSubmissionDialog(String assignmentId) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Make sure to review your submission before submitting.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _submitAssignment(assignmentId, {
                  'notes': textController.text,
                  'submittedAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assignment submitted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error submitting assignment: $e')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
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
    if (widget.schoolType == 'primary') {
      return const Center(
        child: Text('Primary school students do not have direct access.'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Academic Summary Card
          if (_academicRecord != null)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Academic Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (widget.schoolType == 'university') ...[
                      Text('Credits Earned: ${_academicRecord!['totalCredits'] ?? 0}'),
                      Text('Current GPA: ${(_academicRecord!['gpa'] ?? 0.0).toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      Text('Semester: $_currentSemester'),
                    ] else ...[
                      Text('Current Average: ${(_academicRecord!['overallAverage'] ?? 0.0).toStringAsFixed(2)}%'),
                    ],
                    Text('Status: ${_academicRecord!['academicStatus'] ?? 'Active'}'),
                  ],
                ),
              ),
            ),

          // Registration Button for University Students
          if (widget.schoolType == 'university')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                onPressed: () async {
                  List<String> selectedCourseIds = []; // You'll need to implement course selection
                  await _handleCourseRegistration(selectedCourseIds);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: const Text('Course Registration',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Detailed Academic Summary
          if (widget.schoolType == 'university')
            _buildUniversityAcademicSummary()
          else if (widget.schoolType == 'secondary')
            _buildSecondaryAcademicSummary(),

          const SizedBox(height: 16),

          // Current Classes Section
          _buildCurrentClasses(),

          const SizedBox(height: 16),

          // Pending Assignments Section
          if (_pendingAssignments != null && _pendingAssignments!.isNotEmpty)
            _buildPendingAssignments(),
        ],
      ),
    );
  }

    Widget _buildAcademicSummary() {
      switch (widget.schoolType) {
        case 'secondary':
          return _buildSecondaryAcademicSummary();
        case 'university':
          return _buildUniversityAcademicSummary();
        default:
          return const SizedBox.shrink();
      }
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingAssignments != null) {
      if (_pendingAssignments!.isEmpty) {
        return const Center(child: Text('No pending assignments'));
      }

      return ListView.builder(
        itemCount: _pendingAssignments!.length,
        itemBuilder: (context, index) {
          final assignment = _pendingAssignments![index];
          return _buildAssignmentCard(assignment);
        },
      );
    }

    return const Center(child: Text('No pending assignments'));
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final dueDate = (assignment['dueDate'] as Timestamp).toDate();
    final isOverdue = dueDate.isBefore(DateTime.now());
    final bool isSubmitted = assignment['submitted'] ?? false;

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
            Text(
              isSubmitted ? 'Status: Submitted' : 'Status: Pending',
              style: TextStyle(
                color: isSubmitted ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        trailing: !isSubmitted ? TextButton(
          onPressed: () => _showSubmissionDialog(assignment['id']),
          child: const Text('Submit'),
        ) : const Icon(Icons.check_circle, color: Colors.green),
      ),
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
                                          onPressed: () => _handleParentRequest(doc.id, data['parentId'], 'accept'),
                                        ),
                                        TextButton(
                                          child: const Text('Decline'),
                                          onPressed: () => _handleParentRequest(doc.id, data['parentId'], 'reject'),
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
  Widget _buildCurrentClasses() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('classes')
          .where('studentIds', arrayContains: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final classes = snapshot.data?.docs ?? [];
        if (classes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No classes found'),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAcademicSummary(), // Now properly referenced
              const SizedBox(height: 16),
              const Text(
                'Current Classes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...classes.map((classDoc) {
                final classData = classDoc.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ExpansionTile(
                    title: Text(classData['name'] ?? 'Unnamed Class'),
                    subtitle: Text(classData['subject'] ?? 'No subject'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.schoolType == 'university')
                              _buildCourseDetails(classData), // Now properly referenced
                            _buildClassGrades(classDoc.id),
                            const SizedBox(height: 16),
                            _buildClassAttendance(classDoc.id),
                            const SizedBox(height: 16),
                            if (widget.schoolType != 'primary')
                              _buildExamSchedule(classDoc.id), // Now properly referenced
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingAssignments() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Assignments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingAssignments!.length,
            itemBuilder: (context, index) {
              final assignment = _pendingAssignments![index];
              return _buildAssignmentCard(assignment);
            },
          ),
        ],
      ),
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
