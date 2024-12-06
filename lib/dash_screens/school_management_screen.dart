import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}


class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key});

  @override
  State<SchoolManagementScreen> createState() => SchoolManagementScreenState();
}

class SchoolManagementScreenState extends State<SchoolManagementScreen> with SingleTickerProviderStateMixin {

  // Your existing variables remain the same
  late TabController _tabController;
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _schoolCodeController = TextEditingController();
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();
  String _selectedSchoolType = 'primary';
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // School configuration templates
  final Map<String, Map<String, dynamic>> _schoolConfigs = {
    'primary': {
      'features': {
        'studentAccess': false,
        'parentAccess': true,
        'gradingSystem': 'letter',
        'attendance': true,
        'behavior': true,
        'parentCommunication': true,
      },
      'allowedRoles': ['teacher', 'parent'],
      'gradingScale': {
        'A': 90,
        'B': 80,
        'C': 70,
        'D': 60,
        'F': 0
      }
    },
    'secondary': {
      'features': {
        'studentAccess': true,
        'parentAccess': true,
        'gradingSystem': 'waec',
        'attendance': true,
        'behavior': true,
        'parentCommunication': true,
        'examScores': true,
      },
      'allowedRoles': ['teacher', 'student', 'parent'],
      'gradingScale': {
        'A1': 80,
        'B2': 70,
        'B3': 65,
        'C4': 60,
        'C5': 55,
        'C6': 50,
        'D7': 45,
        'E8': 40,
        'F9': 0
      }
    },
    'university': {
      'features': {
        'studentAccess': true,
        'parentAccess': false,
        'gradingSystem': 'gpa',
        'attendance': true,
        'courseRegistration': true,
        'transcripts': true,
      },
      'allowedRoles': ['teacher', 'student'],
      'gradingScale': {
        'A': 4.0,
        'B': 3.0,
        'C': 2.0,
        'D': 1.0,
        'F': 0.0
      }
    }
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _schoolNameController.dispose();
    _schoolCodeController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create School'),
            Tab(text: 'Manage Schools'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateSchoolTab(),
          _buildManageSchoolsTab(),
        ],
      ),
    );
  }

  Widget _buildCreateSchoolTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSchoolTypeSelector(),
            const SizedBox(height: 20),
            _buildSchoolDetailsForm(),
            const SizedBox(height: 20),
            _buildAdminDetailsForm(),
            const SizedBox(height: 20),
            _buildFeaturesList(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _createSchool,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create School'),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSchoolTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'School Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSchoolType,
              decoration: const InputDecoration(
                labelText: 'Select Type',
                border: OutlineInputBorder(),
              ),
              items: _schoolConfigs.keys.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedSchoolType = value!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolDetailsForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'School Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _schoolNameController,
              decoration: const InputDecoration(
                labelText: 'School Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _schoolCodeController,
              decoration: const InputDecoration(
                labelText: 'School Code',
                border: OutlineInputBorder(),
                helperText: 'Unique identifier for the school',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDetailsForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adminNameController,
              decoration: const InputDecoration(
                labelText: 'Admin Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter admin name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adminEmailController,
              decoration: const InputDecoration(
                labelText: 'Admin Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter admin email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adminPasswordController,
              decoration: const InputDecoration(
                labelText: 'Admin Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _isSchoolCodeUnique(String code) async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('schools')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    return result.docs.isEmpty;
  }


  Widget _buildFeaturesList() {
    final features = _schoolConfigs[_selectedSchoolType]?['features'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'School Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...features.entries.map((entry) {
              bool isEnabled = entry.value == true;
              return ListTile(
                leading: Icon(
                  isEnabled ? Icons.check_circle : Icons.cancel,
                  color: isEnabled ? Colors.green : Colors.red,
                ),
                title: Text(_formatFeatureText(entry.key)),
                subtitle: Text(_getFeatureDescription(entry.key, _selectedSchoolType)),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getFeatureDescription(String feature, String schoolType) {
    final descriptions = {
      'studentAccess': {
        'primary': 'Students cannot access the system directly',
        'secondary': 'Students can access their own records',
        'university': 'Full student portal access',
      },
      'parentRequired': {
        'primary': 'Parent account required for all students',
        'secondary': 'Parent account required for all students',
        'university': 'Parent access not required',
      },
      'grading': {
        'primary': 'Simple A-E grading system',
        'secondary': 'WAEC grading system (A1-F9)',
        'university': 'GPA system',
      },
      'attendance': {
        'primary': 'Daily attendance tracking',
        'secondary': 'Subject-wise attendance tracking',
        'university': 'Course attendance tracking',
      },
      'reporting': {
        'primary': 'Termly report cards with comments',
        'secondary': 'Comprehensive academic reports',
        'university': 'Semester transcripts',
      },
      'messaging': {
        'primary': 'Parent-teacher communication only',
        'secondary': 'Parent-teacher and student-teacher communication',
        'university': 'Direct student-teacher communication',
      },
      'examManagement': {
        'primary': 'Internal examinations only',
        'secondary': 'Internal and external examinations',
        'university': 'Course examinations and projects',
      },
      'behaviorTracking': {
        'primary': 'Daily behavior monitoring',
        'secondary': 'Disciplinary record management',
        'university': 'Not applicable',
      },
      'healthRecords': {
        'primary': 'Basic health information and emergencies',
        'secondary': 'Health records and medical clearance',
        'university': 'Not applicable',
      },
      'libraryAccess': {
        'primary': 'Basic library management',
        'secondary': 'Full library system with book tracking',
        'university': 'Digital library and research resources',
      }
    };

    return descriptions[feature]?[schoolType] ?? '';
  }

  String _formatFeatureText(String text) {
    final formattedText = text.replaceAll(RegExp(r'([A-Z])'), ' \$1').toLowerCase();
    if (formattedText.isEmpty) return '';
    return formattedText[0].toUpperCase() + formattedText.substring(1);
  }


  // Add these methods to your SchoolManagementScreenState class

  Map<String, dynamic> _getGradingSystem() {
    switch (_selectedSchoolType) {
      case 'primary':
        return {
          'type': 'simple',
          'scale': {
            'A': {'min': 70, 'max': 100, 'gp': 5.0},
            'B': {'min': 60, 'max': 69, 'gp': 4.0},
            'C': {'min': 50, 'max': 59, 'gp': 3.0},
            'D': {'min': 45, 'max': 49, 'gp': 2.0},
            'F': {'min': 0, 'max': 44, 'gp': 0.0},
          },
          'passMark': 45,
        };
      case 'secondary':
        return {
          'type': 'waec',
          'scale': {
            'A1': {'min': 75, 'max': 100, 'gp': 5.0},
            'B2': {'min': 70, 'max': 74, 'gp': 4.0},
            'B3': {'min': 65, 'max': 69, 'gp': 3.5},
            'C4': {'min': 60, 'max': 64, 'gp': 3.0},
            'C5': {'min': 55, 'max': 59, 'gp': 2.5},
            'C6': {'min': 50, 'max': 54, 'gp': 2.0},
            'D7': {'min': 45, 'max': 49, 'gp': 1.5},
            'E8': {'min': 40, 'max': 44, 'gp': 1.0},
            'F9': {'min': 0, 'max': 39, 'gp': 0.0},
          },
          'passMark': 45,
        };
      case 'university':
        return {
          'type': 'gpa',
          'scale': {
            'A': {'min': 70, 'max': 100, 'gp': 5.0},
            'B': {'min': 60, 'max': 69, 'gp': 4.0},
            'C': {'min': 50, 'max': 59, 'gp': 3.0},
            'D': {'min': 45, 'max': 49, 'gp': 2.0},
            'F': {'min': 0, 'max': 44, 'gp': 0.0},
          },
          'passMark': 45,
          'maxGPA': 5.0,
        };
      default:
        throw Exception('Invalid school type');
    }
  }

  Future<void> _showSchoolDetails(String schoolId) async {
    try {
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();

      if (!mounted) return;

      if (schoolDoc.exists) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            final schoolData = schoolDoc.data() as Map<String, dynamic>;
            return AlertDialog(
              title: Text(schoolData['name'] ?? 'School Details'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Type: ${schoolData['type']?.toUpperCase() ?? ''}'),
                    Text('Code: ${schoolData['code'] ?? ''}'),
                    Text('Status: ${schoolData['status'] ?? ''}'),
                    Text('Admin Email: ${schoolData['adminEmail'] ?? ''}'),
                    const SizedBox(height: 16),
                    Text('Created: ${schoolData['createdAt']?.toDate().toString() ?? ''}'),
                  ],
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading school details: $e')),
        );
      }
    }
  }

  Future<void> _editSchool(String schoolId) async {
    // For now, just show a message that this feature is coming soon
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('School editing feature coming soon')),
    );
  }

  Future<void> _toggleSchoolStatus(String schoolId, bool currentlyActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .update({
        'status': currentlyActive ? 'inactive' : 'active',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              currentlyActive
                  ? 'School deactivated successfully'
                  : 'School activated successfully'
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating school status: $e')),
      );
    }
  }

  void _clearForm() {
    _schoolNameController.clear();
    _schoolCodeController.clear();
    _adminNameController.clear();
    _adminEmailController.clear();
    _adminPasswordController.clear();
    setState(() {
      _selectedSchoolType = 'primary';
    });
  }


  Widget _buildManageSchoolsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final schools = snapshot.data?.docs ?? [];

        if (schools.isEmpty) {
          return const Center(
            child: Text('No schools found'),
          );
        }

        return ListView.builder(
          itemCount: schools.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final school = schools[index].data() as Map<String, dynamic>;
            return _buildSchoolCard(schools[index].id, school);
          },
        );
      },
    );
  }

  Widget _buildSchoolCard(String schoolId, Map<String, dynamic> school) {
    final bool isActive = school['status'] == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(school['name'] ?? 'Unnamed School'),
        subtitle: Text(
          'Type: ${(school['type'] ?? '').toUpperCase()} - Status: ${school['status'] ?? 'unknown'}',
        ),
        leading: Icon(
          Icons.school,
          color: isActive ? Colors.blue : Colors.grey,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('School Code: ${school['code']}'),
                Text('Admin Email: ${school['adminEmail'] ?? 'Not assigned'}'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _showSchoolDetails(schoolId),
                      child: const Text('View Details'),
                    ),
                    TextButton(
                      onPressed: () => _editSchool(schoolId),
                      child: const Text('Edit'),
                    ),
                    TextButton(
                      onPressed: () => _toggleSchoolStatus(schoolId, isActive),
                      child: Text(isActive ? 'Deactivate' : 'Activate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// This goes in your SchoolManagementScreenState class
  Future<void> _createSchool() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (!await _isSchoolCodeUnique(_schoolCodeController.text)) {
        throw Exception('School code already exists');
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Create admin user
        UserCredential adminUser = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _adminEmailController.text,
          password: _adminPasswordController.text,
        );

        // Create school document
        DocumentReference schoolRef = FirebaseFirestore.instance.collection('schools').doc();
        final schoolConfig = _getSchoolConfig();

        transaction.set(schoolRef, {
          'name': _schoolNameController.text,
          'code': _schoolCodeController.text,
          'type': _selectedSchoolType,
          'adminId': adminUser.user!.uid,
          'adminEmail': _adminEmailController.text,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'config': schoolConfig,
          'gradeSystem': _getGradingSystem(),
          'studentAccess': _selectedSchoolType == 'university',
          'parentRequired': _selectedSchoolType != 'university',
          'features': _schoolConfigs[_selectedSchoolType]!['features'],
        });

        // Create admin user document
        transaction.set(
          FirebaseFirestore.instance.collection('users').doc(adminUser.user!.uid),
          {
            'name': _adminNameController.text,
            'email': _adminEmailController.text,
            'role': 'schooladmin',
            'schoolId': schoolRef.id,
            'schoolCode': _schoolCodeController.text,
            'schoolType': _selectedSchoolType,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'permissions': _getAdminPermissions(),
          },
        );

        // Initialize required collections
        await _initializeSchoolCollections(schoolRef);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School created successfully')),
        );
        _tabController.animateTo(1);
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating school: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _getSchoolConfig() {
    return {
      'academicPeriods': _selectedSchoolType == 'university'
          ? ['First Semester', 'Second Semester']
          : ['First Term', 'Second Term', 'Third Term'],
      'maxStudentsPerClass': _selectedSchoolType == 'primary' ? 30 : 40,
      'attendanceRequired': true,
      'assessmentTypes': _getAssessmentTypes(),
    };
  }

  List<Map<String, dynamic>> _getAssessmentTypes() {
    switch (_selectedSchoolType) {
      case 'university':
        return [
          {'type': 'Test', 'weight': 20},
          {'type': 'Assignment', 'weight': 10},
          {'type': 'MidSemester', 'weight': 30},
          {'type': 'Final', 'weight': 40},
        ];
      case 'secondary':
        return [
          {'type': 'Classwork', 'weight': 10},
          {'type': 'Assignment', 'weight': 10},
          {'type': 'Test', 'weight': 20},
          {'type': 'Exam', 'weight': 60},
        ];
      default:
        return [
          {'type': 'Classwork', 'weight': 20},
          {'type': 'Homework', 'weight': 20},
          {'type': 'Test', 'weight': 20},
          {'type': 'Exam', 'weight': 40},
        ];
    }
  }

  Future<void> _initializeSchoolCollections(DocumentReference schoolRef) async {
    final batch = FirebaseFirestore.instance.batch();
    final collections = [
      'classes',
      'grades',
      'attendance',
      'assessments',
    ];

    if (_selectedSchoolType == 'university') {
      collections.addAll(['courses', 'registrations', 'transcripts']);
    }

    for (var collection in collections) {
      DocumentReference templateRef = schoolRef.collection(collection).doc('_template');
      batch.set(templateRef, {
        'isTemplate': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Map<String, List<String>> _getAdminPermissions() {
    final basePermissions = {
      'school': ['read', 'write', 'manage'],
      'users': ['read', 'write', 'manage'],
      'classes': ['read', 'write', 'manage'],
      'grades': ['read', 'write', 'manage'],
    };

    if (_selectedSchoolType == 'university') {
      basePermissions['courses'] = ['read', 'write', 'manage'];
      basePermissions['registrations'] = ['read', 'write', 'manage'];
      basePermissions['transcripts'] = ['read', 'write', 'manage'];
    }

    return basePermissions;
  }}

