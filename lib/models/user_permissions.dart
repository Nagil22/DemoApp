enum UserTier {
  primary,
  secondary,
  university
}

class UserPermissions {
  static final Map<String, Map<UserTier, List<String>>> rolePermissions = {
    'teacher': {
      UserTier.primary: [
        'view_classes',
        'take_attendance',
        'grade_assignments',
        'create_reports',
        'message_parents',
      ],
      UserTier.secondary: [
        'view_classes',
        'take_attendance',
        'grade_assignments',
        'create_reports',
        'message_parents',
        'manage_exams',
        'create_assessments',
        'view_analytics'
      ],
      UserTier.university: [
        'view_courses',
        'take_attendance',
        'grade_assignments',
        'create_reports',
        'message_students',
        'manage_course_materials',
        'grade_gpa',
        'manage_credits',
        'view_analytics'
      ]
    },
    'student': {
      UserTier.primary: [], // Primary students don't have direct access
      UserTier.secondary: [
        'view_grades',
        'view_assignments',
        'view_attendance',
        'submit_assignments',
        'message_teachers',
        'view_reports'
      ],
      UserTier.university: [
        'view_grades',
        'view_assignments',
        'view_attendance',
        'submit_assignments',
        'message_teachers',
        'view_reports',
        'register_courses',
        'view_credits',
        'view_gpa',
        'access_materials'
      ]
    },
    'parent': {
      UserTier.primary: [
        'view_grades',
        'view_attendance',
        'view_reports',
        'message_teachers',
        'view_assignments',
        'manage_payments',
        'submit_absences'
      ],
      UserTier.secondary: [
        'view_grades',
        'view_attendance',
        'view_reports',
        'message_teachers',
        'view_assignments',
        'manage_payments',
        'submit_absences'
      ],
      UserTier.university: [
        'view_grades',
        'view_attendance',
        'view_reports',
        'manage_payments'
      ]
    }
  };

  static bool hasPermission(String role, UserTier tier, String permission) {
    final permissions = rolePermissions[role]?[tier] ?? [];
    return permissions.contains(permission);
  }
}