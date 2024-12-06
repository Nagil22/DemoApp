// lib/services/school_admin_operations.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SchoolAdminOperations {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Foundation Phase Methods
  Future<void> setupGradeSystem({
    required String schoolId,
    required String schoolType,
    required Map<String, dynamic> gradeSystem,
  }) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'gradeSystem': gradeSystem,
        'gradeCalculations': schoolType == 'university' ? _getUniversityGradeCalc() : _getSchoolGradeCalc(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting up grade system: $e');
      throw Exception('Failed to setup grade system');
    }
  }

  Future<void> submitAssignment({
    required String schoolId,
    required String studentId,
    required String assignmentId,
    required Map<String, dynamic> submission,
  }) async {
    try {
      final assignmentRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('assignments')
          .doc(assignmentId);

      final assignmentDoc = await assignmentRef.get();
      if (!assignmentDoc.exists) {
        throw Exception('Assignment not found');
      }

      final dueDate = (assignmentDoc.data()?['dueDate'] as Timestamp).toDate();
      final now = DateTime.now();
      final isLate = now.isAfter(dueDate);

      await assignmentRef.update({
        'submissions.$studentId': {
          ...submission,
          'submittedAt': FieldValue.serverTimestamp(),
          'isLate': isLate,
          'status': 'submitted',
        },
        'submitted': true,
      });
    } catch (e) {
      debugPrint('Error submitting assignment: $e');
      throw Exception('Failed to submit assignment');
    }
  }

  Future<void> handleParentRequest({
    required String requestId,
    required String studentId,
    required String parentId,
    required String action,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final requestRef = _firestore.collection('childRequests').doc(requestId);
        final requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        transaction.update(requestRef, {
          'status': action,
          '${action}At': FieldValue.serverTimestamp(),
        });

        if (action == 'accept') {
          final studentRef = _firestore.collection('users').doc(studentId);
          transaction.update(studentRef, {
            'parentIds': FieldValue.arrayUnion([parentId])
          });
        }
      });
    } catch (e) {
      debugPrint('Error handling parent request: $e');
      throw Exception('Failed to handle parent request');
    }
  }

  Future<void> setupAPIs({
    required String schoolId,
    required Map<String, dynamic> apiConfig,
  }) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'apiConfiguration': {
          ...apiConfig,
          'setupDate': FieldValue.serverTimestamp(),
          'lastChecked': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      debugPrint('Error setting up APIs: $e');
      throw Exception('Failed to setup APIs');
    }
  }

  Future<void> validateData({
    required String schoolId,
    required Map<String, dynamic> data,
  }) async {
    try {
      bool isValid = await _validateSchoolData(data);
      if (!isValid) throw Exception('Invalid data format');

      await _firestore.collection('schools').doc(schoolId).collection('validations').add({
        'data': data,
        'validatedAt': FieldValue.serverTimestamp(),
        'status': 'valid'
      });
    } catch (e) {
      debugPrint('Error validating data: $e');
      throw Exception('Failed to validate data');
    }
  }

  Future<void> optimizeDatabase({
    required String schoolId,
  }) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'optimizationStatus': {
          'lastOptimized': FieldValue.serverTimestamp(),
          'status': 'optimized'
        }
      });
    } catch (e) {
      debugPrint('Error optimizing database: $e');
      throw Exception('Failed to optimize database');
    }
  }

  // University Integration Methods
  Future<void> setupUniversityComponents({
    required String schoolId,
    required Map<String, dynamic> uniConfig,
  }) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'universityConfig': {
          ...uniConfig,
          'courses': [],
          'departments': [],
          'creditSystem': _getDefaultCreditSystem(),
          'setupDate': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      debugPrint('Error setting up university components: $e');
      throw Exception('Failed to setup university components');
    }
  }

  Future<void> setupCreditSystem({
    required String schoolId,
    required Map<String, dynamic> creditSystem,
  }) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'universityConfig.creditSystem': {
          ...creditSystem,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      debugPrint('Error setting up credit system: $e');
      throw Exception('Failed to setup credit system');
    }
  }

  Future<void> setupGPAServices({
    required String schoolId,
    required Map<String, dynamic> gpaConfig,
  }) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'universityConfig.gpaSystem': {
          ...gpaConfig,
          'calculationMethod': 'weighted',
          'scale': 5.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      debugPrint('Error setting up GPA services: $e');
      throw Exception('Failed to setup GPA services');
    }
  }

  // Course Management Methods
  Future<void> manageCourse({
    required String schoolId,
    required Map<String, dynamic> courseData,
  }) async {
    try {
      final courseRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('courses')
          .doc();

      await _firestore.runTransaction((transaction) async {
        transaction.set(courseRef, {
          ...courseData,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        });

        if (courseData['departmentId'] != null) {
          final deptRef = _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('departments')
              .doc(courseData['departmentId']);

          transaction.update(deptRef, {
            'courses': FieldValue.arrayUnion([courseRef.id])
          });
        }
      });
    } catch (e) {
      debugPrint('Error managing course: $e');
      throw Exception('Failed to manage course');
    }
  }

  // GPA Calculation Methods
  Future<void> calculateGPA({
    required String schoolId,
    required String studentId,
    required String semesterId,
  }) async {
    try {
      final gradesSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('studentId', isEqualTo: studentId)
          .where('semesterId', isEqualTo: semesterId)
          .get();

      double totalPoints = 0;
      int totalCredits = 0;

      for (var grade in gradesSnapshot.docs) {
        var gradeData = grade.data();
        int credits = gradeData['credits'] ?? 0;
        double points = gradeData['gradePoint'] ?? 0;

        totalPoints += points * credits;
        totalCredits += credits;
      }

      double gpa = totalCredits > 0 ? totalPoints / totalCredits : 0;

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('academic_records')
          .doc(studentId)
          .collection('semesters')
          .doc(semesterId)
          .update({
        'gpa': gpa,
        'totalCredits': totalCredits,
        'lastCalculated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error calculating GPA: $e');
      throw Exception('Failed to calculate GPA');
    }
  }

  // Helper Methods
  Map<String, dynamic> _getUniversityGradeCalc() {
    return {
      'type': 'gpa',
      'scale': {
        'A': {'points': 5.0, 'range': {'min': 70, 'max': 100}},
        'B': {'points': 4.0, 'range': {'min': 60, 'max': 69}},
        'C': {'points': 3.0, 'range': {'min': 50, 'max': 59}},
        'D': {'points': 2.0, 'range': {'min': 45, 'max': 49}},
        'E': {'points': 1.0, 'range': {'min': 40, 'max': 44}},
        'F': {'points': 0.0, 'range': {'min': 0, 'max': 39}}
      }
    };
  }

  Map<String, dynamic> _getSchoolGradeCalc() {
    return {
      'type': 'percentage',
      'scale': {
        'A1': {'range': {'min': 75, 'max': 100}},
        'B2': {'range': {'min': 70, 'max': 74}},
        'B3': {'range': {'min': 65, 'max': 69}},
        'C4': {'range': {'min': 60, 'max': 64}},
        'C5': {'range': {'min': 55, 'max': 59}},
        'C6': {'range': {'min': 50, 'max': 54}},
        'D7': {'range': {'min': 45, 'max': 49}},
        'E8': {'range': {'min': 40, 'max': 44}},
        'F9': {'range': {'min': 0, 'max': 39}}
      }
    };
  }

  Map<String, dynamic> _getDefaultCreditSystem() {
    return {
      'maxCreditsPerSemester': 24,
      'minCreditsPerSemester': 12,
      'totalCreditsRequired': 120,
      'levelsAndCredits': {
        '100': {'min': 0, 'max': 30},
        '200': {'min': 31, 'max': 60},
        '300': {'min': 61, 'max': 90},
        '400': {'min': 91, 'max': 120}
      }
    };
  }

  Future<bool> _validateSchoolData(Map<String, dynamic> data) async {
    // Add validation logic here
    return data.containsKey('gradeSystem') &&
        data.containsKey('features') &&
        (data['gradeSystem'] != null) &&
        (data['features'] != null);
  }
}