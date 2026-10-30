class PublicController {
  const PublicController();

  Object announcements() {
    return {
      'success': true,
      'data': [
        {
          'id': 'enrollment-first-semester',
          'title': 'Enrollment for First Semester',
          'description':
              'Enrollment for the upcoming semester will begin soon.',
          'displayDate': 'September 2026',
        },
        {
          'id': 'parent-orientation',
          'title': 'Parent Orientation',
          'description':
              'Families are invited to meet advisers and school staff.',
          'displayDate': 'October 2026',
        },
      ],
    };
  }

  Object programs() {
    return {
      'success': true,
      'data': [
        {
          'title': 'Basic Education',
          'description': 'A strong academic foundation with values formation.',
        },
        {
          'title': 'Senior High School',
          'description':
              'Academic tracks for college, career, and community readiness.',
        },
      ],
    };
  }

  Object notImplementedYet(String module) {
    return {
      'success': false,
      'message': '$module will be implemented in a future module.',
    };
  }
}
