import '../../database/app_database.dart';
import '../repository_interface.dart';

class LocalUserProfileRepository implements IUserProfileRepository {
  final UserProfileDao _dao;

  const LocalUserProfileRepository(this._dao);

  @override
  Future<UserProfile?> getProfile() => _dao.getProfile();

  @override
  Stream<UserProfile?> watchProfile() => _dao.watchProfile();

  @override
  Future<int> upsertProfile(UserProfileTableCompanion companion) =>
      _dao.upsertProfile(companion);
}
