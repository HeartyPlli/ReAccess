import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../../config/server_config.dart';

class TokenService {
  const TokenService(this._config);

  final ServerConfig _config;
  bool get isProduction => _config.isProduction;

  String createAccessToken({
    required String userId,
    required String email,
    required List<String> roles,
    required List<String> permissions,
    int version = 0,
  }) {
    final jwt = JWT({
      'sub': userId,
      'email': email,
      'roles': roles,
      'permissions': permissions,
      'type': 'access',
      'version': version,
    });

    return jwt.sign(
      SecretKey(_config.jwtSecret),
      expiresIn: Duration(minutes: _config.accessTokenMinutes),
    );
  }

  JWT verifyAccessToken(String token) {
    final jwt = JWT.verify(token, SecretKey(_config.jwtSecret));
    if (jwt.payload['type'] != 'access') {
      throw JWTException('Invalid token type.');
    }
    return jwt;
  }
}
