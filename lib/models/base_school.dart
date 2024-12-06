abstract class BaseSchool {
  final String schoolId;
  final String schoolType;
  final Map<String, dynamic> configuration;

  BaseSchool({
    required this.schoolId,
    required this.schoolType,
    required this.configuration,
  });

  Map<String, dynamic> get defaultFeatures;
  List<String> get allowedUserRoles;
  Map<String, dynamic> get gradingSystem;
}

// lib/models/school_types/boarding_school.dart
class BoardingSchool extends BaseSchool {
  BoardingSchool({
    required super.schoolId,
    required super.configuration,
  }) : super(
    schoolType: 'boarding',
  );

  @override
  Map<String, dynamic> get defaultFeatures => {
    'dormitoryManagement': true,
    'mealPlanning': true,
    'weekendActivities': true,
    'visitationSchedule': true,
    'healthCenter': true,
    'studentLeave': true,
    'nightStudy': true,
    'dormSupervisor': true,
  };

  @override
  List<String> get allowedUserRoles => [
    'principal',
    'vicePrincipal',
    'teacher',
    'dormSupervisor',
    'nurse',
    'student',
    'parent',
  ];

  @override
  Map<String, dynamic> get gradingSystem => {
    'examWeight': 70,
    'continuousAssessmentWeight': 30,
    'passMark': 40,
    'gradeScale': {
      'A1': {'min': 75, 'max': 100, 'gp': 4.0},
      'B2': {'min': 70, 'max': 74, 'gp': 3.6},
      'B3': {'min': 65, 'max': 69, 'gp': 3.2},
      'C4': {'min': 60, 'max': 64, 'gp': 2.8},
      'C5': {'min': 55, 'max': 59, 'gp': 2.4},
      'C6': {'min': 50, 'max': 54, 'gp': 2.0},
      'D7': {'min': 45, 'max': 49, 'gp': 1.6},
      'E8': {'min': 40, 'max': 44, 'gp': 1.2},
      'F9': {'min': 0, 'max': 39, 'gp': 0.0},
    },
  };
}
