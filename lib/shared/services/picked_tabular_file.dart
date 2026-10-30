import 'dart:typed_data';

class PickedTabularFile {
  const PickedTabularFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
