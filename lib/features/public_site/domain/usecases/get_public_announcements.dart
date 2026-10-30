import '../entities/announcement.dart';
import '../repositories/public_site_repository.dart';

class GetPublicAnnouncements {
  const GetPublicAnnouncements(this._repository);

  final PublicSiteRepository _repository;

  Future<List<Announcement>> call() {
    return _repository.getAnnouncements();
  }
}
