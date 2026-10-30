import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/server_config.dart';
import '../database/database.dart';
import '../errors/api_error.dart';
import '../middleware/error_middleware.dart';
import '../middleware/security_headers_middleware.dart';
import '../modules/auth/auth_service.dart';
import '../modules/auth/password_hasher.dart';
import '../modules/auth/token_service.dart';
import '../modules/public/public_controller.dart';
import '../modules/support/support_routes.dart';
import '../modules/support/support_store.dart';
import '../modules/support/support_ai.dart';
import '../modules/support/support_access.dart';
import 'json_response.dart';
import '../modules/requests/request_routes.dart';
import '../modules/requests/request_store.dart';
import '../modules/admin/portal_routes.dart';

Handler buildHandler({
  required ServerConfig config,
  required Database database,
  SupportStore? supportStore,
  SupportAi? supportAi,
  SupportAccess? supportAuthorization,
  RequestStore? requestStore,
  SupportAccess? requestAuthorization,
}) {
  final router = Router();
  final loginAttempts = <DateTime>[];
  void limitLogin() {
    final now = DateTime.now();
    loginAttempts.removeWhere((t) => now.difference(t).inMinutes >= 1);
    if (loginAttempts.length >= 10) {
      throw const ApiError(
        statusCode: 429,
        message: 'Too many sign-in attempts. Try again shortly.',
      );
    }
    loginAttempts.add(now);
  }

  final publicController = const PublicController();
  final authService = AuthService(
    database: database,
    passwordHasher: const PasswordHasher(),
    tokenService: TokenService(config),
  );

  router.get('/health', (Request request) {
    return JsonResponse.ok({
      'success': true,
      'status': 'ok',
      'environment': config.environment,
    });
  });

  router.get('/api/v1/public/announcements', (Request request) {
    return JsonResponse.ok(publicController.announcements());
  });

  router.get('/api/v1/public/programs', (Request request) {
    return JsonResponse.ok(publicController.programs());
  });

  router.get('/api/v1/public/letter-template', (Request request) async {
    final environment = ServerConfig.environmentValues();
    final path = (environment['LETTER_TEMPLATE_PATH'] ?? '').isNotEmpty
        ? environment['LETTER_TEMPLATE_PATH']!
        : 'templates/formal-letter.docx';
    final file = File(path);
    if (!await file.exists()) {
      throw const ApiError(
        statusCode: 404,
        message: 'The formal letter template is not available.',
      );
    }
    return Response.ok(
      await file.readAsBytes(),
      headers: const {
        'content-type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'content-disposition': 'attachment; filename="formal-letter.docx"',
        'cache-control': 'public, max-age=3600',
      },
    );
  });

  router.post('/api/v1/auth/login', (Request request) async {
    limitLogin();
    final payload = await readPortalBody(request);
    final identifier = payload['username'] ?? payload['email'];
    if (identifier is! String || payload['password'] is! String) {
      throw const ApiError(
        statusCode: 400,
        message: 'Enter your username and password.',
      );
    }
    final email = identifier;
    final password = payload['password'] as String;
    final result = await authService.login(email: email, password: password);

    if (result['success'] == true) {
      return JsonResponse.ok(result);
    }

    return JsonResponse.unauthorized(result['message'] as String);
  });

  router.post('/api/v1/auth/logout', (Request request) async {
    final id = await supportAccess(
      database,
      TokenService(config),
      permission: '',
      allowPasswordChange: true,
    )(request);
    await authService.logout(id);
    return JsonResponse.ok({'success': true});
  });

  router.post('/api/v1/auth/refresh', (Request request) {
    return JsonResponse.ok(publicController.notImplementedYet('Token refresh'));
  });

  router.get('/api/v1/auth/me', (Request request) async {
    final id = await supportAccess(
      database,
      TokenService(config),
      permission: '',
      allowPasswordChange: true,
    )(request);
    return JsonResponse.ok(await authService.profile(id));
  });

  router.post('/api/v1/auth/credentials', (Request request) async {
    limitLogin();
    final id = await supportAccess(
      database,
      TokenService(config),
      permission: '',
      allowPasswordChange: true,
    )(request);
    await authService.credentials(id, await readPortalBody(request));
    return JsonResponse.ok({'success': true});
  });

  router.get('/api/v1/admin/students', (Request request) {
    return JsonResponse.unauthorized();
  });

  SupportRoutes(
    store: supportStore ?? PostgresSupportStore(database),
    ai: supportAi ?? SupportAi(config),
    authorize:
        supportAuthorization ?? supportAccess(database, TokenService(config)),
  ).register(router);

  RequestRoutes(
    store: requestStore ?? PostgresRequestStore(database),
    secret: config.jwtSecret,
    authorize:
        requestAuthorization ??
        supportAccess(
          database,
          TokenService(config),
          permission: 'manage_requests',
        ),
  ).register(router);

  PortalRoutes(database, config).register(router);

  router.all('/<ignored|.*>', (Request request) {
    return Response.notFound(
      jsonEncode({'success': false, 'message': 'Route not found.'}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });

  final corsHeaderValues = {
    ACCESS_CONTROL_ALLOW_ORIGIN: config.allowedOrigins.isEmpty
        ? '*'
        : config.allowedOrigins.first,
    ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    ACCESS_CONTROL_ALLOW_HEADERS: 'Origin, Content-Type, Authorization',
  };

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(securityHeadersMiddleware())
      .addMiddleware(corsHeaders(headers: corsHeaderValues))
      .addMiddleware(safeErrorMiddleware())
      .addHandler(router.call);
}
