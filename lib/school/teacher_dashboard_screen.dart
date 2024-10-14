import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/screens/profile_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class TeacherDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolCode;
  final String schoolName;

  const TeacherDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolCode,
    required this.schoolName,
  });

  @override
  TeacherDashboardScreenState createState() => TeacherDashboardScreenState();
}

List<IconData> navIcons = [
  Icons.home,
  Icons.class_,
  Icons.person,
];
List<String> navTitle = [
  "Overview",
  "Classes",
  "Profile"
];


class TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedIndex = 0;
  Color _accentColor = Colors.blue;
  String? schoolDocumentId;
  int notificationCount = 0;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


  @override
  void initState() {
    super.initState();
    _listenToAccentColorChanges();
    _fetchSchoolDocumentId();
    _initializeNotifications();
    _listenToNotifications();
  }

  void _listenToAccentColorChanges() {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final accentColorHex = data['teacherAccent'] as String?;
        if (accentColorHex != null) {
          setState(() {
            _accentColor = Color(int.parse(accentColorHex.substring(1), radix: 16) + 0xFF000000);
          });
        }
      }
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
          title: Text(
            'Welcome, ${widget.username}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 20
            )
        ),
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications,color: Colors.black),
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
        body:  Stack(
          children: [
            _getSelectedSection(),
            Align(alignment: Alignment.bottomCenter, child: _navBar())
          ],
        ),
      ),
    );
  }

  Future<void> _fetchSchoolDocumentId() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .where('code', isEqualTo: widget.schoolCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          schoolDocumentId = querySnapshot.docs.first.id;
        });
      } else {
        if (kDebugMode) {
          print('No school found with code: ${widget.schoolCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching school document ID: $e');
      }
    }
  }


  Future<void> addStudentToClass(String classId, String studentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('classes')
          .doc(classId)
          .update({
        'studentIds': FieldValue.arrayUnion([studentId]),
      });
      if (kDebugMode) {
        print('Successfully added student to class');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding student to class: $e');
      }
    }
  }

  void _initializeNotifications() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _listenToNotifications() {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolDocumentId)
        .collection('notifications')
        .where('recipients', arrayContains: widget.userId)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        notificationCount = snapshot.docs
            .where((doc) => doc.data()['read'] == false)
            .length;
      });
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
                            left: 45,
                            right: 45
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
        return _buildClassesSection();
      case 2:
        return ProfileScreen(
          userId: widget.userId,
          username: widget.username,
          email: '',
          userType: 'teacher',
          accentColor: _accentColor,
        );
      default:
        return _buildOverviewSection();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  Widget _buildOverviewSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('classes')
          .where('teacherId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No classes available', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var classData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  classData['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text(
                  'Next class: ${_getNextClassTime(classData)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.primaries[index % Colors.primaries.length],
                  child: Text(
                    classData['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.schedule, color: Theme.of(context).primaryColor),
                  onPressed: () => _showScheduleDialog(snapshot.data!.docs[index].id, classData),
                ),
                children: [
                  const Divider(height: 1),
                  _buildActionTile(
                    icon: Icons.checklist,
                    title: 'Take Attendance',
                    onTap: () => _showAttendanceSheet(snapshot.data!.docs[index].id),
                  ),
                  _buildActionTile(
                    icon: Icons.grade,
                    title: 'Manage Grades',
                    onTap: () => _showGradesManagementDialog(snapshot.data!.docs[index].id),
                  ),
                  _buildActionTile(
                    icon: Icons.assignment,
                    title: 'Upload Assignment',
                    onTap: () => _showUploadAssignmentDialog(snapshot.data!.docs[index].id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  String _getNextClassTime(Map<String, dynamic> classData) {
    // Implement logic to get the next class time based on the schedule
    // For now, we'll return a placeholder
    return classData['nextClass'] ?? 'Not scheduled';
  }

  void _showScheduleDialog(String classId, Map<String, dynamic> classData) {
    DateTime selectedDateTime = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Set Schedule for ${classData['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select date and time for the class:'),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text('Pick Date and Time'),
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDateTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                    );
                    if (pickedTime != null) {
                      selectedDateTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                // Save the schedule to Firestore
                await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolDocumentId)
                    .collection('classes')
                    .doc(classId)
                    .update({
                  'nextClass': selectedDateTime,
                });

                // Schedule a notification
                _scheduleClassNotification(classData['name'], selectedDateTime);

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Class schedule updated and notification set')),
                );
              },
            ),
          ],
        );
      },
    );
  }
  void _showNotificationsDialog() {
    // Implement a dialog or a new screen to show notifications
  }

  void _scheduleClassNotification(String className, DateTime classTime) {
    flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Class Reminder',
      '$className is about to start',
      tz.TZDateTime.from(classTime.subtract(const Duration(minutes: 5)), tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_channel_id',
          'Class Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }


  Widget _buildClassesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('classes')
          .where('teacherId', isEqualTo: widget.userId)
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateClassDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Create New Class'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            Expanded(
              child: snapshot.data?.docs.isEmpty ?? true
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data?.docs.length ?? 0,
                itemBuilder: (context, index) {
                  var classData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return _buildClassCard(classData, snapshot.data!.docs[index].id);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.class_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No classes available', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showCreateClassDialog(),
            child: const Text('Create Your First Class'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData, String classId) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    classData['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classData['name'],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Subject: ${classData['subject']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.person_add,
                  label: 'Add Student',
                  onPressed: () => _showAddStudentDialog(classId),
                ),
                _buildActionButton(
                  icon: Icons.people,
                  label: 'View Students',
                  onPressed: () => _showViewStudentsDialog(classId, classData['name']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showViewStudentsDialog(String classId, String className) {
    // Implement the view students functionality here
    // You can use a dialog or navigate to a new screen to show the list of students
  }

  void _showCreateClassDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateClassDialog(
          userId: widget.userId,
          schoolDocumentId: schoolDocumentId,
        );
      },
    );
  }
  void _showAddStudentDialog(String classId) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Student'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Student Email'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                final studentSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: emailController.text)
                    .where('schoolCode', isEqualTo: widget.schoolCode)
                    .where('role', isEqualTo: 'student')
                    .get();

                if (studentSnapshot.docs.isNotEmpty) {
                  final studentId = studentSnapshot.docs.first.id;
                  await addStudentToClass(classId, studentId);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student added successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student not found or not eligible')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAttendanceSheet(String classId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolDocumentId)
              .collection('classes')
              .doc(classId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();

            var classData = snapshot.data!.data() as Map<String, dynamic>;
            var studentIds = List<String>.from(classData['studentIds'] ?? []);

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: studentIds.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(studentIds[index]).get(),
                        builder: (context, studentSnapshot) {
                          if (!studentSnapshot.hasData) return const CircularProgressIndicator();

                          var studentData = studentSnapshot.data!.data() as Map<String, dynamic>;
                          return CheckboxListTile(
                            title: Text(studentData['name']),
                            value: false,
                            onChanged: (bool? value) {
                              // TODO: Update attendance status
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Save attendance
                    Navigator.pop(context);
                  },
                  child: const Text('Save Attendance'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGradesManagementDialog(String classId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manage Grades'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => _showAddGradeDialog(classId),
                child: const Text('Add New Grade'),
              ),
              ElevatedButton(
                onPressed: () => _showViewGradesSheet(classId),
                child: const Text('View/Edit Grades'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }


  void _showAddGradeDialog(String classId) {
    final TextEditingController assignmentNameController = TextEditingController();
    final TextEditingController totalScoreController = TextEditingController();
    String selectedType = 'homework';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Grade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: assignmentNameController,
                decoration: const InputDecoration(labelText: 'Assignment Name'),
              ),
              TextField(
                controller: totalScoreController,
                decoration: const InputDecoration(labelText: 'Total Possible Score'),
                keyboardType: TextInputType.number,
              ),
              DropdownButton<String>(
                value: selectedType,
                items: ['homework', 'quiz', 'exam', 'project']
                    .map((String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                ))
                    .toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    selectedType = newValue;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                // Add the new grade to Firestore
                await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolDocumentId)
                    .collection('grades')
                    .add({
                  'classId': classId,
                  'assignmentName': assignmentNameController.text,
                  'totalPossibleScore': int.parse(totalScoreController.text),
                  'type': selectedType,
                  'date': Timestamp.now(),
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New grade added successfully')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showViewGradesSheet(String classId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolDocumentId)
              .collection('grades')
              .where('classId', isEqualTo: classId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();

            var grades = snapshot.data!.docs;

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: grades.length,
                    itemBuilder: (context, index) {
                      var gradeData = grades[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(gradeData['assignmentName']),
                        subtitle: Text('Type: ${gradeData['type']} | Total Score: ${gradeData['totalPossibleScore']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditGradeDialog(grades[index].id, gradeData),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditGradeDialog(String gradeId, Map<String, dynamic> gradeData) {
    final TextEditingController assignmentNameController = TextEditingController(text: gradeData['assignmentName']);
    final TextEditingController totalScoreController = TextEditingController(text: gradeData['totalPossibleScore'].toString());
    String selectedType = gradeData['type'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Grade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: assignmentNameController,
                decoration: const InputDecoration(labelText: 'Assignment Name'),
              ),
              TextField(
                controller: totalScoreController,
                decoration: const InputDecoration(labelText: 'Total Possible Score'),
                keyboardType: TextInputType.number,
              ),
              DropdownButton<String>(
                value: selectedType,
                items: ['homework', 'quiz', 'exam', 'project']
                    .map((String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                ))
                    .toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    selectedType = newValue;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                // Update the grade in Firestore
                await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolDocumentId)
                    .collection('grades')
                    .doc(gradeId)
                    .update({
                  'assignmentName': assignmentNameController.text,
                  'totalPossibleScore': int.parse(totalScoreController.text),
                  'type': selectedType,
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Grade updated successfully')),
                );
              },
            ),
          ],
        );
      },
    );
  }


  void _showUploadAssignmentDialog(String classId) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upload Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Assignment Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              // TODO: Add file upload functionality
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Upload'),
              onPressed: () async {
                // TODO: Implement assignment upload logic
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Assignment uploaded successfully')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}




class CreateClassDialog extends StatefulWidget {
  final String userId;
  final String? schoolDocumentId;

  const CreateClassDialog({
    Key? key,
    required this.userId,
    required this.schoolDocumentId,
  }) : super(key: key);

  @override
  _CreateClassDialogState createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends State<CreateClassDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Class', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Class Name',
                icon: Icons.class_,
                validator: (value) => value!.isEmpty ? 'Please enter a class name' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _subjectController,
                label: 'Subject',
                icon: Icons.subject,
                validator: (value) => value!.isEmpty ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _codeController,
                label: 'Class Code',
                icon: Icons.code,
                validator: (value) => value!.isEmpty ? 'Please enter a class code' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text('Create'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, backgroundColor: Theme.of(context).primaryColor,
          ),
          onPressed: _submitForm,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      validator: validator,
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (widget.schoolDocumentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: School not found')),
        );
        return;
      }

      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolDocumentId)
            .collection('classes')
            .add({
          'name': _nameController.text,
          'subject': _subjectController.text,
          'code': _codeController.text,
          'teacherId': widget.userId,
          'studentIds': [],
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Class created successfully')),
        );
      } catch (e) {
        print('Error creating class: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating class: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}

