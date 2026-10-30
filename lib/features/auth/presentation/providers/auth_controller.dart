import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/security/permissions.dart';
import '../../domain/entities/auth_user.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

enum AuthStatus { unknown, loading, authenticated, unauthenticated, expired }

class AuthState {
  const AuthState({required this.status, this.user, this.message});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  final AuthStatus status;
  final AuthUser? user;
  final String? message;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({AuthStatus? status, AuthUser? user, String? message}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      message: message,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/auth/login',
            data: {
              'username': email.trim().toLowerCase(),
              'password': password,
            },
          );

      final data = response.data ?? {};
      final accessToken = data['accessToken'] as String? ?? '';
      final refreshToken = data['refreshToken'] as String?;
      final userJson = data['user'];

      if (accessToken.isEmpty || userJson is! Map<String, dynamic>) {
        throw AppException('Invalid authentication response.');
      }

      ref
          .read(authTokenStoreProvider)
          .save(accessToken: accessToken, refreshToken: refreshToken);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _parseUser(userJson),
      );
    } on AppException catch (error) {
      ref.read(authTokenStoreProvider).clear();
      state = AuthState(
        status: AuthStatus.unauthenticated,
        message: error.message,
      );
    } catch (_) {
      ref.read(authTokenStoreProvider).clear();
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        message: 'Unable to sign in right now.',
      );
    }
  }

  void expireSession() {
    ref.read(authTokenStoreProvider).clear();
    state = const AuthState(
      status: AuthStatus.expired,
      message: 'Your session expired. Please sign in again.',
    );
  }

  Future<void> logout() async {
    try {
      await ref.read(apiClientProvider).post('/auth/logout');
    } catch (_) {}
    ref.read(authTokenStoreProvider).clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  AuthUser _parseUser(Map<String, dynamic> json) {
    final roleValues = (json['roles'] as List? ?? const [])
        .whereType<String>()
        .map(_roleFromValue)
        .whereType<AppRole>()
        .toList();
    final permissions = (json['permissions'] as List? ?? const [])
        .whereType<String>()
        .toSet();

    return AuthUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      mustChangePassword: json['mustChangePassword'] == true,
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      status: json['status'] as String? ?? 'INACTIVE',
      roles: roleValues,
      permissions: permissions,
    );
  }

  AppRole? _roleFromValue(String value) {
    for (final role in AppRole.values) {
      if (role.value == value) {
        return role;
      }
    }
    return null;
  }
}
