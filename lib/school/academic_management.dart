
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AcademicManagementScreen extends StatefulWidget {
  final String classId;
  final String teacherId;
  final String schoolCode;
  final String schoolType;
  final String className;

  const AcademicManagementScreen({
    super.key,
    required this.classId,
    required this.teacherId,
    required this.schoolCode,
    required this.schoolType,
    required this.className,
  });

  @override
  AcademicManagementScreenState createState() => AcademicManagementScreenState();
}

class AcademicManagementScreenState extends State<AcademicManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> students = [];
  DateTime selectedDate = DateTime.now();
  Map<String, bool> attendanceData = {};

  // Grading systems based on school type
  final Map<String, Map<String, dynamic>> gradingSystems = {
    'primary': {
      'grades': ['A', 'B', 'C', 'D', 'F'],
      'skills': [
        'Follows Instructions',
        'Class Participation',
        'Homework Completion',
        'Behavior',
        'Teamwork'
      ],
      'requiresComments': true,
    },
    'secondary': {
      'grades': ['A1', 'B2', 'B3', 'C4', 'C5', 'C6', 'D7', 'E8', 'F9'],
      'skills': [
        'Subject Understanding',
        'Practical Work',
        'Class Participation',
        'Project Work'
      ],
      'requiresComments': true,
    },
    'university': {
      'grades': ['A', 'B', 'C', 'D', 'E', 'F'],
      'gpaPoints': {
        'A': 5.0,
        'B': 4.0,
        'C': 3.0,
        'D': 2.0,
        'E': 1.0,
        'F': 0.0
      },
      'requiresComments': false,
    },
  };
  // Add to AcademicManagementScreenState class
  Widget _buildDatePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Date: ${DateFormat('MMM d, y').format(selectedDate)}',
              style: const TextStyle(fontSize: 16),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: const Text('Change Date'),
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => selectedDate = picked);
                  _loadAttendanceData(picked);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...students.map((student) => _buildAttendanceRow(student)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (var student in students) {
                            attendanceData[student['id']] = true;
                          }
                        });
                      },
                      child: const Text('Mark All Present'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (var student in students) {
                            attendanceData[student['id']] = false;
                          }
                        });
                      },
                      child: const Text('Mark All Absent'),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _saveAttendanceData,
                  child: const Text('Save Attendance'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildAttendanceStats(),
      ],
    );
  }

  void _editGrade(String gradeId, Map<String, dynamic> gradeData) {
    // Show edit grade dialog
    showDialog(
      context: context,
      builder: (context) => _GradeDialog(
        schoolType: widget.schoolType,
        gradingSystem: gradingSystems[widget.schoolType]!,
        onSubmit: (updatedData) => _updateGrade(gradeId, updatedData),
      ),
    );
  }

  Future<void> _updateGrade(String gradeId, Map<String, dynamic> updatedData) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('grades')
          .doc(gradeId)
          .update({
        ...updatedData,
        'lastModified': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grade updated successfully')),
        );
      }
    } catch (e) {
      _showError('Error updating grade: $e');
    }
  }

  Widget _buildAttendanceRow(Map<String, dynamic> student) {
    return CheckboxListTile(
      title: Text(student['name']),
      subtitle: Text(student['email']),
      value: attendanceData[student['id']] ?? false,
      onChanged: (bool? value) {
        setState(() {
          attendanceData[student['id']] = value ?? false;
        });
      },
    );
  }

  Future<void> _loadAttendanceData(DateTime date) async {
    setState(() => _isLoading = true);
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('attendance')
          .where('classId', isEqualTo: widget.classId)
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .get();

      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        setState(() {
          attendanceData = Map<String, bool>.from(data['attendance'] ?? {});
        });
      } else {
        setState(() {
          attendanceData = {};
          for (var student in students) {
            attendanceData[student['id']] = false;
          }
        });
      }
    } catch (e) {
      _showError('Error loading attendance: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendanceData() async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('attendance')
          .doc('${widget.classId}_${DateFormat('yyyy-MM-dd').format(selectedDate)}')
          .set({
        'classId': widget.classId,
        'date': Timestamp.fromDate(selectedDate),
        'attendance': attendanceData,
        'teacherId': widget.teacherId,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully')),
        );
      }
    } catch (e) {
      _showError('Error saving attendance: $e');
    }
  }

  Widget _buildAttendanceStats() {
    int present = attendanceData.values.where((v) => v).length;
    int total = students.length;
    double percentage = total > 0 ? (present / total) * 100 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Present: $present/$total'),
            Text('Attendance Rate: ${percentage.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);

    try {
      DocumentSnapshot classDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('classes')
          .doc(widget.classId)
          .get();

      if (classDoc.exists) {
        var classData = classDoc.data() as Map<String, dynamic>;
        var studentIds = List<String>.from(classData['studentIds'] ?? []);

        List<Map<String, dynamic>> studentsList = [];
        for (var id in studentIds) {
          var studentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .get();

          if (studentDoc.exists) {
            var studentData = studentDoc.data() as Map<String, dynamic>;
            studentsList.add({
              'id': id,
              'name': studentData['name'],
              'email': studentData['email'],
            });
          }
        }

        setState(() {
          students = studentsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error fetching students: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Grades'),
            Tab(text: 'Attendance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildGradesTab(),
          _buildAttendanceTab(),
        ],
      ),
    );
  }

  Widget _buildGradesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton(
            onPressed: _showAddGradeDialog,
            child: const Text('Add New Grade'),
          ),
          const SizedBox(height: 16),
          _buildGradesList(),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDatePicker(),
          const SizedBox(height: 16),
          _buildAttendanceList(),
        ],
      ),
    );
  }

  Widget _buildGradesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('grades')
          .where('classId', isEqualTo: widget.classId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var grades = snapshot.data!.docs;
        if (grades.isEmpty) {
          return const Center(child: Text('No grades recorded yet'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: grades.length,
          itemBuilder: (context, index) {
            var grade = grades[index].data() as Map<String, dynamic>;
            return _buildGradeCard(grade, grades[index].id);
          },
        );
      },
    );
  }

  Widget _buildGradeCard(Map<String, dynamic> grade, String gradeId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(grade['assessmentName'] ?? 'Unnamed Assessment'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grade: ${grade['grade']}'),
            if (grade['comments'] != null)
              Text('Comments: ${grade['comments']}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editGrade(gradeId, grade),
        ),
      ),
    );
  }

  void _showAddGradeDialog() {
    showDialog(
      context: context,
      builder: (context) => _GradeDialog(
        schoolType: widget.schoolType,
        gradingSystem: gradingSystems[widget.schoolType]!,
        onSubmit: _submitGrade,
      ),
    );
  }

  Future<void> _submitGrade(Map<String, dynamic> gradeData) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('grades')
          .add({
        ...gradeData,
        'classId': widget.classId,
        'teacherId': widget.teacherId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grade added successfully')),
        );
      }
    } catch (e) {
      _showError('Error adding grade: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Grade Dialog Widget
class _GradeDialog extends StatefulWidget {
  final String schoolType;
  final Map<String, dynamic> gradingSystem;
  final Function(Map<String, dynamic>) onSubmit;

  const _GradeDialog({
    required this.schoolType,
    required this.gradingSystem,
    required this.onSubmit,
  });

  @override
  _GradeDialogState createState() => _GradeDialogState();
}

class _GradeDialogState extends State<_GradeDialog> {
  late String selectedGrade;
  final commentController = TextEditingController();
  final Map<String, bool> skills = {};

  @override
  void initState() {
    super.initState();
    selectedGrade = widget.gradingSystem['grades'][0];
    for (var skill in widget.gradingSystem['skills']) {
      skills[skill] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.schoolType.capitalize()} Grade'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedGrade,
              items: widget.gradingSystem['grades'].map<DropdownMenuItem<String>>(
                    (grade) => DropdownMenuItem(
                  value: grade,
                  child: Text(grade),
                ),
              ).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedGrade = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Grade'),
            ),
            if (widget.gradingSystem['requiresComments']) ...[
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comments',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
            if (widget.gradingSystem['skills'] != null) ...[
              const SizedBox(height: 16),
              const Text('Skills Assessment',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...skills.entries.map(
                    (entry) => CheckboxListTile(
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: (value) {
                    setState(() => skills[entry.key] = value ?? false);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSubmit({
              'grade': selectedGrade,
              if (widget.gradingSystem['requiresComments'])
                'comments': commentController.text,
              if (skills.isNotEmpty) 'skills': skills,
            });
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}


extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

