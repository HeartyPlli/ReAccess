import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'picked_tabular_file.dart';

Future<PickedTabularFile?> pickTabularFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,.xlsx';
  final changed = Completer<void>();
  input.addEventListener(
    'change',
    ((web.Event _) {
      if (!changed.isCompleted) changed.complete();
    }).toJS,
  );
  input.click();
  await changed.future;
  final file = input.files?.item(0);
  if (file == null) return null;
  final arrayBuffer = await file.arrayBuffer().toDart;
  return PickedTabularFile(file.name, Uint8List.view(arrayBuffer.toDart));
}
