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
          title: Text('Welcome, ${widget.username}'),
          backgroundColor: _accentColor,
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
        body: _getSelectedSection(),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Overview'),
            BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Classes'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
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
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No classes available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var classData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return ExpansionTile(
              title: Text(classData['name']),
              subtitle: Text('Next class: ${_getNextClassTime(classData)}'),
              trailing: IconButton(
                icon: const Icon(Icons.schedule),
                onPressed: () => _showScheduleDialog(snapshot.data!.docs[index].id, classData),
              ),
              children: [
                ListTile(
                  title: const Text('Take Attendance'),
                  onTap: () => _showAttendanceSheet(snapshot.data!.docs[index].id),
                ),
                ListTile(
                  title: const Text('Manage Grades'),
                  onTap: () => _showGradesManagementDialog(snapshot.data!.docs[index].id),
                ),
                ListTile(
                  title: const Text('Upload Assignment'),
                  onTap: () => _showUploadAssignmentDialog(snapshot.data!.docs[index].id),
                ),
              ],
            );
          },
        );
      },
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
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _showCreateClassDialog(),
                child: const Text('Create New Class'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: snapshot.data?.docs.length ?? 0,
                itemBuilder: (context, index) {
                  var classData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(classData['name']),
                          subtitle: Text('Subject: ${classData['subject']}'),
                        ),
                        OverflowBar(
                          alignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _showAddStudentDialog(snapshot.data!.docs[index].id),
                              child: const Text('Add Student'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                // Implement view students functionality
                              },
                              child: const Text('View Students'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateClassDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Class Name'),
              ),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Class Code'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async {
                if (nameController.text.isEmpty || subjectController.text.isEmpty || codeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                if (schoolDocumentId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error: School not found')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('schools')
                      .doc(schoolDocumentId)
                      .collection('classes')
                      .add({
                    'name': nameController.text,
                    'subject': subjectController.text,
                    'code': codeController.text,
                    'teacherId': widget.userId,
                    'studentIds': [],
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'active',
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class created successfully')),
                  );
                } catch (e) {
                  if (kDebugMode) {
                    print('Error creating class: $e');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating class: $e')),
                  );
                }
              },
            ),
          ],
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

