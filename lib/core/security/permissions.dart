class AppPermissions {
  const AppPermissions._();

  static const manageUsers = 'manage_users';
  static const manageStudents = 'manage_students';
  static const manageTeachers = 'manage_teachers';
  static const manageEnrollment = 'manage_enrollment';
  static const manageSubjects = 'manage_subjects';
  static const manageSections = 'manage_sections';
  static const manageGrades = 'manage_grades';
  static const manageAttendance = 'manage_attendance';
  static const manageSchedules = 'manage_schedules';
  static const manageAnnouncements = 'manage_announcements';
  static const viewReports = 'view_reports';
  static const managePayments = 'manage_payments';
  static const viewOwnGrades = 'view_own_grades';
  static const viewOwnAttendance = 'view_own_attendance';
}

enum AppRole {
  superAdmin('SUPER_ADMIN'),
  admin('ADMIN'),
  registrar('REGISTRAR'),
  teacher('TEACHER'),
  accounting('ACCOUNTING'),
  student('STUDENT');

  const AppRole(this.value);

  final String value;
}
