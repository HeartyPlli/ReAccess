import 'package:bcrypt/bcrypt.dart';

class PasswordHasher {
  const PasswordHasher();

  String hash(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  bool verify({required String password, required String passwordHash}) {
    return BCrypt.checkpw(password, passwordHash);
  }
}
