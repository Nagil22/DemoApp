
import 'package:cloud_firestore/cloud_firestore.dart';

class UserValidationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> validateUserSetup(String userId, String schoolId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;

      // Basic validation
      if (!_validateBasicUserData(userData)) return false;

      final role = userData['role'] as String?;
      if (role != 'teacher') return false;

      // Teacher-specific validation
      return await _validateTeacherSetup(userId, schoolId);
    } catch (e) {
      return false;
    }
  }

  bool _validateBasicUserData(Map<String, dynamic> userData) {
    final requiredFields = [
      'name',
      'email',
      'role',
      'schoolCode',
      'status'
    ];

    return requiredFields.every((field) =>
    userData[field] != null && userData[field].toString().isNotEmpty
    );
  }

  Future<bool> _validateTeacherSetup(String teacherId, String schoolId) async {
    try {
      // Verify teacher's classes
      final classesQuery = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (classesQuery.docs.isEmpty) return false;

      // Verify teacher permissions
      final teacherDoc = await _firestore
          .collection('users')
          .doc(teacherId)
          .get();

      final permissions = teacherDoc.data()?['permissions'] as Map<String, dynamic>?;
      if (permissions == null) return false;

      // Check required teacher permissions
      final requiredPermissions = [
        'classes',
        'grades',
        'attendance',
        'assessments'
      ];

      for (var permission in requiredPermissions) {
        if (!permissions.containsKey(permission) ||
            !permissions[permission]['enabled']) {
          return false;
        }
      }

      // Verify teacher features setup
      final schoolDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .get();

      final features = schoolDoc.data()?['features'] as Map<String, dynamic>?;
      if (features == null) return false;

      final requiredFeatures = [
        'grading',
        'attendance',
        'assessments'
      ];

      return requiredFeatures.every((feature) =>
      features[feature] == true
      );

    } catch (e) {
      return false;
    }
  }
}