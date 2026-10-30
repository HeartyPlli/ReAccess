import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void saveDownload(
  Uint8List bytes,
  String name,
  String mime, {
  bool preview = false,
}) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  if (preview) {
    final opened = web.window.open(url, '_blank');
    if (opened == null) {
      _download(url, name);
    }
  } else {
    _download(url, name);
  }
  // Keep the blob available while the browser PDF viewer reads it.
  Future.delayed(
    const Duration(minutes: 5),
    () => web.URL.revokeObjectURL(url),
  );
}

void _download(String url, String name) {
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(link);
  link.click();
  link.remove();
}
