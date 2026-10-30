import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:request_contract/request_contract.dart';

import '../../../core/network/api_client.dart';

final requestRepositoryProvider = Provider(
  (ref) => RequestRepository(ref.watch(apiClientProvider)),
);

class RequestRepository {
  RequestRepository(this.client);
  final ApiClient client;
  Future<RequestSettings> settings() async {
    final response = await client.get<Map<String, dynamic>>(
      '/public/request-settings',
    );
    final json = response.data!;
    final catalog = <String, List<String>>{};
    for (final item in (json['institutions'] as List? ?? const [])) {
      if (item is! Map || item['name'] is! String) continue;
      catalog[item['name'] as String] = (item['programs'] as List? ?? const [])
          .whereType<String>()
          .toList();
    }
    return RequestSettings(
      institutions: catalog,
      studentRequestLimit: json['studentRequestLimit'] as int? ?? 0,
    );
  }

  Future<Verification> verify(RequestData data) async {
    final response = await client.post<Map<String, dynamic>>(
      '/public/requests/verify',
      data: data.toJson(),
    );
    final json = response.data!;
    return Verification(
      json['verificationToken'] as String,
      json['previousRequests'] as int,
      studentRequestLimit: json['studentRequestLimit'] as int? ?? 0,
      requiresFormalLetter: json['requiresFormalLetter'] == true,
    );
  }

  Future<String> submit(RequestData data, String token) async {
    final response = await client.post<Map<String, dynamic>>(
      '/public/requests',
      data: {...data.toJson(), 'verificationToken': token},
    );
    return response.data!['reference'] as String;
  }
}

class RequestSettings {
  const RequestSettings({
    required this.institutions,
    required this.studentRequestLimit,
  });

  final Map<String, List<String>> institutions;
  final int studentRequestLimit;
}

class Verification {
  const Verification(
    this.token,
    this.previousRequests, {
    this.studentRequestLimit = 0,
    this.requiresFormalLetter = false,
  });
  final String token;
  final int previousRequests;
  final int studentRequestLimit;
  final bool requiresFormalLetter;
}
