import '../models/announcement_model.dart';

class PublicSiteMockDataSource {
  const PublicSiteMockDataSource();

  Future<List<AnnouncementModel>> getAnnouncements() async {
    return const [
      AnnouncementModel(
        id: 'enrollment-first-semester',
        title: 'Enrollment for First Semester',
        description: 'Enrollment for the upcoming semester will begin soon.',
        displayDate: 'September 2026',
      ),
      AnnouncementModel(
        id: 'parent-orientation',
        title: 'Parent Orientation',
        description: 'Families are invited to meet advisers and school staff.',
        displayDate: 'October 2026',
      ),
      AnnouncementModel(
        id: 'scholarship-applications',
        title: 'Scholarship Applications',
        description: 'Need-based scholarship screening opens next month.',
        displayDate: 'November 2026',
      ),
    ];
  }
}
