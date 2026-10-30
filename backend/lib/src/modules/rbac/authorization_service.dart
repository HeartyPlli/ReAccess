import '../../errors/api_error.dart';
import 'roles.dart';

class AuthenticatedPrincipal {
  const AuthenticatedPrincipal({
    required this.userId,
    required this.email,
    required this.status,
    required this.roles,
    required this.permissions,
  });

  final String userId;
  final String email;
  final String status;
  final Set<AppRole> roles;
  final Set<String> permissions;

  bool get isActive => status == 'ACTIVE';
}

class AuthorizationService {
  const AuthorizationService();

  void requirePermission(AuthenticatedPrincipal principal, String permission) {
    if (!principal.isActive) {
      throw ApiError.unauthorized;
    }

    if (principal.roles.contains(AppRole.superAdmin)) {
      return;
    }

    if (!principal.permissions.contains(permission)) {
      throw ApiError.forbidden;
    }
  }

  void requireOwnRecordOrPermission({
    required AuthenticatedPrincipal principal,
    required String requestedUserId,
    required String permission,
  }) {
    if (principal.userId == requestedUserId) {
      return;
    }

    requirePermission(principal, permission);
  }
}
