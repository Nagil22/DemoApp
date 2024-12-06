import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/school_admin_ops.dart';
import '../screens/profile_screen.dart';
import '../dash_screens/payments_screen.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class AdminDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolCode;
  final String schoolName;
  final String schoolType;

  const AdminDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolCode,
    required this.schoolName,
    required this.schoolType,
  });

  @override
  AdminDashboardScreenState createState() => AdminDashboardScreenState();
}

List<IconData> navIcons = [
  Icons.dashboard,
  Icons.people,
  Icons.payment,
  Icons.person,
];
List<String> navTitle = [
  "Overview",
  "Users",
  "Payment",
  "Profile"
];

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _searchController = TextEditingController();

  int _selectedIndex = 0;
  String _schoolName = '';
  String _schoolAddress = '';
  String _logoUrl = '';
  String _schoolType = '';
  String _currentTerm = '';
  final String _currentAcademicYear = DateTime.now().year.toString();
  final SchoolAdminOperations _schoolAdminOps = SchoolAdminOperations();

  final Color _colorPrimary = Colors.blue;
  final Color _colorSecondary = Colors.blueAccent;
  final Color _teacherColor = Colors.green;
  final Color _studentColor = Colors.orange;
  final Color _parentColor = Colors.purple;


  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  bool _schoolExists = false;
  bool get isUniversity => widget.schoolType == 'university';
  bool get allowStudentAccess => isUniversity;

  bool _isGradeSystemSetup = false;
  bool _isApiSetup = false;
  bool _isDatabaseOptimized = false;
  bool _isUniversitySetup = false;  // Only for university type
  bool _isGpaSystemSetup = false;
  bool _isCourseSystemSetup = false;

  String? selectedRole;
  String selectedStatus = 'active';

  List<QueryDocumentSnapshot> _filteredUsers = [];
  List<String> _terms = [];

  Map<String, dynamic> _originalSchoolData = {};
  Map<String, dynamic> _updatedSchoolData = {};
  Map<String, dynamic>? _schoolFeatures;
  final Map<String, dynamic> _gradingSystem = {};
  final Map<String, dynamic> _academicConfig = {};
  final List<Map<String, dynamic>> _departments = [];

  late Stream<QuerySnapshot> usersStream;

  String get periodLabel => widget.schoolType == 'university' ? 'Semester' : 'Term';


  List<String> get allowedRoles {
    if (isUniversity) {
      return ['teacher', 'student', 'schooladmin'];
    } else {
      return ['teacher', 'parent', 'schooladmin'];
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAcademicPeriods();
    _initializeData();
    _checkSetupStatus();
  }


  void _initializeAcademicPeriods() {
    if (widget.schoolType == 'university') {
      _terms = ['First Semester', 'Second Semester', 'Summer Semester'];
      _currentTerm = 'First Semester';
    } else {
      _terms = ['First Term', 'Second Term', 'Third Term'];
      _currentTerm = 'First Term';
    }
  }



  Future<void> _setupGPASystem() async {
    if (widget.schoolType != 'university') return;

    try {
      await _schoolAdminOps.setupGPAServices(
        schoolId: widget.schoolCode,
        gpaConfig: {
          'maxGPA': 5.0,
          'minPassingGPA': 1.0,
          'honorsThreshold': 4.5,
        },
      );

      setState(() => _isGpaSystemSetup = true);
    } catch (e) {
      debugPrint('Error setting up GPA system: $e');
    }
  }

  Future<void> _setupCourseSystem() async {
    if (widget.schoolType != 'university') return;

    try {
      await _schoolAdminOps.setupCreditSystem(
        schoolId: widget.schoolCode,
        creditSystem: {
          'maxCreditsPerSemester': 24,
          'minCreditsPerSemester': 12,
          'requiredCredits': 120,
        },
      );

      setState(() => _isCourseSystemSetup = true);
    } catch (e) {
      debugPrint('Error setting up course system: $e');
    }
  }

  Widget _buildAcademicTermInfo() {
    bool isUniversity = widget.schoolType == 'university';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Period Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Academic Year: $_currentAcademicYear'),
                if (isUniversity)
                  const Tooltip(
                    message: 'Summer semester is for retakes and second intakes',
                    child: Icon(Icons.info_outline),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current $periodLabel:'),
                DropdownButton<String>(
                  value: _currentTerm,
                  items: _terms.map((String term) {
                    return DropdownMenuItem<String>(
                      value: term,
                      child: Text(term),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _currentTerm = newValue;
                      });
                      _updateAcademicPeriod(newValue);
                    }
                  },
                ),
              ],
            ),
            if (isUniversity && _currentTerm == 'Summer Semester')
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Summer semester is reserved for retakes and second intakes',
                  style: TextStyle(
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAcademicPeriod(String newTerm) async {
    try {
      // Calculate period dates
      DateTime now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      if (widget.schoolType == 'university') {
        // University semester dates
        switch (newTerm) {
          case 'First Semester':
            startDate = DateTime(now.year, 9, 1); // September 1st
            endDate = DateTime(now.year + 1, 1, 15); // January 15th
            break;
          case 'Second Semester':
            startDate = DateTime(now.year, 2, 1); // February 1st
            endDate = DateTime(now.year, 6, 15); // June 15th
            break;
          case 'Summer Semester':
            startDate = DateTime(now.year, 7, 1); // July 1st
            endDate = DateTime(now.year, 8, 31); // August 31st
            break;
          default:
            startDate = now;
            endDate = now.add(const Duration(days: 120));
        }
      } else {
        // School term dates (3-4 months each)
        switch (newTerm) {
          case 'First Term':
            startDate = DateTime(now.year, 9, 1); // September 1st
            endDate = DateTime(now.year, 12, 15); // December 15th
            break;
          case 'Second Term':
            startDate = DateTime(now.year, 1, 15); // January 15th
            endDate = DateTime(now.year, 4, 30); // April 30th
            break;
          case 'Third Term':
            startDate = DateTime(now.year, 5, 1); // May 1st
            endDate = DateTime(now.year, 8, 15); // August 15th
            break;
          default:
            startDate = now;
            endDate = now.add(const Duration(days: 90));
        }
      }

      await _firestore
          .collection('schools')
          .doc(widget.schoolCode)
          .update({
        'academicPeriod': {
          'year': _currentAcademicYear,
          'term': newTerm,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'type': widget.schoolType == 'university' ? 'semester' : 'term',
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });

      // Create academic term record
      await _firestore
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('academic_terms')
          .add({
        'name': newTerm,
        'academicYear': _currentAcademicYear,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'type': widget.schoolType == 'university' ? 'semester' : 'term',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Academic $periodLabel updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating academic period: $e')),
        );
      }
    }
  }

  Future<void> _initializeData() async {
    usersStream = FirebaseFirestore.instance
        .collection('users')
        .where('schoolCode', isEqualTo: widget.schoolCode)
        .orderBy('name')
        .snapshots();

    await _fetchSchoolConfiguration();

    await _checkSetupStatus();
    await _validateAllData();  // Add this line
    await _optimizeDatabase(); // Add this line

    if (widget.schoolType == 'university' && !_isUniversitySetup) {
      await _setupUniversityComponents();
    }
  }

  Future<void> _validateAllData() async {
    try {
      final schoolData = {
        'gradeSystem': _gradingSystem,
        'academicConfig': _academicConfig,
        'features': _schoolFeatures,
        'departments': _departments,
      };

      await _schoolAdminOps.validateData(
        schoolId: widget.schoolCode,
        data: schoolData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School data validated successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error validating school data: $e');
    }
  }

  Future<void> _checkSetupStatus() async {
    try {
      final schoolDoc = await _firestore
          .collection('schools')
          .doc(widget.schoolCode)
          .get();

      if (schoolDoc.exists) {
        final data = schoolDoc.data()!;
        setState(() {
          _isGradeSystemSetup = data['gradeSystem'] != null;
          _isApiSetup = data['apiConfiguration'] != null;
          _isDatabaseOptimized = data['optimizationStatus']?['status'] == 'optimized';

          if (widget.schoolType == 'university') {
            _isUniversitySetup = data['universityConfig'] != null;
            _isGpaSystemSetup = data['universityConfig']?['gpaSystem'] != null;
            _isCourseSystemSetup = data['universityConfig']?['creditSystem'] != null;
          }
        });

        if (!_isGradeSystemSetup) await _setupGradeSystem();
        if (!_isApiSetup) await _setupAPIs();
        if (!_isDatabaseOptimized) {
          await _schoolAdminOps.optimizeDatabase(schoolId: widget.schoolCode);
          setState(() => _isDatabaseOptimized = true);
        }
        if (widget.schoolType == 'university') {
          if (!_isGpaSystemSetup) await _setupGPASystem();
          if (!_isCourseSystemSetup) await _setupCourseSystem();
        }

        await _validateAllData();  // Add this line
        await _optimizeDatabase(); // Add this line

      }
    } catch (e) {
      debugPrint('Error checking setup status: $e');
    }
  }

  Future<void> _fetchSchoolConfiguration() async {
    try {
      if (kDebugMode) {
        print('Fetching school configuration for school code: ${widget
            .schoolCode}');
      }
      final schoolQuery = await _firestore
          .collection('schools')
          .where('code', isEqualTo: widget.schoolCode)
          .limit(1)
          .get();

      if (schoolQuery.docs.isNotEmpty) {
        final schoolDoc = schoolQuery.docs.first;
        final schoolConfig = schoolDoc.data();

        if (kDebugMode) {
          print('School found: ${schoolConfig['name']}');
        }

        setState(() {
          _schoolExists = true;
          _originalSchoolData = Map<String, dynamic>.from(schoolConfig);
          _updatedSchoolData = Map<String, dynamic>.from(schoolConfig);
          _schoolName = schoolConfig['name'] ?? '';
          _schoolAddress = schoolConfig['address'] ?? '';
          _logoUrl = schoolConfig['logo'] ?? '';
          _schoolType = schoolConfig['type'] ?? 'primary'; // Add this
          _schoolFeatures =
              schoolConfig['config']?['features'] ?? {}; // Add this
          // Rest of your existing color configurations...
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching school configuration: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_schoolExists) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create School')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('School "${widget.schoolCode}" does not exist.'),
            ],
          ),
        ),
      );
    }

    return Theme(
      data: ThemeData(
        primaryColor: _colorPrimary,
        colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: _colorSecondary),
      ),
      child: Scaffold(
        appBar: AppBar(
          title:
          Text(
              'Admin Dashboard - $_schoolName',
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 20
              )
          ),
          // backgroundColor: _colorPrimary,
          leading: Container(
            padding: const EdgeInsets.all(8.0),
            child: _logoUrl.isNotEmpty
                ? Image.network(_logoUrl, fit: BoxFit.contain)
                : const Placeholder(
              fallbackHeight: 40,
              fallbackWidth: 40,
              color: Colors.white,
            ),
          ),
          actions: [
            if (_hasUnsavedChanges)
              TextButton(
                onPressed: _saveChanges,
                child: Text(
                    'Save Changes', style: TextStyle(color: _colorSecondary)),
              ),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () {
                // Implement notification viewing functionality
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            _buildBody(),
            Align(alignment: Alignment.bottomCenter, child: _navBar())
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewPage();
      case 1:
        return _buildUsersPage();
      case 2:
        return PaymentsScreen(schoolCode: widget.schoolCode, userId: '',);
      case 3:
        return ProfileScreen(
          userId: widget.userId,
          username: '',
          email: '',
          userType: '',
          accentColor: Colors.blueAccent,);
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _navBar() {
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
                onTap: () {
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
                            bottom: 0,
                            left: 30,
                            right: 30
                        ),
                        child: Icon(icon,
                            color: isSelected ? Colors.blue : Colors.grey),
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

  Widget _buildOverviewPage() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Padding(
          // Add bottom padding to account for navigation bar
          padding: const EdgeInsets.only(bottom: 80.0),
          // Increased bottom padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'School Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 22,
                  )
              ),
              const SizedBox(height: 24),
              _buildSchoolTypeFeatures(),
              _buildAcademicTermInfo(),
              _buildEditableField('School Name', _schoolName, (value) =>
                  _updateSchoolField('name', value)),
              _buildEditableField('School Address', _schoolAddress, (value) =>
                  _updateSchoolField('address', value)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickSchoolLogo,
                style: ElevatedButton.styleFrom(
                  elevation: 1,
                  minimumSize: const Size(400, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                  backgroundColor: Colors.white,
                ),
                child: const Text('Update School Logo',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blue)),
              ),
              const SizedBox(height: 26),
              const Text(
                  'User Accent Colors',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 22,
                  )
              ),
              const SizedBox(height: 16),
              _buildColorPicker('Teacher Accent', _teacherColor, (color) =>
                  _updateSchoolField('teacherAccent',
                      '#${color.value.toRadixString(16).substring(2)}')),
              _buildColorPicker('Student Accent', _studentColor, (color) =>
                  _updateSchoolField('studentAccent',
                      '#${color.value.toRadixString(16).substring(2)}')),
              _buildColorPicker('Parent Accent', _parentColor, (color) =>
                  _updateSchoolField('parentAccent',
                      '#${color.value.toRadixString(16).substring(2)}')),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveChanges, style: ElevatedButton.styleFrom(
                elevation: 4,
                minimumSize: const Size(400, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.0),
                ),
                backgroundColor: Colors.blue,
              ),
                child: const Text('Save Changes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ));
  }

  Widget _buildEditableField(String label, String value,
      Function(String) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10)
      ),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        onChanged: (newValue) {
          onChanged(newValue);
          _checkForUnsavedChanges();
        },
      ),
    );
  }


  Widget _buildSchoolTypeFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'School Type: ${_schoolType.toUpperCase()}',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enabled Features',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                if (_schoolFeatures != null) ...[
                  ...(_schoolFeatures!.entries.map((entry) {
                    // Convert value to boolean if it's a string
                    bool isEnabled = entry.value is bool ?
                    entry.value as bool :
                    entry.value.toString().toLowerCase() == 'true';

                    return ListTile(
                      leading: Icon(
                        isEnabled ? Icons.check_circle : Icons.cancel,
                        color: isEnabled ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        entry.key.replaceAll(RegExp(r'([A-Z])'), ' \$1')
                            .toLowerCase()
                            .capitalize(),
                      ),
                    );
                  }).toList()),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker(String label, Color currentColor,
      Function(Color) onColorChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          SizedBox(
            width: 150, // Fixed width for text to align pills
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ),
          GestureDetector(
            onTap: () => _showColorPicker(label, currentColor, onColorChanged),
            child: Container(
              width: 100,
              height: 40,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    right: 8,
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: currentColor.computeLuminance() > 0.5 ? Colors
                          .black54 : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(String label, Color currentColor,
      Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pick $label color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                currentColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              labelTypes: const [],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                onColorChanged(currentColor);
                _updateSchoolField('${label.toLowerCase()}Color',
                    '#${currentColor.value.toRadixString(16).substring(2)}');
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label color updated')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickSchoolLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      try {
        final ref = _storage.ref().child('school_logos/${widget.schoolCode}');
        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        _updateSchoolField('logo', url);
        setState(() {
          _logoUrl = url;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating logo: $e')));
      }
    }
  }

  void _updateSchoolField(String field, dynamic value) {
    setState(() {
      _updatedSchoolData[field] = value;
    });
    _checkForUnsavedChanges();

    // Update Firestore immediately for color changes
    if (field.endsWith('Color')) {
      _firestore.collection('schools').doc(widget.schoolCode).update(
          {field: value}).then((_) {
        if (kDebugMode) {
          print('Updated $field to $value in Firestore');
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('Error updating $field: $error');
        }
      });
    }
  }


  void _checkForUnsavedChanges() {
    bool hasChanges = false;
    _originalSchoolData.forEach((key, value) {
      if (_updatedSchoolData[key] != value) {
        hasChanges = true;
      }
    });
    setState(() {
      _hasUnsavedChanges = hasChanges;
    });
  }

  Future<void> _saveChanges() async {
    try {
      final schoolQuery = await _firestore
          .collection('schools')
          .where('code', isEqualTo: widget.schoolCode)
          .limit(1)
          .get();

      if (schoolQuery.docs.isNotEmpty) {
        final schoolDoc = schoolQuery.docs.first;
        await schoolDoc.reference.update(_updatedSchoolData);
        setState(() {
          _originalSchoolData = Map<String, dynamic>.from(_updatedSchoolData);
          _hasUnsavedChanges = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Changes saved successfully')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: School not found')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving changes: $e')));
      }
    }
  }

  Widget _buildUsersPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search users',
                        prefixIcon: const Icon(
                            Icons.search, color: Colors.grey),
                        suffixIcon: IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.clear, color: Colors.grey),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                      onChanged: _filterUsers,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _showCreateUserDialog,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      shape: const CircleBorder(),
                      backgroundColor: _colorPrimary,
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'School Type: ${_schoolType.toUpperCase()}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: usersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              _filteredUsers = snapshot.data!.docs;
              return ListView.separated(
                itemCount: _filteredUsers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = _filteredUsers[index];
                  final user = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getUserColor(user['role']),
                      child: Text(
                        user['name'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      user['name'] ?? 'No name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            user['email'] ?? 'No email', style: const TextStyle(
                            fontSize: 12)),
                        Text('Role: ${user['role'] ?? 'No role'}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    trailing: Switch(
                      value: user['status'] == 'active',
                      onChanged: (bool value) {
                        _updateUserStatus(doc.id,
                            value ? 'active' : 'inactive');
                      },
                      activeColor: Colors.blue,
                      activeTrackColor: Colors.blue.withOpacity(0.5),
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[300],
                    ),
                    onTap: () => _showUserDetailsDialog(doc),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getUserColor(String? role) {
    switch (role) {
      case 'teacher':
        return _teacherColor;
      case 'student':
        return _studentColor;
      case 'parent':
        return _parentColor;
      case 'schooladmin':
        return _colorPrimary;
      default:
        return Colors.grey;
    }
  }

  void _updateUserStatus(String userId, String status) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'status': status})
        .then((_) => print('User status updated'))
        .catchError((error) => print('Failed to update user status: $error'));
  }

  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? department; // For university teachers/students

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New User'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          if (!value!.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          if (value!.length < 6) return 'Must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: allowedRoles.map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(role.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setDialogState(() {
                            selectedRole = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      if (isUniversity && (selectedRole == 'teacher' || selectedRole == 'student')) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: department,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            border: OutlineInputBorder(),
                          ),
                          items: _getDepartments().map((String dept) {
                            return DropdownMenuItem<String>(
                              value: dept,
                              child: Text(dept),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setDialogState(() {
                              department = newValue;
                            });
                          },
                          validator: (value) => value == null ? 'Required' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      _createUser(
                        nameController.text,
                        emailController.text,
                        passwordController.text,
                        selectedRole!,
                        department,
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _filterUsers(String query) {
    final filtered = _filteredUsers.where((userDoc) {
      final user = userDoc.data() as Map<String, dynamic>;
      return user['name'].toLowerCase().contains(query.toLowerCase()) ||
          user['email'].toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredUsers = filtered;
    });
  }

  void _showUserDetailsDialog(QueryDocumentSnapshot userDoc) {
    final user = userDoc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(user['name']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Email: ${user['email']}'),
                Text('Role: ${user['role']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _toggleUserAccess(userDoc),
                child: Text(user['blocked'] == true ? 'Unblock' : 'Block'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _toggleUserAccess(QueryDocumentSnapshot userDoc) {
    final user = userDoc.data() as Map<String, dynamic>;
    final isBlocked = user['blocked'] == true;
    _firestore.collection('schools').doc(widget.schoolCode).collection('users')
        .doc(userDoc.id).update({
      'blocked': !isBlocked,
    })
        .then((_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isBlocked ? 'User unblocked' : 'User blocked'),
      ));
    });
  }

  Future<void> _createUser(
      String name,
      String email,
      String password,
      String role,
      String? department,
      ) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'role': role,
        'schoolCode': widget.schoolCode,
        'schoolType': widget.schoolType,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.userId,
        'permissions': _getRolePermissions(role),
        'features': _getRoleFeatures(role),
      };

      if (isUniversity && department != null) {
        userData['department'] = department;
        if (role == 'student') {
          userData['academicInfo'] = {
            'credits': 0,
            'gpa': 0.0,
            'level': 100,
            'semesterCount': 0,
            'status': 'active',
            'parentAccess': false,
            'admissionDate': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          };
        }
      }

      await _firestore.runTransaction((transaction) async {
        // Create user document
        transaction.set(
            _firestore.collection('users').doc(userCredential.user!.uid),
            userData
        );

        // Create academic record for university students
        if (isUniversity && role == 'student') {
          // Use the existing method through the transaction
          transaction.set(
              _firestore.collection('schools')
                  .doc(widget.schoolCode)
                  .collection('academic_records')
                  .doc(userCredential.user!.uid),
              {
                'studentId': userCredential.user!.uid,
                'currentLevel': 100,
                'totalCredits': 0,
                'cgpa': 0.0,
                'semesters': [],
                'startDate': FieldValue.serverTimestamp(),
                'status': 'active',
              }
          );
        }
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating user: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  List<String> _getDepartments() {
    // Add your departments here
    return [
      'Computer Science',
      'Engineering',
      'Business Administration',
      'Medicine',
      // Add more departments as needed
    ];
  }

  Future<void> _setupUniversityComponents() async {
    if (widget.schoolType != 'university') return;

    try {
      await _firestore.collection('schools').doc(widget.schoolCode).update({
        'universityConfig': {
          'creditSystem': {
            'maxCreditsPerSemester': 24,
            'minCreditsPerSemester': 12,
            'totalCreditsRequired': 120,
            'gpaScale': 5.0,
          },
          'departments': [],
          'setupDate': FieldValue.serverTimestamp(),
        }
      });

      setState(() => _isUniversitySetup = true);
    } catch (e) {
      debugPrint('Error setting up university components: $e');
    }
  }

  Future<void> _setupGradeSystem() async {
    try {
      final gradeSystem = widget.schoolType == 'university'
          ? {
        'type': 'gpa',
        'scale': {
          'A': {'min': 70, 'max': 100, 'points': 5.0},
          'B': {'min': 60, 'max': 69, 'points': 4.0},
          'C': {'min': 50, 'max': 59, 'points': 3.0},
          'D': {'min': 45, 'max': 49, 'points': 2.0},
          'F': {'min': 0, 'max': 44, 'points': 0.0},
        }
      }
          : {
        'type': 'standard',
        'scale': {
          'A1': {'min': 75, 'max': 100},
          'B2': {'min': 70, 'max': 74},
          'B3': {'min': 65, 'max': 69},
          'C4': {'min': 60, 'max': 64},
          'C5': {'min': 55, 'max': 59},
          'C6': {'min': 50, 'max': 54},
          'D7': {'min': 45, 'max': 49},
          'E8': {'min': 40, 'max': 44},
          'F9': {'min': 0, 'max': 39},
        }
      };

      await _firestore.collection('schools').doc(widget.schoolCode).update({
        'gradeSystem': gradeSystem,
        'lastGradeSystemUpdate': FieldValue.serverTimestamp(),
      });

      setState(() => _isGradeSystemSetup = true);
    } catch (e) {
      debugPrint('Error setting up grade system: $e');
    }
  }

  Future<void> _setupAPIs() async {
    try {
      final apiConfig = {
        'gradeCalculation': true,
        'attendanceTracking': true,
        'reportGeneration': true,
        'setupDate': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('schools').doc(widget.schoolCode).update({
        'apiConfiguration': apiConfig,
      });

      setState(() => _isApiSetup = true);
    } catch (e) {
      debugPrint('Error setting up APIs: $e');
    }
  }

  Future<void> _optimizeDatabase() async {
    try {
      await _schoolAdminOps.optimizeDatabase(schoolId: widget.schoolCode);
      setState(() => _isDatabaseOptimized = true);
    } catch (e) {
      debugPrint('Error optimizing database: $e');
    }
  }

  Map<String, dynamic> _getRolePermissions(String role) {
    final basePermissions = {
      'schooladmin': {
        'all': ['create', 'read', 'update', 'delete'],
      },
      'teacher': {
        'classes': ['create', 'read', 'update'],
        'attendance': ['create', 'read', 'update'],
        'grades': ['create', 'read', 'update'],
        'students': ['read'],
      },
    };

    if (isUniversity) {
      basePermissions['student'] = {
        'courses': ['read'],
        'grades': ['read'],
        'registration': ['create', 'read'],
        'parentAccess': ['update'],
      };
    } else {
      basePermissions['parent'] = {
        'children': ['read'],
        'grades': ['read'],
        'attendance': ['read'],
        'teachers': ['read'],
      };
    }

    return basePermissions[role] ?? {};
  }

  Map<String, dynamic> _getRoleFeatures(String role) {
    switch (role) {
      case 'schooladmin':
        return {
          'manageUsers': true,
          'manageClasses': true,
          'manageGrades': true,
          'manageSystem': true,
        };
      case 'teacher':
        return {
          'grading': true,
          'attendance': true,
          'messaging': true,
          'classManagement': true,
        };
      case 'student':
        if (!isUniversity) return {};
        return {
          'courseRegistration': true,
          'gradeView': true,
          'messaging': true,
          'parentLinking': true,
        };
      case 'parent':
        if (isUniversity) return {};
        return {
          'childrenView': true,
          'gradeView': true,
          'attendanceView': true,
          'messaging': true,
        };
      default:
        return {};
    }
  }}