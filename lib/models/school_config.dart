import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SchoolConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> initializeSchoolConfig({
    required String schoolId,
    required String schoolType,
    required Map<String, dynamic> customConfig,
  }) async {
    final baseConfig = _getBaseConfig(schoolType);
    final mergedConfig = {
      ...baseConfig,
      ...customConfig,
      'schoolType': schoolType,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('config')
        .doc('main')
        .set(mergedConfig);

    return mergedConfig;
  }

  Map<String, dynamic> _getBaseConfig(String schoolType) {
    final base = {
      'features': {
        'attendance': true,
        'grading': true,
        'reporting': true,
        'messaging': true,
      },
      'roles': {
        'schooladmin': {
          'canManageUsers': true,
          'canManageClasses': true,
          'canViewReports': true,
          'canModifySettings': true,
        },
        'teacher': {
          'canManageClasses': true,
          'canInputGrades': true,
          'canTakeAttendance': true,
          'canCreateReports': true,
        },
      },
    };

    switch (schoolType) {
      case 'primary':
        return {
          ...base,
          'features': {
            ...base['features']!,
            'studentAccess': false,
            'parentRequired': true,
            'examManagement': true,
            'behaviorTracking': true,
            'healthRecords': true,
            'libraryAccess': true
          },
          'gradeSystem': {
            'type': 'simple',
            'scale': ['A', 'B', 'C', 'D', 'E'],
            'passMark': 40,
          },
          'terms': 3,
          'reportingPeriod': 'term',
        };

      case 'secondary':
        return {
          ...base,
          'features': {
            ...base['features']!,
            'studentAccess': true,
            'parentRequired': true,
            'examManagement': true,
            'behaviorTracking': true,
            'healthRecords': true,
            'libraryAccess': true
          },
          'gradeSystem': {
            'type': 'waec',
            'scale': ['A1', 'B2', 'B3', 'C4', 'C5', 'C6', 'D7', 'E8', 'F9'],
            'passMark': 40,
          },
          'terms': 3,
          'reportingPeriod': 'term',
        };

      case 'university':
        return {
          ...base,
          'features': {
            ...base['features']!,
            'studentAccess': true,
            'parentRequired': false,
            'courseRegistration': true,
            'creditSystem': true,
            'libraryAccess': true
          },
          'gradeSystem': {
            'type': 'gpa',
            'scale': {
              'A': 5.0,
              'B': 4.0,
              'C': 3.0,
              'D': 2.0,
              'E': 1.0,
              'F': 0,
            },
            'passMark': 40,
          },
          'terms': 2,
          'reportingPeriod': 'semester',
        };

      default:
        throw Exception('Invalid school type');
    }
  }

  Future<bool> hasFeatureAccess(String schoolId, String feature, String userRole) async {
    try {
      final configDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('main')
          .get();

      if (!configDoc.exists) return false;

      final config = configDoc.data()!;
      final features = config['features'] as Map<String, dynamic>?;
      final roles = config['roles'] as Map<String, dynamic>?;

      if (features == null || roles == null) return false;

      // Check if feature is enabled for school
      final featureEnabled = features[feature] == true;

      // Check if role has access to feature
      final roleConfig = roles[userRole] as Map<String, dynamic>?;
      final roleHasAccess = roleConfig?[feature] == true;

      return featureEnabled && roleHasAccess;
    } catch (e) {
      debugPrint('Error checking feature access: $e');
      return false;
    }
  }
}