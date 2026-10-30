import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/public_site_mock_datasource.dart';
import '../../data/repositories/public_site_repository_impl.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/entities/school_program.dart';
import '../../domain/repositories/public_site_repository.dart';
import '../../domain/usecases/get_public_announcements.dart';

final publicSiteDataSourceProvider = Provider<PublicSiteMockDataSource>((ref) {
  return const PublicSiteMockDataSource();
});

final publicSiteRepositoryProvider = Provider<PublicSiteRepository>((ref) {
  return PublicSiteRepositoryImpl(ref.watch(publicSiteDataSourceProvider));
});

final getPublicAnnouncementsProvider = Provider<GetPublicAnnouncements>((ref) {
  return GetPublicAnnouncements(ref.watch(publicSiteRepositoryProvider));
});

final publicAnnouncementsProvider = FutureProvider<List<Announcement>>((
  ref,
) async {
  return ref.watch(getPublicAnnouncementsProvider).call();
});

final schoolProgramsProvider = Provider<List<SchoolProgram>>((ref) {
  return const [
    SchoolProgram(
      title: 'Basic Education',
      description: 'A strong academic foundation with values formation and guided learning support.',
      icon: 'school',
    ),
    SchoolProgram(
      title: 'Senior High School',
      description: 'Academic tracks that prepare learners for college, career, and community life.',
      icon: 'menu_book',
    ),
    SchoolProgram(
      title: 'Student Services',
      description: 'Advising, activities, and learner support services organized around student needs.',
      icon: 'groups',
    ),
  ];
});
