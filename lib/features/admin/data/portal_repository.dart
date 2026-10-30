import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final portalDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, path) async {
      return (await ref
              .watch(apiClientProvider)
              .get<Map<String, dynamic>>('/admin/portal/$path'))
          .data!;
    });
Future<Uint8List> portalDownload(WidgetRef ref, String path) async {
  final response = await ref
      .read(apiClientProvider)
      .dio
      .get<List<int>>(
        '/admin/portal/$path',
        options: Options(responseType: ResponseType.bytes),
      );
  return Uint8List.fromList(response.data!);
}

Future<Map<String, dynamic>> portalPost(
  WidgetRef ref,
  String path,
  Map<String, dynamic> data,
) async =>
    (await ref
            .read(apiClientProvider)
            .post<Map<String, dynamic>>('/admin/portal/$path', data: data))
        .data!;
