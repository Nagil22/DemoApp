import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'school_config.dart';

class AuthValidationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SchoolConfigService _schoolConfig = SchoolConfigService();

  Future<bool> validateUserAccess({
    required String userId,
    required String schoolId,
    required String feature,
  }) async {
    try {
      // Get user data
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final userRole = userData['role'] as String?;

      // Special handling for superadmin
      if (userRole == 'superadmin') return true;

      final userSchoolCode = userData['schoolCode'] as String?;

      // School code check for non-superadmin users
      if (userSchoolCode != schoolId) return false;

      // For non-superadmin users, check school data
      if (schoolId.isNotEmpty) {
        final schoolDoc = await _firestore
            .collection('schools')
            .doc(schoolId)
            .get();

        if (!schoolDoc.exists) return false;

        final schoolData = schoolDoc.data()!;
        final schoolType = schoolData['type'] as String?;

        if (schoolType == null) return false;

        // Primary school student restrictions
        if (schoolType == 'primary' &&
            userRole == 'student' &&
            feature != 'view_profile') {
          return false;
        }

        // Check feature access through school config
        return await _schoolConfig.hasFeatureAccess(schoolId, feature, userRole ?? '');
      }

      return false; // Don't allow access if no school code for non-superadmin
    } catch (e) {
      debugPrint('Error validating user access: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserPermissions(String schoolCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final userRole = userData['role'] as String?;

      if (userRole == 'superadmin') {
        return {'all': true};
      }

      if (schoolCode.isEmpty) return null;

      final configDoc = await _firestore
          .collection('schools')
          .doc(schoolCode)
          .collection('config')
          .doc('main')
          .get();

      if (!configDoc.exists) return null;

      final config = configDoc.data()!;
      final roles = config['roles'] as Map<String, dynamic>?;

      return roles?[userRole] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting user permissions: $e');
      return null;
    }
  }
  Future<bool> handleUserTypeValidation(
      BuildContext context,
      String? schoolCode,
      String? userId,
      ) async {
    try {
      if (userId == null || userId.isEmpty) {
        _showError(context, 'Invalid user credentials');
        return false;
      }

      // Get the user document
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        _showError(context, 'User account not found');
        return false;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String role = userData['role'] ?? '';

      // Superadmin doesn't need school validation
      if (role == 'superadmin') {
        return true;
      }

      // For other roles, validate school code
      if (schoolCode == null || schoolCode.isEmpty) {
        _showError(context, 'Invalid school access');
        return false;
      }

      // Get school document
      DocumentSnapshot schoolDoc = await _firestore
          .collection('schools')
          .doc(schoolCode)
          .get();

      if (!schoolDoc.exists) {
        _showError(context, 'School not found');
        return false;
      }

      Map<String, dynamic> schoolData = schoolDoc.data() as Map<String, dynamic>;
      String schoolType = schoolData['type'] ?? '';

      // Check primary school student restriction
      if (schoolType == 'primary' && role == 'student') {
        _showPrimaryStudentRestriction(context);
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error in handleUserTypeValidation: $e');
      _showError(context, 'Error validating user access');
      return false;
    }
  }

  void _showPrimaryStudentRestriction(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Access Restricted'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block,
                color: Colors.red,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Primary school students cannot directly access the system.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Please ask your parent to access your information.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}