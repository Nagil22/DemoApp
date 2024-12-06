import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/profile_screen.dart';
import '../dash_screens/payments_screen.dart';
import '../dash_screens/messaging_screen.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class ParentDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolCode;
  final String schoolName;

  const ParentDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolCode,
    required this.schoolName,
  });

  @override
  ParentDashboardScreenState createState() => ParentDashboardScreenState();
}

List<IconData> navIcons = [
  Icons.dashboard,
  Icons.family_restroom,  // Children section
  Icons.payment,
  Icons.person,
];

List<String> navTitle = [
  "Overview",
  "Children",
  "Payments",
  "Profile"
];

class ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _selectedIndex = 0;
  String? _selectedChildId;
  List<Map<String, dynamic>> _children = [];
  Color _accentColor = Colors.blue;
  int notificationCount = 0;
  bool _isLoading = true;
  late int _unreadMessageCount = 0;
  final String userType = 'parent';

  @override
  void initState() {
    super.initState();
    _fetchChildren();
    _listenToAccentColorChanges();
    _listenToNotifications();
    _listenToUnreadMessages();
  }

  Future<void> _fetchChildren() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final parentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!mounted) return;

      if (!parentDoc.exists) {
        throw Exception('Parent user document not found');
      }

      final parentData = parentDoc.data() as Map<String, dynamic>;
      final List<String> childrenIds = List<String>.from(
          parentData['childrenIds'] ?? []);

      final List<Map<String, dynamic>> children = [];
      for (String childId in childrenIds) {
        final childDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .get();

        if (childDoc.exists) {
          final childData = childDoc.data() as Map<String, dynamic>;
          childData['id'] = childId;
          children.add(childData);
        }
      }

      if (!mounted) return;

      setState(() {
        _children = children;
        if (_children.isNotEmpty) {
          _selectedChildId = _children[0]['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (kDebugMode) {
        print('Error fetching children: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching children data: $e')),
      );

      setState(() {
        _isLoading = false;
      });
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
        final accentColorHex = data['parentColor'] as String?;
        if (accentColorHex != null) {
          setState(() {
            _accentColor = Color(
                int.parse(accentColorHex.substring(1), radix: 16) + 0xFF000000);
          });
        }
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
    });
  }

  void _showNotificationsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery
                  .of(context)
                  .size
                  .width * 0.9,
              maxHeight: MediaQuery
                  .of(context)
                  .size
                  .height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Notifications',
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleLarge
                  ),
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
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Something went wrong');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final notifications = snapshot.data?.docs ?? [];

                      if (notifications.isEmpty) {
                        return const Center(child: Text('No notifications'));
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index]
                              .data() as Map<String, dynamic>;
                          final bool isRead = notification['read'] ?? false;

                          return ListTile(
                            title: Text(notification['title'] ?? 'No title'),
                            subtitle: Text(
                                notification['body'] ?? 'No content'),
                            trailing: !isRead ? TextButton(
                              onPressed: () => _markNotificationAsRead(
                                  notifications[index].id),
                              child: const Text('Mark as Read'),
                            ) : null,
                          );
                        },
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
      });

      if (!mounted) return;

      setState(() {
        notificationCount = notificationCount > 0 ? notificationCount - 1 : 0;
      });
    } catch (e) {
      if (!mounted) return;

      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notification as read: $e')),
      );
    }
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UniversalMessagingScreen(
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
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                          Icons.message, size: 20.0, color: Colors.white),
                      const SizedBox(width: 8.0),
                      Text(
                        'Messages ${_unreadMessageCount > 0
                            ? "($_unreadMessageCount)"
                            : ""}',
                        style: const TextStyle(
                            fontSize: 16.0,
                            color: Colors.white
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewChildGrades(String childId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Academic Performance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(widget.schoolCode)
                        .collection('grades')
                        .where('studentId', isEqualTo: childId)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final grades = snapshot.data?.docs ?? [];

                      if (grades.isEmpty) {
                        return const Center(
                          child: Text('No grades available'),
                        );
                      }

                      return ListView.separated(
                        itemCount: grades.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final grade = grades[index].data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(grade['subject'] ?? 'Unknown Subject'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Assessment: ${grade['assessmentName'] ?? 'N/A'}'),
                                Text('Date: ${DateFormat('MMM d, y').format((grade['timestamp'] as Timestamp).toDate())}'),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${grade['score']}/${grade['totalPossibleScore']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  grade['grade'] ?? 'N/A',
                                  style: TextStyle(
                                    color: _getGradeColor(grade['grade']),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Color _getGradeColor(String? grade) {
    if (grade == null) return Colors.grey;

    switch (grade.toUpperCase()) {
      case 'A':
      case 'A1':
      case 'A2':
        return Colors.green;
      case 'B':
      case 'B2':
      case 'B3':
        return Colors.blue;
      case 'C':
      case 'C4':
      case 'C5':
      case 'C6':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  void _viewChildAttendance(String childId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Attendance Records',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(widget.schoolCode)
                        .collection('attendance')
                        .where('studentId', isEqualTo: childId)
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final records = snapshot.data?.docs ?? [];

                      if (records.isEmpty) {
                        return const Center(
                          child: Text('No attendance records available'),
                        );
                      }

                      return ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index].data() as Map<String, dynamic>;
                          final date = (record['date'] as Timestamp).toDate();
                          final status = record['status'] as String;

                          return ListTile(
                            leading: Icon(
                              status == 'present' ? Icons.check_circle : Icons.cancel,
                              color: status == 'present' ? Colors.green : Colors.red,
                            ),
                            title: Text(DateFormat('EEEE, MMMM d, y').format(date)),
                            trailing: Text(
                              status.capitalize(),
                              style: TextStyle(
                                color: status == 'present' ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddChildDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Child'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your child\'s school email address to connect their account.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Child\'s School Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _sendChildConnectionRequest(emailController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendChildConnectionRequest(String childEmail) async {
    try {
      // First check if child exists
      final childQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: childEmail)
          .where('schoolCode', isEqualTo: widget.schoolCode)
          .get();

      if (childQuery.docs.isEmpty) {
        throw Exception('No student found with this email');
      }

      // Check if request already exists
      final existingRequest = await FirebaseFirestore.instance
          .collection('childRequests')
          .where('childEmail', isEqualTo: childEmail)
          .where('parentId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('A connection request is already pending');
      }

      // Create the connection request
      await FirebaseFirestore.instance.collection('childRequests').add({
        'parentId': widget.userId,
        'parentName': widget.username,
        'childEmail': childEmail,
        'schoolCode': widget.schoolCode,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request sent successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
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
          title: Text('Welcome, ${widget.username}'),
          backgroundColor: _accentColor,
          actions: [
            _buildNotificationIcon(),
            _buildMessageIcon(),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
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
          icon: const Icon(Icons.notifications),
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

  Widget _buildMessageIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.message),
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

  Widget _navBar() {
    return Container(
      height: 65,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(
          navIcons.length,
              (index) => _buildNavItem(index),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            navIcons[index],
            color: isSelected ? _accentColor : Colors.grey,
          ),
          Text(
            navTitle[index],
            style: TextStyle(
              color: isSelected ? _accentColor : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getSelectedSection() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewSection();
      case 1:
        return _buildChildrenSection();
      case 2:
        return PaymentsScreen(
            userId: _selectedChildId ?? '',
            schoolCode: widget.schoolCode
        );
      case 3:
        return ProfileScreen(
          userId: widget.userId,
          username: widget.username,
          email: '',
          userType: 'parent',
          accentColor: _accentColor,
        );
      default:
        return _buildOverviewSection();
    }
  }

  Widget _buildOverviewSection() {
    if (_children.isEmpty) {
      return _buildNoChildrenView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChildSelector(),
          const SizedBox(height: 20),
          if (_selectedChildId != null) ...[
            _buildAcademicOverview(),
            const SizedBox(height: 20),
            _buildAttendanceOverview(),
            const SizedBox(height: 20),
            _buildRecentActivities(),
          ],
        ],
      ),
    );
  }


  Widget _buildChildSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Child',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedChildId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
              ),
              items: _children.map((child) {
                return DropdownMenuItem<String>(
                  value: child['id'],
                  child: Text(child['name'] ?? 'Unknown'),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedChildId = newValue;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicOverview() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('academic_records')
          .doc(_selectedChildId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Error loading academic data'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final academicData = snapshot.data?.data() as Map<String, dynamic>? ??
            {};

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Academic Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAcademicStat(
                      'Overall Average',
                      '${(academicData['overallAverage'] ?? 0).toStringAsFixed(
                          1)}%',
                      Icons.grade,
                    ),
                    _buildAcademicStat(
                      'Subjects',
                      '${academicData['totalSubjects'] ?? 0}',
                      Icons.subject,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('attendance')
          .where('studentId', isEqualTo: _selectedChildId)
          .orderBy('date', descending: true)
          .limit(30) // Last 30 days
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Error loading attendance data'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final attendanceRecords = snapshot.data?.docs ?? [];
        final totalDays = attendanceRecords.length;
        final presentDays = attendanceRecords
            .where((doc) =>
        (doc.data() as Map<String, dynamic>)['status'] == 'present')
            .length;
        final attendanceRate = totalDays > 0
            ? (presentDays / totalDays) * 100
            : 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAcademicStat(
                      'Present Days',
                      '$presentDays/$totalDays',
                      Icons.calendar_today,
                    ),
                    _buildAcademicStat(
                      'Attendance Rate',
                      '${attendanceRate.toStringAsFixed(1)}%',
                      Icons.timeline,
                    ),
                  ],
                ),
                if (attendanceRecords.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Recent Attendance:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...attendanceRecords.take(5).map((record) {
                    final data = record.data() as Map<String, dynamic>;
                    final status = data['status'] as String;
                    final date = (data['date'] as Timestamp).toDate();
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        status == 'present' ? Icons.check_circle : Icons.cancel,
                        color: status == 'present' ? Colors.green : Colors.red,
                      ),
                      title: Text(DateFormat('MMM d, y').format(date)),
                      trailing: Text(
                        status.capitalize(),
                        style: TextStyle(
                          color: status == 'present' ? Colors.green : Colors
                              .red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivities() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('activities')
          .where('studentId', isEqualTo: _selectedChildId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final activities = snapshot.data?.docs ?? [];
        if (activities.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Activities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...activities.map((activity) {
                  final data = activity.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(_getActivityIcon(data['type'])),
                    title: Text(data['title'] ?? 'Unknown Activity'),
                    subtitle: Text(
                      DateFormat('MMM d, y h:mm a').format(
                        (data['timestamp'] as Timestamp).toDate(),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAcademicStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: _accentColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'grade':
        return Icons.grade;
      case 'attendance':
        return Icons.calendar_today;
      case 'assignment':
        return Icons.assignment;
      case 'exam':
        return Icons.school;
      default:
        return Icons.event_note;
    }
  }

  Widget _buildChildrenSection() {
    if (_children.isEmpty) {
      return _buildNoChildrenView();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _children.length,
      itemBuilder: (context, index) {
        final child = _children[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(child['name'] ?? 'Unknown'),
            subtitle: Text('Class: ${child['class'] ?? 'Not specified'}'),
            leading: CircleAvatar(
              backgroundColor: _accentColor,
              child: Text(
                (child['name'] as String? ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            children: [
              _buildChildDetails(child),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoChildrenView() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 64,
              color: _accentColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Children Associated',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your children to start monitoring their academic progress',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddChildDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Child'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildDetails(Map<String, dynamic> child) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Email:', child['email'] ?? 'Not specified'),
          _buildDetailRow('Registration No:',
              child['registrationNumber'] ?? 'Not specified'),
          _buildDetailRow('Class:', child['class'] ?? 'Not specified'),
          _buildDetailRow('Status:', child['status'] ?? 'Active'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () => _viewChildGrades(child['id']),
                icon: const Icon(Icons.grade),
                label: const Text('View Grades'),
              ),
              OutlinedButton.icon(
                onPressed: () => _viewChildAttendance(child['id']),
                icon: const Icon(Icons.calendar_today),
                label: const Text('View Attendance'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120, // Fixed width container instead of style property
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
