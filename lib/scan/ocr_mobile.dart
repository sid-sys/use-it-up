import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

bool get ocrSupported => true;

class OcrOutput {
  /// Lines found in the scan frame, after crop and contrast boost.
  final List<String> focus;

  /// Lines found in the whole photo.
  final List<String> all;
  OcrOutput(this.focus, this.all);
}

/// On-device OCR (Google ML Kit). The photo never leaves the phone.
/// [frame] is [screenW, screenH, left, top, width, height] of the scan frame on screen.
/// Passes: (1) cropped + contrast boosted, (2) the same inverted for light-on-dark print,
/// (3) the whole original photo.
Future<OcrOutput> readLabel(String path, Uint8List bytes, {List<double>? frame}) async {
  final prepared = await Isolate.run(() => _prepare(bytes, frame));
  final dir = await Directory.systemTemp.createTemp('ocr');
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    Future<List<String>> run(String p) async {
      final r = await recognizer.processImage(InputImage.fromFilePath(p));
      return [for (final b in r.blocks) for (final l in b.lines) l.text];
    }

    final focus = <String>[];
    for (var i = 0; i < prepared.length; i++) {
      final f = File('${dir.path}/p$i.jpg');
      await f.writeAsBytes(prepared[i]);
      focus.addAll(await run(f.path));
    }
    final all = await run(path);
    return OcrOutput(focus, all);
  } finally {
    await recognizer.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Runs in a background isolate so the screen does not freeze.
List<Uint8List> _prepare(Uint8List bytes, List<double>? f) {
  var im = img.decodeImage(bytes);
  if (im == null) return [];
  im = img.bakeOrientation(im);

  var region = im;
  if (f != null) {
    final sw = f[0], sh = f[1], fl = f[2], ft = f[3], fw = f[4], fh = f[5];
    // The preview fills the screen (cover), so map screen pixels back to photo pixels.
    final scale = math.max(sw / im.width, sh / im.height);
    final offX = (im.width * scale - sw) / 2;
    final offY = (im.height * scale - sh) / 2;
    var w = fw / scale, h = fh / scale;
    var x = (fl + offX) / scale, y = (ft + offY) / scale;
    final padX = w * 0.06, padY = h * 0.06; // a little margin for shaky hands
    x -= padX;
    y -= padY;
    w += padX * 2;
    h += padY * 2;
    x = x.clamp(0, im.width - 2).toDouble();
    y = y.clamp(0, im.height - 2).toDouble();
    w = math.min(w, im.width - x);
    h = math.min(h, im.height - y);
    if (w > 20 && h > 20) {
      region = img.copyCrop(im, x: x.round(), y: y.round(), width: w.round(), height: h.round());
    }
  }

  // Small print needs pixels. Scale up, flatten to grey, stretch contrast.
  if (region.width < 1400) {
    region = img.copyResize(region, width: 1400, interpolation: img.Interpolation.cubic);
  }
  final grey = img.grayscale(region.clone());
  img.normalize(grey, min: 0, max: 255);
  final boosted = img.contrast(grey.clone(), contrast: 140);
  final inverted = img.invert(boosted.clone());
  return [
    Uint8List.fromList(img.encodeJpg(boosted, quality: 95)),
    Uint8List.fromList(img.encodeJpg(inverted, quality: 95)),
  ];
}
