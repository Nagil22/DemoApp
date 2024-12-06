import 'base_school.dart';

class DaySchool extends BaseSchool {
  DaySchool({
    required super.schoolId,
    required super.configuration,
  }) : super(
    schoolType: 'day',
  );

  @override
  Map<String, dynamic> get defaultFeatures => {
    'transportManagement': true,
    'afterSchoolPrograms': true,
    'parentPickup': true,
    'lunchProgram': true,
    'clubActivities': true,
  };

  @override
  List<String> get allowedUserRoles => [
    'principal',
    'vicePrincipal',
    'teacher',
    'student',
    'parent',
  ];

  @override
  Map<String, dynamic> get gradingSystem => {
    'examWeight': 70,
    'continuousAssessmentWeight': 30,
    'passMark': 40,
    'gradeScale': {
      'A': {'min': 70, 'max': 100, 'gp': 4.0},
      'B': {'min': 60, 'max': 69, 'gp': 3.0},
      'C': {'min': 50, 'max': 59, 'gp': 2.0},
      'D': {'min': 45, 'max': 49, 'gp': 1.0},
      'E': {'min': 40, 'max': 44, 'gp': 0.5},
      'F': {'min': 0, 'max': 39, 'gp': 0.0},
    },
  };
}
