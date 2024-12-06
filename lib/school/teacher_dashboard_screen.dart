import 'package:demo/school/service/assessment_manager.dart';
import 'package:demo/school/service/base_service.dart';
import 'package:demo/school/service/data_validation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/screens/profile_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../dash_screens/messaging_screen.dart';
import 'academic_management.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolCode;
  final String schoolName;
  final String schoolType;

  const TeacherDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolCode,
    required this.schoolName,
    required this.schoolType,
  });

  @override
  TeacherDashboardScreenState createState() => TeacherDashboardScreenState();
}

List<IconData> navIcons = [
  Icons.home,
  Icons.class_,
  Icons.people_alt, // Add this for academic management
  Icons.person,
];

List<String> navTitle = [
  "Overview",
  "Classes",
  "Academic", // Add this
  "Profile"
];


class TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedIndex = 0;
  Color _accentColor = Colors.blue;
  String? schoolDocumentId;
  int notificationCount = 0;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int _unreadMessageCount = 0;
  late Map<String, dynamic> teacherPermissions;

  late final BaseFoundationService _foundationService;
  late final DataValidationService _validationService;
  late final AssessmentManager _assessmentManager;
  Map<String, dynamic> _gradeSystem = {};
  bool _isSetupComplete = false;

  final String userType = 'teacher';

  @override
  void initState() {
    super.initState();
    _foundationService = BaseFoundationService();
    _validationService = DataValidationService();
    _assessmentManager = AssessmentManager(schoolCode: widget.schoolCode);

    _listenToAccentColorChanges();
    _fetchSchoolDocumentId();
    _initializeNotifications();
    _listenToNotifications();
    _listenToUnreadMessages();
    _initializePermissions();
    _initializeTeacherServices();
  }

  void _initializePermissions() {
    teacherPermissions = switch (widget.schoolType) {
      'primary' => {
        'canManageGrades': true,
        'canMessageParents': true,
        'canCreateReports': true,
        'canManageAttendance': true,
        'canManageAssessments': false,
      },
      'secondary' => {
        'canManageGrades': true,
        'canMessageParents': true,
        'canCreateReports': true,
        'canManageAttendance': true,
        'canManageAssessments': true,
        'canManageExams': true,
      },
      'university' => {
        'canManageGrades': true,
        'canMessageStudents': true,
        'canCreateReports': true,
        'canManageAttendance': true,
        'canManageAssessments': true,
        'canManageCredits': true,
        'canManageCourses': true,
      },
      _ => {},
    };
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
            _accentColor = Color(
                int.parse(accentColorHex.substring(1), radix: 16) + 0xFF000000);
          });
        }
      }
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


  void _showCommunicationHubDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Communication Hub'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        UniversalMessagingScreen(
                          userId: widget.userId,
                          schoolId: widget.schoolCode,
                          userType: userType,
                          username: widget.username,
                        ),
                  ));
                },
                child: Text('Messages ($_unreadMessageCount unread)'),
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

  void _showClassReportsDialog(String classId) async {
    try {
      final report = await _assessmentManager.generateClassReport(classId);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Class Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Assessments: ${report['totalAssessments']}'),
              const SizedBox(height: 8),
              Text('Average Score: ${(report['averageScore'] as double).toStringAsFixed(1)}'),
              const SizedBox(height: 8),
              const Text('Assessment Types:'),
              ...(report['assessmentTypes'] as Map<String, int>).entries.map(
                      (e) => Text('  ${e.key}: ${e.value}')
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  Future<void> _initializeTeacherServices() async {
    final hasAccess = await _foundationService.validateUserAccess(
        widget.userId,
        widget.schoolCode
    );

    if (!hasAccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied')),
        );
        return;
      }
    }

    final isValid = await _validationService.validateUserSetup(
      widget.userId,
      widget.schoolCode,
    );

    if (isValid) {
      await _setupGradingSystem();
      await _setupAssessmentTypes();
    }

    setState(() {
      _isSetupComplete = isValid;
    });
  }

  Future<void> _setupGradingSystem() async {
    final schoolDoc = await FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .get();

    setState(() {
      _gradeSystem = schoolDoc.data()?['gradeSystem'] ?? {};
    });
  }

  Future<void> _setupAssessmentTypes() async {
    final assessmentTypes = widget.schoolType == 'university'
        ? ['Quiz', 'Assignment', 'Mid-Semester', 'Final']
        : ['Test', 'Assignment', 'Exam'];

    await FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('config')
        .doc('assessments')
        .set({
      'types': assessmentTypes,
      'weights': _getDefaultWeights(assessmentTypes),
    });
  }

  Map<String, int> _getDefaultWeights(List<String> types) {
    if (widget.schoolType == 'university') {
      return {
        'Quiz': 20,
        'Assignment': 10,
        'Mid-Semester': 30,
        'Final': 40
      };
    }
    return {
      'Test': 30,
      'Assignment': 20,
      'Exam': 50
    };
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
            // Add Communication Hub icon
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
                        '$_unreadMessageCount ',
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
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
        'app_icon');
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid);
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

  Future<void> _notifyStudents(String classId, String title, String body) async {
    try {
      DocumentSnapshot classDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) return;

      var classData = classDoc.data() as Map<String, dynamic>;
      var studentIds = List<String>.from(classData['studentIds'] ?? []);

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'recipients': studentIds,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'academic',
        'classId': classId,
        'teacherId': widget.userId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification: $e');
      }
    }
  }



  Widget _getSelectedSection() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewSection();
      case 1:
        return _buildClassesSection();
      case 2:
        return _buildAcademicSection();
      case 3:
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

  Widget _buildOverviewSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
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

        if (!_isSetupComplete) {
          return const Center(child: Text('Teacher setup incomplete'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No classes available',
                    style: TextStyle(fontSize: 18, color: Colors.grey)
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var classData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            var classId = snapshot.data!.docs[index].id;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(classData['name'] ?? 'Unnamed Class'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subject: ${classData['subject'] ?? 'Not specified'}'),
                    Text('Grading: ${_gradeSystem['type'] ?? 'Standard'}')
                  ],
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildClassActionButton(
                        icon: Icons.assignment_add,
                        label: 'Upload Assignment',
                        onPressed: () => _showUploadAssignmentDialog(classId),
                      ),
                      _buildClassActionButton(
                        icon: Icons.grade,
                        label: 'Manage Grades',
                        onPressed: () => _showManageGradesDialog(classId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildClassActionButton(
                        icon: Icons.people,
                        label: 'View Students',
                        onPressed: () => _showViewStudentsDialog(classId, classData['name']),
                      ),
                      _buildClassActionButton(
                        icon: Icons.assessment,
                        label: 'Class Reports',
                        onPressed: () => _showClassReportsDialog(classId),
                      ),
                    ],
                  ),
                ],
              ),
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
                  child: Text('Notifications', style: Theme
                      .of(context)
                      .textTheme
                      .titleLarge),
                ),
                Flexible(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(schoolDocumentId)
                        .collection('notifications')
                        .where('recipients', arrayContains: widget.userId)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Something went wrong');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      return ListView(
                        shrinkWrap: true,
                        children: snapshot.data!.docs.map((
                            DocumentSnapshot document) {
                          Map<String, dynamic> data = document.data() as Map<
                              String,
                              dynamic>;
                          return ListTile(
                            title: Text(data['title']),
                            subtitle: Text(data['body']),
                            trailing: data['read'] == false
                                ? ElevatedButton(
                              onPressed: () =>
                                  _markNotificationAsRead(document.id),
                              child: const Text('Mark as Read'),
                            )
                                : null,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _markNotificationAsRead(String notificationId) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolDocumentId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true}).then((_) {
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


  void _showViewStudentsDialog(String classId, String className) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Students in $className'),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .doc(schoolDocumentId)
                  .collection('classes')
                  .doc(classId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Text('No students found');
                }

                var classData = snapshot.data!.data() as Map<String, dynamic>;
                var studentIds = List<String>.from(
                    classData['studentIds'] ?? []);

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: studentIds.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users')
                          .doc(studentIds[index])
                          .get(),
                      builder: (context, studentSnapshot) {
                        if (!studentSnapshot.hasData) {
                          return const LinearProgressIndicator();
                        }

                        var studentData = studentSnapshot.data!.data() as Map<
                            String,
                            dynamic>;
                        return ListTile(
                          title: Text(studentData['name'] ?? 'Unknown'),
                          subtitle: Text(studentData['email'] ?? 'No email'),
                        );
                      },
                    );
                  },
                );
              },
            ),
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

  void _showCreateClassDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Create New Class'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Class Name'),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Class Code'),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (value!.length < 4) return 'Code must be at least 4 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () => _handleCreateClass(
                dialogContext,
                formKey,
                nameController.text,
                subjectController.text,
                codeController.text,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCreateClass(
      BuildContext dialogContext,
      GlobalKey<FormState> formKey,
      String name,
      String subject,
      String code,
      ) async {
    if (!formKey.currentState!.validate()) return;

    try {
      // Check if class code already exists
      var existingClasses = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('classes')
          .where('code', isEqualTo: code)
          .get();

      if (existingClasses.docs.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class code already exists')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('classes')
          .add({
        'name': name,
        'subject': subject,
        'code': code,
        'teacherId': widget.userId,
        'studentIds': [],
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (!context.mounted) return;
      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class created successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating class: $e')),
      );
    }
  }

  void _showAddStudentDialog(String classId) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add Student'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Student Email'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () => _handleAddStudent(dialogContext, classId, emailController.text),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAddStudent(
      BuildContext dialogContext,
      String classId,
      String email,
      ) async {
    try {
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('schoolCode', isEqualTo: widget.schoolCode)
          .where('role', isEqualTo: 'student')
          .get();

      if (!context.mounted) return;

      if (studentSnapshot.docs.isNotEmpty) {
        final studentId = studentSnapshot.docs.first.id;
        await addStudentToClass(classId, studentId);
        Navigator.of(dialogContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student not found or not eligible')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding student: $e')),
      );
    }
  }

  void _showManageGradesDialog(String classId) {
    // Will be implemented in the next phase
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grade management coming soon')),
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
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var classes = snapshot.data?.docs ?? [];

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
              child: classes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  var classData = classes[index].data() as Map<String, dynamic>;
                  return _buildClassCard(classData, classes[index].id);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAcademicSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
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

        var classes = snapshot.data?.docs ?? [];

        if (classes.isEmpty) {
          return const Center(
            child: Text('No classes assigned yet'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            var classData = classes[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    classData['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(classData['name']),
                subtitle: Text(classData['subject'] ?? 'No subject'),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AcademicManagementScreen(
                          classId: classes[index].id,
                          teacherId: widget.userId,
                          schoolCode: widget.schoolCode,
                          schoolType: widget.schoolType,
                          className: classData['name'],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
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
                _buildClassActionButton(
                  icon: Icons.person_add,
                  label: 'Add Student',
                  onPressed: () => _showAddStudentDialog(classId),
                ),
                _buildClassActionButton(
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

    Widget _buildClassActionButton({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );
    }


  void _showUploadAssignmentDialog(String classId) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    String selectedType = 'homework';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New Assignment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'Assignment Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                          labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      items: ['homework', 'quiz', 'project', 'exam']
                          .map((type) =>
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedType = value!);
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(DateFormat('MMM d, y').format(dueDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                              const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => dueDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Create'),
                  onPressed: () =>
                      _createAssignment(
                        classId,
                        nameController.text,
                        descriptionController.text,
                        selectedType,
                        dueDate,
                      ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createAssignment(
      String classId,
      String name,
      String description,
      String type,
      DateTime dueDate,
      ) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an assignment name')),
      );
      return;
    }

    try {
      DocumentSnapshot classDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        throw Exception('Class not found');
      }

      var classData = classDoc.data() as Map<String, dynamic>;
      List<String> studentIds = List<String>.from(classData['studentIds'] ?? []);

      // Create the assignment
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolDocumentId)
          .collection('assignments')
          .add({
        'name': name,
        'description': description,
        'type': type,
        'classId': classId,
        'teacherId': widget.userId,
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': FieldValue.serverTimestamp(),
        'studentIds': studentIds,
        'submissions': {},
        'status': 'active',
      });

      // Add notification after creating assignment
      await _notifyStudents(
        classId,
        'New Assignment',
        'A new $type assignment: $name has been posted',
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment created successfully')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating assignment: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating assignment: $e')),
        );
      }
    }
  }}




class CreateClassDialog extends StatefulWidget {
  final String userId;
  final String? schoolDocumentId;

  const CreateClassDialog({
    super.key,
    required this.userId,
    required this.schoolDocumentId,
  });

  @override
  CreateClassDialogState createState() => CreateClassDialogState();
}

class CreateClassDialogState extends State<CreateClassDialog> {
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
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, backgroundColor: Theme.of(context).primaryColor,
          ),
          onPressed: _submitForm,
          child: const Text('Create'),
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
          const SnackBar(content: Text('Error: School not found')),
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

