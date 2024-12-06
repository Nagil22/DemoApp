// lib/utils/grade_calculator.dart

class GradeCalculator {
  static Map<String, dynamic> calculateGrade(String schoolType, List<Map<String, dynamic>> grades) {
    switch (schoolType) {
      case 'primary':
        return _calculatePrimaryGrades(grades);
      case 'secondary':
        return _calculateWAECGrades(grades);
      case 'university':
        return _calculateGPA(grades);
      default:
        return {'error': 'Invalid school type'};
    }
  }

  static Map<String, dynamic> _calculatePrimaryGrades(List<Map<String, dynamic>> grades) {
    var totalScore = 0.0;
    var totalSubjects = 0;

    for (var grade in grades) {
      totalScore += grade['score'] as double;
      totalSubjects++;
    }

    double average = totalSubjects > 0 ? totalScore / totalSubjects : 0;
    return {
      'average': average,
      'totalSubjects': totalSubjects,
      'grade': _getPrimaryGrade(average),
    };
  }

  static Map<String, dynamic> _calculateWAECGrades(List<Map<String, dynamic>> grades) {
    var totalPoints = 0;
    var subjects = 0;
    var gradePoints = {
      'A1': 1, 'B2': 2, 'B3': 3, 'C4': 4, 'C5': 5,
      'C6': 6, 'D7': 7, 'E8': 8, 'F9': 9
    };

    for (var grade in grades) {
      var gradeValue = grade['grade'] as String;
      totalPoints += gradePoints[gradeValue] ?? 9;
      subjects++;
    }

    double average = subjects > 0 ? totalPoints / subjects : 0;
    return {
      'average': average,
      'totalSubjects': subjects,
      'totalPoints': totalPoints,
    };
  }

  static Map<String, dynamic> _calculateGPA(List<Map<String, dynamic>> grades) {
    var totalPoints = 0.0;
    var totalCredits = 0;
    var gradePoints = {
      'A': 5.0, 'B': 4.0, 'C': 3.0, 'D': 2.0, 'E': 1.0, 'F': 0.0
    };

    for (var grade in grades) {
      var gradeValue = grade['grade'] as String;
      var credits = grade['credits'] as int;
      totalPoints += (gradePoints[gradeValue] ?? 0.0) * credits;
      totalCredits += credits;
    }

    double gpa = totalCredits > 0 ? totalPoints / totalCredits : 0.0;
    return {
      'gpa': gpa,
      'totalCredits': totalCredits,
      'qualityPoints': totalPoints,
    };
  }

  static Map<String, dynamic> calculateGradeFromScore(String schoolType, double score) {
    switch (schoolType) {
      case 'primary':
        return _getPrimaryGrade(score);
      case 'secondary':
        return _getSecondaryGrade(score);
      case 'university':
        return _getUniversityGrade(score);
      default:
        return {'error': 'Invalid school type'};
    }
  }

  static Map<String, dynamic> _getPrimaryGrade(double score) {
    if (score >= 90) return {'grade': 'A', 'description': 'Excellent'};
    if (score >= 80) return {'grade': 'B', 'description': 'Very Good'};
    if (score >= 70) return {'grade': 'C', 'description': 'Good'};
    if (score >= 60) return {'grade': 'D', 'description': 'Fair'};
    return {'grade': 'F', 'description': 'Needs Improvement'};
  }

  static Map<String, dynamic> _getSecondaryGrade(double score) {
    if (score >= 75) return {'grade': 'A1', 'points': 1, 'description': 'Excellent'};
    if (score >= 70) return {'grade': 'B2', 'points': 2, 'description': 'Very Good'};
    if (score >= 65) return {'grade': 'B3', 'points': 3, 'description': 'Good'};
    if (score >= 60) return {'grade': 'C4', 'points': 4, 'description': 'Credit'};
    if (score >= 55) return {'grade': 'C5', 'points': 5, 'description': 'Credit'};
    if (score >= 50) return {'grade': 'C6', 'points': 6, 'description': 'Credit'};
    if (score >= 45) return {'grade': 'D7', 'points': 7, 'description': 'Pass'};
    if (score >= 40) return {'grade': 'E8', 'points': 8, 'description': 'Pass'};
    return {'grade': 'F9', 'points': 9, 'description': 'Fail'};
  }

  static Map<String, dynamic> _getUniversityGrade(double score) {
    if (score >= 70) return {'grade': 'A', 'points': 5.0, 'description': 'Excellent'};
    if (score >= 60) return {'grade': 'B', 'points': 4.0, 'description': 'Very Good'};
    if (score >= 50) return {'grade': 'C', 'points': 3.0, 'description': 'Good'};
    if (score >= 45) return {'grade': 'D', 'points': 2.0, 'description': 'Fair'};
    if (score >= 40) return {'grade': 'E', 'points': 1.0, 'description': 'Pass'};
    return {'grade': 'F', 'points': 0.0, 'description': 'Fail'};
  }
}