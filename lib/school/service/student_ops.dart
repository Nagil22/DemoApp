// lib/services/student_ops.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StudentOperations {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Academic Record Management
  Future<Map<String, dynamic>> getAcademicRecord({
    required String schoolId,
    required String studentId,
    required String schoolType,
  }) async {
    try {
      final academicDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('academic_records')
          .doc(studentId)
          .get();

      if (!academicDoc.exists) {
        await _initializeAcademicRecord(schoolId, studentId, schoolType);
        return _getDefaultAcademicRecord(schoolType);
      }

      return academicDoc.data() ?? _getDefaultAcademicRecord(schoolType);
    } catch (e) {
      debugPrint('Error fetching academic record: $e');
      throw Exception('Failed to fetch academic record');
    }
  }

  Future<void> _initializeAcademicRecord(
      String schoolId,
      String studentId,
      String schoolType,
      ) async {
    final academicRecord = _getDefaultAcademicRecord(schoolType);

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('academic_records')
        .doc(studentId)
        .set({
      ...academicRecord,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _getDefaultAcademicRecord(String schoolType) {
    switch (schoolType) {
      case 'university':
        return {
          'currentLevel': '100',
          'totalCredits': 0,
          'gpa': 0.0,
          'academicStatus': 'Active',
          'creditHistory': [],
          'semesters': {},
        };
      case 'secondary':
        return {
          'currentClass': 'JSS1',
          'overallAverage': 0.0,
          'academicStatus': 'Active',
          'terms': {},
        };
      default:
        return {
          'currentGrade': '1',
          'overallAverage': 0.0,
          'academicStatus': 'Active',
          'terms': {},
        };
    }
  }

  Future<bool> _validateRegistrationPeriod(String schoolId) async {
    final schoolDoc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .get();

    if (!schoolDoc.exists) return false;

    final registrationPeriod = schoolDoc.data()?['registrationPeriod'] ?? {};
    final startDate = registrationPeriod['start']?.toDate();
    final endDate = registrationPeriod['end']?.toDate();

    if (startDate == null || endDate == null) return false;

    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  Future<void> registerForCourses({
    required String schoolId,
    required String studentId,
    required List<String> courseIds,
    required String semester,
  }) async {
    try {
      // First validate registration period
      final isValidPeriod = await _validateRegistrationPeriod(schoolId);
      if (!isValidPeriod) {
        throw Exception('Registration period is closed');
      }

      // Then validate credit load
      final isValidCredit = await _validateCreditLoad(
        schoolId,
        studentId,
        courseIds,
      );
      if (!isValidCredit) {
        throw Exception('Credit load exceeds limits');
      }

      // Begin registration transaction
      await _firestore.runTransaction((transaction) async {
        // Update courses collection
        for (String courseId in courseIds) {
          final courseRef = _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('courses')
              .doc(courseId);

          final courseDoc = await transaction.get(courseRef);
          if (!courseDoc.exists) continue;

          // Check course capacity
          final currentEnrollment = (courseDoc.data()?['enrolledStudents'] ?? []).length;
          final maxCapacity = courseDoc.data()?['capacity'] ?? 0;

          if (currentEnrollment >= maxCapacity) {
            throw Exception('Course ${courseDoc.data()?['code']} is full');
          }

          // Add student to course
          transaction.update(courseRef, {
            'enrolledStudents': FieldValue.arrayUnion([studentId])
          });
        }

        // Create registration record
        final registrationRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('registrations')
            .doc('${studentId}_$semester');

        transaction.set(registrationRef, {
          'studentId': studentId,
          'semester': semester,
          'courseIds': courseIds,
          'status': 'registered',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update student's academic record
        final academicRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('academic_records')
            .doc(studentId);

        transaction.update(academicRef, {
          'currentCourses': courseIds,
          'lastUpdated': FieldValue.serverTimestamp(),
          'currentSemester': semester,
        });
      });
    } catch (e) {
      debugPrint('Error in course registration: $e');
      throw Exception('Failed to register courses: $e');
    }
  }

  // Also add this method for dropping courses
  Future<void> dropCourses({
    required String schoolId,
    required String studentId,
    required List<String> courseIds,
    required String semester,
  }) async {
    try {
      // Validate drop period (similar to registration period)
      final isValidPeriod = await _validateRegistrationPeriod(schoolId);
      if (!isValidPeriod) {
        throw Exception('Course drop period is closed');
      }

      await _firestore.runTransaction((transaction) async {
        // Update each course's enrollment
        for (String courseId in courseIds) {
          final courseRef = _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('courses')
              .doc(courseId);

          transaction.update(courseRef, {
            'enrolledStudents': FieldValue.arrayRemove([studentId])
          });
        }

        // Update registration status
        final registrationRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('registrations')
            .doc('${studentId}_$semester');

        transaction.update(registrationRef, {
          'status': 'dropped',
          'droppedCourses': FieldValue.arrayUnion(courseIds),
          'dropDate': FieldValue.serverTimestamp(),
        });

        // Update student's academic record
        final academicRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('academic_records')
            .doc(studentId);

        // Get current courses
        final academicDoc = await transaction.get(academicRef);
        final currentCourses = List<String>.from(academicDoc.data()?['currentCourses'] ?? []);

        // Remove dropped courses
        currentCourses.removeWhere((course) => courseIds.contains(course));

        transaction.update(academicRef, {
          'currentCourses': currentCourses,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Error dropping courses: $e');
      throw Exception('Failed to drop courses: $e');
    }
  }

  Future<bool> _validateCreditLoad(
      String schoolId,
      String studentId,
      List<String> courseIds,
      ) async {
    try {
      final schoolDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .get();

      final creditLimits = schoolDoc.data()?['creditLimits'] ?? {};
      final minCredits = int.parse((creditLimits['min'] ?? 0).toString());
      final maxCredits = int.parse((creditLimits['max'] ?? 24).toString());

      var totalCredits = 0;
      for (String courseId in courseIds) {
        final courseDoc = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('courses')
            .doc(courseId)
            .get();

        if (courseDoc.exists) {
          final courseCredits = courseDoc.data()?['credits'];
          if (courseCredits != null) {
            totalCredits += int.parse(courseCredits.toString());
          }
        }
      }

      return totalCredits >= minCredits && totalCredits <= maxCredits;
    } catch (e) {
      debugPrint('Error validating credit load: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> calculateGPA({
    required String schoolId,
    required String studentId,
    required String semester,
  }) async {
    try {
      final grades = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('studentId', isEqualTo: studentId)
          .where('semester', isEqualTo: semester)
          .get();

      double totalPoints = 0.0;
      int totalCredits = 0;

      for (var grade in grades.docs) {
        final courseDoc = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('courses')
            .doc(grade.data()['courseId'])
            .get();

        if (!courseDoc.exists) continue;

        final courseData = courseDoc.data();
        if (courseData != null) {
          final credits = int.parse((courseData['credits'] ?? 0).toString());
          final score = double.parse((grade.data()['score'] ?? 0).toString());
          final gradePoint = _calculateGradePoint(score);

          totalPoints += (gradePoint * credits);
          totalCredits += credits;
        }
      }

      final semesterGPA = totalCredits > 0 ? totalPoints / totalCredits : 0.0;

      await _updateAcademicRecord(
        schoolId: schoolId,
        studentId: studentId,
        semester: semester,
        gpa: semesterGPA,
        credits: totalCredits,
      );

      return {
        'semesterGPA': semesterGPA,
        'totalCredits': totalCredits,
        'qualityPoints': totalPoints,
      };
    } catch (e) {
      debugPrint('Error calculating GPA: $e');
      throw Exception('Failed to calculate GPA');
    }
  }



  double _calculateGradePoint(double score) {
    if (score >= 70) return 5.0;
    if (score >= 60) return 4.0;
    if (score >= 50) return 3.0;
    if (score >= 45) return 2.0;
    if (score >= 40) return 1.0;
    return 0.0;
  }

  Future<void> _updateAcademicRecord({
    required String schoolId,
    required String studentId,
    required String semester,
    required double gpa,
    required int credits,
  }) async {
    try {
      final academicRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('academic_records')
          .doc(studentId);

      await academicRef.update({
        'semesters.$semester': {
          'gpa': gpa,
          'credits': credits,
          'completedAt': FieldValue.serverTimestamp(),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating academic record: $e');
      throw Exception('Failed to update academic record');
    }
  }

  // Assignment Management
  Future<List<Map<String, dynamic>>> getPendingAssignments({
    required String schoolId,
    required String studentId,
  }) async {
    try {
      final now = DateTime.now();
      final assignmentsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('assignments')
          .where('studentIds', arrayContains: studentId)
          .where('dueDate', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('dueDate')
          .get();

      return assignmentsSnapshot.docs
          .map((doc) => {
        ...doc.data(),
        'id': doc.id,
      })
          .toList();
    } catch (e) {
      debugPrint('Error fetching assignments: $e');
      throw Exception('Failed to fetch assignments');
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

      await assignmentRef.update({
        'submissions.$studentId': {
          ...submission,
          'submittedAt': FieldValue.serverTimestamp(),
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

        await requestRef.update({
          'status': action,
          '${action}At': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        if (action == 'accept') {
          final studentRef = _firestore.collection('users').doc(studentId);
          await studentRef.update({
            'parentIds': FieldValue.arrayUnion([parentId])
          });
        }
      });
    } catch (e) {
      debugPrint('Error handling parent request: $e');
      throw Exception('Failed to handle parent request');
    }
  }
}
