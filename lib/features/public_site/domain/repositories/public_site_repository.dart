import '../entities/announcement.dart';

abstract class PublicSiteRepository {
  Future<List<Announcement>> getAnnouncements();
}
