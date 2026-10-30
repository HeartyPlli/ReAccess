import '../../../../core/security/permissions.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.roles,
    required this.permissions,
    this.username = '',
    this.mustChangePassword = false,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String status;
  final List<AppRole> roles;
  final Set<String> permissions;
  final String username;
  final bool mustChangePassword;

  String get fullName => '$firstName $lastName';

  bool get isActive => status == 'ACTIVE';

  bool get canAccessAdmin {
    return isActive &&
        roles.any(
          (role) =>
              role == AppRole.superAdmin ||
              role == AppRole.admin ||
              role == AppRole.registrar ||
              role == AppRole.teacher ||
              role == AppRole.accounting,
        );
  }

  bool hasPermission(String permission) {
    return roles.contains(AppRole.superAdmin) ||
        permissions.contains(permission);
  }
}
