// Makes a fully transparent PNG. The native splash uses it so no logo shows there.
// Run: dart run tool/make_blank.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final blank = img.Image(width: 48, height: 48, numChannels: 4);
  File('assets/brand/blank.png').writeAsBytesSync(img.encodePng(blank));
}
