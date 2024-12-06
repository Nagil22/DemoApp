import 'package:cloud_firestore/cloud_firestore.dart';

class AssessmentManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String schoolCode;

  AssessmentManager({required this.schoolCode});

  Future<void> createAssessment({
    required String classId,
    required String teacherId,
    required String title,
    required String type,
    required DateTime dueDate,
    required int totalScore,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolCode)
        .collection('assessments')
        .add({
      'classId': classId,
      'teacherId': teacherId,
      'title': title,
      'type': type,
      'dueDate': Timestamp.fromDate(dueDate),
      'totalScore': totalScore,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> generateClassReport(String classId) async {
    final assessments = await _firestore
        .collection('schools')
        .doc(schoolCode)
        .collection('assessments')
        .where('classId', isEqualTo: classId)
        .get();

    return {
      'totalAssessments': assessments.docs.length,
      'assessmentTypes': _calculateAssessmentTypes(assessments.docs),
      'averageScore': _calculateAverageScore(assessments.docs),
    };
  }

  Map<String, int> _calculateAssessmentTypes(List<QueryDocumentSnapshot> assessments) {
    final types = <String, int>{};
    for (var assessment in assessments) {
      final type = (assessment.data() as Map<String, dynamic>)['type'] as String;
      types[type] = (types[type] ?? 0) + 1;
    }
    return types;
  }

  double _calculateAverageScore(List<QueryDocumentSnapshot> assessments) {
    if (assessments.isEmpty) return 0.0;
    var total = 0.0;
    for (var assessment in assessments) {
      final data = assessment.data() as Map<String, dynamic>;
      total += (data['averageScore'] ?? 0.0) as double;
    }
    return total / assessments.length;
  }
}