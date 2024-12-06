
import 'package:cloud_firestore/cloud_firestore.dart';

class DataValidationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> validateUserSetup(String userId, String schoolId) async {
    try {
      final teacherDoc = await _firestore.collection('users').doc(userId).get();
      if (!teacherDoc.exists) return false;

      final classesQuery = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
          .where('teacherId', isEqualTo: userId)
          .limit(1)
          .get();

      return classesQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, bool>> validateSchoolSetup(String schoolId) async {
    try {
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (!schoolDoc.exists) throw Exception('School not found');

      final data = schoolDoc.data()!;
      final schoolType = data['type'] as String?;

      final results = {
        'gradeSystem': false,
        'attendance': false,
        'reporting': false,
        'database': false
      };

      if (data['gradeSystem'] != null) {
        results['gradeSystem'] = _validateGradeSystem(data['gradeSystem'], schoolType);
      }

      if (data['attendanceSystem'] != null) {
        results['attendance'] = _validateAttendanceSystem(data['attendanceSystem']);
      }

      if (data['reportSystem'] != null) {
        results['reporting'] = _validateReportSystem(data['reportSystem'], schoolType);
      }

      results['database'] = await _validateDatabaseStructure(schoolId);

      return results;
    } catch (e) {
      rethrow;
    }
  }

  bool _validateGradeSystem(Map<String, dynamic> system, String? schoolType) {
    if (schoolType == null) return false;

    final requiredFields = schoolType == 'university'
        ? ['type', 'scale', 'classifications']
        : ['type', 'scale'];

    return requiredFields.every((field) => system.containsKey(field));
  }

  bool _validateAttendanceSystem(Map<String, dynamic> system) {
    final requiredFields = ['type', 'periods', 'options'];
    return requiredFields.every((field) => system.containsKey(field));
  }

  bool _validateReportSystem(Map<String, dynamic> system, String? schoolType) {
    if (schoolType == null) return false;

    final requiredFields = ['type', 'components'];
    if (!requiredFields.every((field) => system.containsKey(field))) {
      return false;
    }

    final components = system['components'] as List?;
    if (components == null || components.isEmpty) return false;

    switch (schoolType) {
      case 'primary':
        return components.contains('behavior') && components.contains('skills');
      case 'secondary':
        return components.contains('subjects') && components.contains('grades');
      case 'university':
        return components.contains('courses') && components.contains('gpa');
      default:
        return false;
    }
  }

  Future<bool> _validateDatabaseStructure(String schoolId) async {
    try {
      final requiredCollections = [
        'users',
        'classes',
        'attendance',
        'grades',
        'reports'
      ];

      for (var collection in requiredCollections) {
        final snapshot = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection(collection)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}