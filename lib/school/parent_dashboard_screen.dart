import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/profile_screen.dart';
import '../dash_screens/payments_screen.dart';
import '../dash_screens/messaging_screen.dart';

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
  Icons.grade,
  Icons.payment,
  Icons.person,
];
List<String> navTitle = [
  "Overview",
  "Grades",
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

  // Fetches the list of children IDs associated with the parent

  Future<void> _fetchChildren() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First get the parent's user document to get childrenIds
      DocumentSnapshot parentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!parentDoc.exists) {
        throw Exception('Parent user document not found');
      }

      var parentData = parentDoc.data() as Map<String, dynamic>;
      List<String> childrenIds = List<String>.from(
          parentData['childrenIds'] ?? []);

      // Fetch each child's data
      List<Map<String, dynamic>> children = [];
      for (String childId in childrenIds) {
        DocumentSnapshot childDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .get();

        if (childDoc.exists) {
          var childData = childDoc.data() as Map<String, dynamic>;
          childData['id'] = childId;
          children.add(childData);
        }
      }

      setState(() {
        _children = children;
        if (_children.isNotEmpty) {
          _selectedChildId = _children[0]['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
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
            _accentColor = Color(
                int.parse(accentColorHex.substring(1), radix: 16) + 0xFF000000);
          });
        }
      }
    });
  }

  // Listens to unread notifications for the parent
  void _listenToNotifications() {
    if (!mounted) return;

    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('notifications')
        .where('recipientIds', arrayContains: widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        notificationCount = snapshot.docs
            .where((doc) {
          var readMap = doc.data()['read'] as Map<String, dynamic>? ?? {};
          return !(readMap[widget.userId] ?? false);
        })
            .length;
      });
    }, onError: (error) {
      if (kDebugMode && mounted) {
        if (kDebugMode) {
          print('Error fetching notifications: $error');
        }
      }
    }, cancelOnError: true);
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


  void _listenToUnreadMessages() {
    if (!mounted) return;

    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('messages')
        .where('recipientId', isEqualTo: widget.userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _unreadMessageCount = snapshot.docs.length;
      });
    }, onError: (error) {
      if (kDebugMode && mounted) {
        if (kDebugMode) {
          print('Error listening to messages: $error');
        }
      }
    }, cancelOnError: true);
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
            // Existing notification icon
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
            // New Communication Hub icon
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.message, color: Colors.black),
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
            ),
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
        return _children.isEmpty
            ? Center(child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ Text(
            'No children associated with this account. Please add a child to view grades.',   textAlign: TextAlign.center,),
            ]
            )
        )
        )
            : _buildGradesSection();
      case 2:
        return _children.isEmpty
            ? Center(child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ Text(
                  'No children associated with this account. Please add a child to view grades.',   textAlign: TextAlign.center,),
                ]
            )
        )
        )
            : PaymentsScreen(
            userId: _selectedChildId ?? '', schoolCode: widget.schoolCode);
      case 3:
        return ProfileScreen(
          userId: widget.userId,
          username: widget.username,
          email: '',
          // Ensure this gets passed correctly
          userType: 'parent',
          accentColor: _accentColor,
        );
      default:
        return _buildOverviewSection();
    }
  }

  // Builds the Overview section with child selector and actions
  Widget _buildOverviewSection() {
    final theme = Theme.of(context);
    if (_children.isEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustration or Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.child_care_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Message
              Text(
                'No children associated with this account',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Add a child to get started with managing their profile',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Button
              FilledButton(
                onPressed:  _showAddChildDialog,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Add Child'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Child selector dropdown
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: _selectedChildId,
            hint: const Text('Select a child'),
            isExpanded: true,
            items: _children.map<DropdownMenuItem<String>>((child) {
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
        ),

        // Action buttons row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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
          ),
        ),

        // Classes list
        if (_selectedChildId != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .doc(widget.schoolCode)
                  .collection('classes')
                  .where('studentIds', arrayContains: _selectedChildId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading classes: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var classes = snapshot.data?.docs ?? [];
                if (classes.isEmpty) {
                  return const Center(
                    child: Text('No classes found for this student'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    var classData = classes[index].data() as Map<String,
                        dynamic>;
                    var classId = classes[index].id;

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ExpansionTile(
                        title: Text(classData['name'] ?? 'Unnamed Class'),
                        subtitle: Text(classData['subject'] ?? 'No subject'),
                        children: [
                          _buildClassGrades(classId),
                          _buildClassAttendance(classId),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

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
      // First, find the child's user document
      QuerySnapshot childUserDocs = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: childEmail)
          .where('role', isEqualTo: 'student')
          .where('schoolCode', isEqualTo: widget.schoolCode)
          .limit(1)
          .get();

      if (childUserDocs.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No student found with this email in your school')),
        );
        return;
      }

      String childId = childUserDocs.docs.first.id;
      String requestId = '${widget.userId}_$childId';

      // Create the child request
      await FirebaseFirestore.instance.collection('childRequests').doc(
          requestId).set({
        'parentId': widget.userId,
        'childId': childId,
        'childEmail': childEmail,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'schoolCode': widget.schoolCode,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending request: $e')),
      );
    }
  }

  bool _validateEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
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
                  decoration: const InputDecoration(
                      hintText: "Reason for absence"),
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
                      _showSubmitAbsenteeFormWithDates(
                          reasonController.text, picked, endDate);
                    }
                  },
                  child: Text(startDate == null
                      ? 'Select Start Date'
                      : 'Start Date: ${DateFormat('yyyy-MM-dd').format(
                      startDate!)}'),
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
                      _showSubmitAbsenteeFormWithDates(
                          reasonController.text, startDate, picked);
                    }
                  },
                  child: Text(endDate == null
                      ? 'Select End Date'
                      : 'End Date: ${DateFormat('yyyy-MM-dd').format(
                      endDate!)}'),
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
  void _showSubmitAbsenteeFormWithDates(String reason, DateTime? start,
      DateTime? end) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Submit Absentee Form'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reason: $reason'),
              Text('Start Date: ${start != null ? DateFormat('yyyy-MM-dd')
                  .format(start) : 'Not selected'}'),
              Text('End Date: ${end != null ? DateFormat('yyyy-MM-dd').format(
                  end) : 'Not selected'}'),
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
  void _submitAbsenteeForm(String reason, DateTime? startDate,
      DateTime? endDate) async {
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
          const SnackBar(
              content: Text('No classes found for the selected child')),
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

  Widget _buildGradesSection() {
    if (_selectedChildId == null) {
      return const Center(child: Text('Please select a child to view grades'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('classes')
          .where('studentIds', arrayContains: _selectedChildId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var classes = snapshot.data?.docs ?? [];
        if (classes.isEmpty) {
          return const Center(child: Text('No classes found for this student'));
        }

        return ListView.builder(
          itemCount: classes.length,
          itemBuilder: (context, index) {
            var classData = classes[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ExpansionTile(
                title: Text(classData['name'] ?? 'Unknown Class'),
                subtitle: Text(classData['subject'] ?? 'No subject'),
                children: [
                  _buildClassGrades(classes[index].id),
                  _buildClassAttendance(classes[index].id),
                ],
              ),
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
          .where('studentId', isEqualTo: _selectedChildId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: const Text('Grades'),
            subtitle: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            title: Text('Grades'),
            subtitle: LinearProgressIndicator(),
          );
        }

        var grades = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Grades',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (grades.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No grades available'),
              )
            else
              ...grades.map((grade) {
                var gradeData = grade.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(
                      gradeData['assignmentName'] ?? 'Unknown Assignment'),
                  subtitle: Text(
                      'Type: ${gradeData['type'] ?? 'Not specified'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${gradeData['score']}/${gradeData['totalPossibleScore']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(DateFormat('MMM d').format(
                          (gradeData['date'] as Timestamp).toDate())),
                    ],
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
          .where('studentId', isEqualTo: _selectedChildId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: const Text('Attendance'),
            subtitle: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            title: Text('Attendance'),
            subtitle: LinearProgressIndicator(),
          );
        }

        var attendance = snapshot.data?.docs ?? [];

        // Calculate attendance statistics
        int totalDays = attendance.length;
        int presentDays = attendance
            .where((doc) =>
        (doc.data() as Map<String, dynamic>)['status'] == 'present')
            .length;
        double attendanceRate = totalDays > 0
            ? (presentDays / totalDays) * 100
            : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Attendance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Present: $presentDays/$totalDays days'),
                  Text('${attendanceRate.toStringAsFixed(1)}%'),
                ],
              ),
            ),
            if (attendance.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Recent Attendance:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...attendance.take(5).map((record) {
                var data = record.data() as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text(DateFormat('MMM d').format(
                      (data['date'] as Timestamp).toDate())),
                  trailing: Text(
                    data['status'] ?? 'Unknown',
                    style: TextStyle(
                      color: data['status'] == 'present' ? Colors.green : Colors
                          .red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ],
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
                content: Text(
                    'Failed to fetch notifications: ${snapshot.error}'),
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
                    var notification = notifications[index].data() as Map<
                        String,
                        dynamic>;
                    bool isRead = false;
                    if (notification['read'] != null &&
                        notification['read'] is Map) {
                      var readMap = notification['read'] as Map<
                          String,
                          dynamic>;
                      isRead = readMap[widget.userId] ?? false;
                    }

                    return ListTile(
                      title: Text(notification['title'] ?? 'No title'),
                      subtitle: Text(notification['body'] ?? 'No content'),
                      trailing: Text(
                        notification['timestamp'] != null
                            ? DateFormat('yyyy-MM-dd').format(
                            (notification['timestamp'] as Timestamp).toDate())
                            : 'No date',
                      ),
                      leading: Icon(
                        isRead ? Icons.mark_email_read : Icons
                            .mark_email_unread,
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
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }
}

