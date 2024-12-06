import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class SchoolCreationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createSchool({
    required String name,
    required String code,
    required String type,  // 'primary', 'secondary', or 'university'
    required String adminEmail,
    required String adminName,
    required String adminPassword,
    String? address,
  }) async {
    String? schoolId;
    String? adminUserId;

    try {
      await _firestore.runTransaction((transaction) async {
        // Check if school code is unique
        var existingSchool = await _firestore
            .collection('schools')
            .where('code', isEqualTo: code)
            .get();

        if (existingSchool.docs.isNotEmpty) {
          throw Exception('School code already exists');
        }

        // Create school document
        DocumentReference schoolRef = _firestore.collection('schools').doc();
        schoolId = schoolRef.id;

        Map<String, dynamic> schoolData = {
          'name': name,
          'code': code,
          'type': type,
          'address': address,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'features': _getSchoolTypeFeatures(type),
          'gradeSystem': _getGradingSystem(type),
        };

        transaction.set(schoolRef, schoolData);

        // Create admin user
        UserCredential adminUserCred = await _auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        adminUserId = adminUserCred.user!.uid;

        // Create admin document
        DocumentReference adminRef = _firestore.collection('users').doc(adminUserId);
        transaction.set(adminRef, {
          'name': adminName,
          'email': adminEmail,
          'role': 'schooladmin',
          'schoolId': schoolId,
          'schoolCode': code,
          'schoolType': type,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'permissions': _getAdminPermissions(type),
        });

        // Update school with admin reference
        transaction.update(schoolRef, {
          'adminId': adminUserId,
          'adminEmail': adminEmail,
        });
      });

      // Initialize school structure
      if (schoolId != null) {
        await _initializeSchoolCollections(schoolId!, type);
      }

      return schoolId!;
    } catch (e) {
      if (adminUserId != null) {
        try {
          await _auth.currentUser?.delete();
          await _firestore.collection('users').doc(adminUserId).delete();
        } catch (cleanupError) {
          debugPrint('Cleanup error: $cleanupError');
        }
      }
      throw Exception('Failed to create school: $e');
    }
  }

  Map<String, dynamic> _getSchoolTypeFeatures(String type) {
    switch (type) {
      case 'primary':
        return {
          'studentAccess': false,
          'parentRequired': true,
          'behaviorTracking': true,
          'simpleGrading': true,
        };
      case 'secondary':
        return {
          'studentAccess': false,
          'parentRequired': true,
          'waecGrading': true,
          'examTracking': true,
        };
      case 'university':
        return {
          'studentAccess': true,
          'parentOptional': true,
          'creditSystem': true,
          'gpaTracking': true,
          'courseRegistration': true,
        };
      default:
        throw Exception('Invalid school type');
    }
  }

  Map<String, dynamic> _getGradingSystem(String type) {
    switch (type) {
      case 'primary':
        return {
          'type': 'simple',
          'scale': {
            'A': {'min': 70, 'max': 100, 'comment': 'Excellent'},
            'B': {'min': 60, 'max': 69, 'comment': 'Very Good'},
            'C': {'min': 50, 'max': 59, 'comment': 'Good'},
            'D': {'min': 40, 'max': 49, 'comment': 'Fair'},
            'F': {'min': 0, 'max': 39, 'comment': 'Fail'},
          },
          'passMark': 40,
        };
      case 'secondary':
        return {
          'type': 'waec',
          'scale': {
            'A1': {'min': 75, 'max': 100, 'comment': 'Excellent'},
            'B2': {'min': 70, 'max': 74, 'comment': 'Very Good'},
            'B3': {'min': 65, 'max': 69, 'comment': 'Good'},
            'C4': {'min': 60, 'max': 64, 'comment': 'Credit'},
            'C5': {'min': 55, 'max': 59, 'comment': 'Credit'},
            'C6': {'min': 50, 'max': 54, 'comment': 'Credit'},
            'D7': {'min': 45, 'max': 49, 'comment': 'Pass'},
            'E8': {'min': 40, 'max': 44, 'comment': 'Pass'},
            'F9': {'min': 0, 'max': 39, 'comment': 'Fail'},
          },
          'passMark': 40,
        };
      case 'university':
        return {
          'type': 'gpa',
          'scale': {
            'A': {'min': 70, 'max': 100, 'gp': 5.0},
            'B': {'min': 60, 'max': 69, 'gp': 4.0},
            'C': {'min': 50, 'max': 59, 'gp': 3.0},
            'D': {'min': 45, 'max': 49, 'gp': 2.0},
            'E': {'min': 40, 'max': 44, 'gp': 1.0},
            'F': {'min': 0, 'max': 39, 'gp': 0.0},
          },
          'passMark': 40,
          'maxGPA': 5.0,
        };
      default:
        throw Exception('Invalid school type');
    }
  }

  Future<void> _initializeSchoolCollections(String schoolId, String type) async {
    final batch = _firestore.batch();
    final schoolRef = _firestore.collection('schools').doc(schoolId);

    // Common collections for all school types
    final baseCollections = {
      'classes': {'template': true},
      'attendance': {'template': true},
      'grades': {'template': true},
      'users': {'template': true}
    };

    // Type-specific collections
    if (type == 'university') {
      baseCollections['courses'] = {'template': true};
      baseCollections['departments'] = {'template': true};
      baseCollections['registrations'] = {'template': true};
    }

    // Create collections
    for (var collection in baseCollections.entries) {
      DocumentReference templateRef = schoolRef.collection(collection.key).doc('_template');
      batch.set(templateRef, collection.value);
    }

    await batch.commit();
  }

  Map<String, dynamic> _getAdminPermissions(String type) {
    final basePermissions = {
      'users': ['create', 'read', 'update', 'delete'],
      'classes': ['create', 'read', 'update', 'delete'],
      'grades': ['create', 'read', 'update', 'delete'],
      'settings': ['read', 'update'],
    };

    if (type == 'university') {
      basePermissions['courses'] = ['create', 'read', 'update', 'delete'];
      basePermissions['departments'] = ['create', 'read', 'update', 'delete'];
      basePermissions['registrations'] = ['read', 'update'];
    }

    return basePermissions;
  }
}