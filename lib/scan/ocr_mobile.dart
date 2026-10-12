import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

bool get ocrSupported => true;

/// On-device OCR (Google ML Kit, works on iOS and Android). The photo never leaves the phone.
Future<List<String>> readTextFromImage(String path, Uint8List? bytes) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return [for (final b in result.blocks) for (final l in b.lines) l.text];
  } finally {
    await recognizer.close();
  }
}
