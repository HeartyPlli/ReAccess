import '../../domain/entities/announcement.dart';
import '../../domain/repositories/public_site_repository.dart';
import '../datasources/public_site_mock_datasource.dart';

class PublicSiteRepositoryImpl implements PublicSiteRepository {
  const PublicSiteRepositoryImpl(this._dataSource);

  final PublicSiteMockDataSource _dataSource;

  @override
  Future<List<Announcement>> getAnnouncements() {
    return _dataSource.getAnnouncements();
  }
}
