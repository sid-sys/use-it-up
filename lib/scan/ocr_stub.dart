import 'dart:typed_data';

bool get ocrSupported => false;

class OcrOutput {
  final List<String> focus;
  final List<String> all;
  OcrOutput(this.focus, this.all);
}

Future<OcrOutput> readLabel(String path, Uint8List bytes, {List<double>? frame}) async => OcrOutput([], []);
