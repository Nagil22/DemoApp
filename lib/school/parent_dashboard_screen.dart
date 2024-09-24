import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/profile_screen.dart';
import '../dash_screens/payments_screen.dart';

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

class ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _selectedIndex = 0;
  List<String> _childrenIds = [];
  String? _selectedChildId;
  Color _accentColor = Colors.blue;
  int notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchChildrenIds();
    _listenToAccentColorChanges();
    _listenToNotifications();
  }

  // Fetches the list of children IDs associated with the parent

  Future<void> _fetchChildrenIds() async {
    // Fetch the list of children IDs for the current parent user
    Map<String, dynamic> userData = await _getUserData();
    setState(() {
      _childrenIds = List<String>.from(userData['childrenIds'] ?? []);
    });
  }

  // Listens to changes in the school's accent color
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
            _accentColor = Color(int.parse(accentColorHex.substring(1), radix: 16) + 0xFF000000);
          });
        }
      }
    });
  }

  // Listens to unread notifications for the parent
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
        body: _getSelectedSection(),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
            BottomNavigationBarItem(icon: Icon(Icons.grade), label: 'Grades'),
            BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: _accentColor,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  // Handles bottom navigation item taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Returns the widget corresponding to the selected section
  Widget _getSelectedSection() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewSection();
      case 1:
        return _buildGradesSection();
      case 2:
        return PaymentsScreen(userId: _selectedChildId ?? '', schoolCode: widget.schoolCode);
      case 3:
        return ProfileScreen(
          userId: widget.userId,
          username: widget.username,
          email: '', // Ensure this gets passed correctly
          userType: 'parent',
          accentColor: _accentColor,
        );
      default:
        return _buildOverviewSection();
    }
  }

  // Builds the Overview section with child selector and actions
  Widget _buildOverviewSection() {
    return Column(
      children: [
        _buildChildSelector(),
        ElevatedButton(
          onPressed: _showAddChildDialog,
          child: const Text('Add Child'),
        ),
        if (_selectedChildId != null)
          ElevatedButton(
            onPressed: _showSubmitAbsenteeForm,
            child: const Text('Submit Absentee Form'),
          ),
      ],
    );
  }

  // Builds the child selector dropdown
  Widget _buildChildSelector() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButton<String>(
        value: _selectedChildId,
        hint: const Text('Select a child'),
        isExpanded: true,
        items: _childrenIds.map((String childId) {
          return DropdownMenuItem<String>(
            value: childId,
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(childId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Loading...');
                }
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const Text('Error');
                }
                var childData = snapshot.data!.data() as Map<String, dynamic>?;
                return Text(childData?['name'] ?? 'Unknown');
              },
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedChildId = newValue;
          });
        },
      ),
    );
  }

  // Shows a dialog to add a child by email
  void _showAddChildDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Child'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(hintText: "Enter child's email"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Send Request'),
              onPressed: () {
                final childEmail = emailController.text.trim();
                if (childEmail.isNotEmpty && _validateEmail(childEmail)) {
                  _sendChildRequest(childEmail);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email')),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendChildRequest(String childEmail) async {
    try {
      // Get the current user's data
      Map<String, dynamic> userData = await _getUserData();

      // Check if the current user is a parent
      if (userData['role'] != 'parent') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be a parent to send a child request')),
        );
        return;
      }

      // Check if the child user already exists
      QuerySnapshot childSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: childEmail)
          .limit(1)
          .get();

      if (childSnapshot.docs.isEmpty) {
        // Child user doesn't exist, show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Child user with email $childEmail not found')),
        );
        return;
      }

      // Get the child user's ID
      String childUserId = childSnapshot.docs.first.id;

      // Create a new document in the 'childRequests' subcollection
      DocumentReference parentUserDoc = FirebaseFirestore.instance.collection('users').doc(userData['uid']);
      await parentUserDoc.collection('childRequests').add({
        'parentId': userData['uid'],
        'childId': childUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Refresh the child selector dropdown
      _fetchChildrenIds();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent to child')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending child request: $e')),
      );
    }
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  Future<Map<String, dynamic>> _getUserData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userSnapshot.data() as Map<String, dynamic>;
    } else {
      return {};
    }
  }
  // Shows a dialog to submit an absentee form
  void _showSubmitAbsenteeForm() {
    final TextEditingController reasonController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Submit Absentee Form'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(hintText: "Reason for absence"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        startDate = picked;
                      });
                      // Update the dialog with the selected date
                      Navigator.of(context).pop();
                      _showSubmitAbsenteeFormWithDates(reasonController.text, picked, endDate);
                    }
                  },
                  child: Text(startDate == null
                      ? 'Select Start Date'
                      : 'Start Date: ${DateFormat('yyyy-MM-dd').format(startDate!)}'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: endDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        endDate = picked;
                      });
                      // Update the dialog with the selected date
                      Navigator.of(context).pop();
                      _showSubmitAbsenteeFormWithDates(reasonController.text, startDate, picked);
                    }
                  },
                  child: Text(endDate == null
                      ? 'Select End Date'
                      : 'End Date: ${DateFormat('yyyy-MM-dd').format(endDate!)}'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Shows the absentee form with selected dates
  void _showSubmitAbsenteeFormWithDates(String reason, DateTime? start, DateTime? end) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Submit Absentee Form'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reason: $reason'),
              Text('Start Date: ${start != null ? DateFormat('yyyy-MM-dd').format(start) : 'Not selected'}'),
              Text('End Date: ${end != null ? DateFormat('yyyy-MM-dd').format(end) : 'Not selected'}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                _submitAbsenteeForm(reason, start, end);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Submits the absentee form to Firestore
  void _submitAbsenteeForm(String reason, DateTime? startDate, DateTime? endDate) async {
    if (_selectedChildId == null || startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      // Get all classes for the selected child
      var classesSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('classes')
          .where('studentIds', arrayContains: _selectedChildId)
          .get();

      if (classesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No classes found for the selected child')),
        );
        return;
      }

      // For each class, create an absentee record
      for (var classDoc in classesSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolCode)
            .collection('absenteeRecords')
            .add({
          'studentId': _selectedChildId,
          'classId': classDoc.id,
          'reason': reason,
          'startDate': startDate,
          'endDate': endDate,
          'status': 'pending',
          'submittedBy': widget.userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Absentee form submitted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting absentee form: $e')),
      );
    }
  }

  // Builds the Grades section using StreamBuilder
  Widget _buildGradesSection() {
    if (_selectedChildId == null) {
      return const Center(child: Text('Please select a child to view grades'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('grades')
          .where('studentId', isEqualTo: _selectedChildId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var grades = snapshot.data!.docs;
        if (grades.isEmpty) {
          return const Center(child: Text('No grades available.'));
        }
        return ListView.builder(
          itemCount: grades.length,
          itemBuilder: (context, index) {
            var grade = grades[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(grade['assignmentName'] ?? 'Unknown Assignment'),
              subtitle: Text('Grade: ${grade['score']}/${grade['totalPossibleScore']}'),
              trailing: Text('Date: ${DateFormat('yyyy-MM-dd').format((grade['date'] as Timestamp).toDate())}'),
            );
          },
        );
      },
    );
  }

  // Shows a dialog with the list of notifications
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
              .orderBy('timestamp', descending: true)
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
              return const AlertDialog(
                title: Text('Loading'),
                content: Center(child: CircularProgressIndicator()),
              );
            }

            var notifications = snapshot.data?.docs ?? [];

            if (notifications.isEmpty) {
              return AlertDialog(
                title: const Text('Notifications'),
                content: const Text('No notifications available.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Notifications'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    var notification = notifications[index].data() as Map<String, dynamic>;
                    bool isRead = false;
                    if (notification['read'] != null && notification['read'] is Map) {
                      var readMap = notification['read'] as Map<String, dynamic>;
                      isRead = readMap[widget.userId] ?? false;
                    }

                    return ListTile(
                      title: Text(notification['title'] ?? 'No title'),
                      subtitle: Text(notification['body'] ?? 'No content'),
                      trailing: Text(
                        notification['timestamp'] != null
                            ? DateFormat('yyyy-MM-dd').format((notification['timestamp'] as Timestamp).toDate())
                            : 'No date',
                      ),
                      leading: Icon(
                        isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                        color: isRead ? Colors.grey : Colors.blue,
                      ),
                      onTap: () {
                        if (!isRead) {
                          _markNotificationAsRead(notifications[index].id);
                        }
                      },
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

  // Marks a notification as read
  void _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': {
          widget.userId: true,
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notification as read: $e')),
      );
    }
  }
}

extension on QuerySnapshot<Map<String, dynamic>> {
}
