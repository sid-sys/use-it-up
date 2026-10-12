// ignore_for_file: avoid_print
// Builds app icon, adaptive-icon foreground, notification icon and splash logo
// from assets/brand/icon_source.webp. Run:  dart run tool/make_assets.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const limeR = 207, limeG = 250, limeB = 97; // brand lime #CFFA61
const darkR = 33; // charcoal red channel, for edge alpha

// Measured from the source art (1254x1254): the lime rounded square.
const L = 182, R = 1072, T = 151, B = 1099;
const radius = 205;

bool insideShape(num x, num y, {num inset = 4}) {
  final l = L + inset, r = R - inset, t = T + inset, b = B - inset, rad = radius - inset;
  if (x < l || x > r || y < t || y > b) return false;
  final cx = x < l + rad ? l + rad : (x > r - rad ? r - rad : x);
  final cy = y < t + rad ? t + rad : (y > b - rad ? b - rad : y);
  final dx = x - cx, dy = y - cy;
  return dx * dx + dy * dy <= rad * rad;
}

void save(String path, img.Image im) {
  File(path).createSync(recursive: true);
  File(path).writeAsBytesSync(img.encodePng(im));
  print('wrote $path ${im.width}x${im.height}');
}

void main() {
  final src = img.decodeImage(File('assets/brand/icon_source.webp').readAsBytesSync())!;

  // Square crop of the lime shape, with everything outside the rounded corners painted lime.
  const side = R - L; // 890
  const top = T + (B - T - side) ~/ 2;
  final full = img.Image(width: side, height: side, numChannels: 4);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final sx = L + x, sy = top + y;
      if (insideShape(sx, sy, inset: 14)) {
        final p = src.getPixel(sx, sy);
        full.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
      } else {
        full.setPixelRgba(x, y, limeR, limeG, limeB, 255);
      }
    }
  }

  // 1) Full-bleed square icon (Android legacy + iOS). iOS adds its own rounded mask.
  save('assets/brand/icon_full.png', img.copyResize(full, width: 1024, height: 1024, interpolation: img.Interpolation.cubic));

  // 2) Mark on transparent background: lime becomes transparent.
  final mark = img.Image(width: side, height: side, numChannels: 4);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final p = full.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
      if (r > limeR + 12 && sat < 60) {
        mark.setPixelRgba(x, y, r, g, b, 255); // beige clock face stays
      } else {
        final a = ((limeR - r) / (limeR - darkR)).clamp(0.0, 1.0);
        if (a < 0.04) {
          mark.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          mark.setPixelRgba(x, y, 33, 39, 30, (a * 255).round());
        }
      }
    }
  }

  // Bounding box of the mark.
  var minX = side, maxX = 0, minY = side, maxY = 0;
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      if (mark.getPixel(x, y).a > 20) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
  }
  final markW = maxX - minX + 1, markH = maxY - minY + 1;
  final cropped = img.copyCrop(mark, x: minX, y: minY, width: markW, height: markH);
  print('mark bbox ${markW}x$markH');

  // Place the mark centered on a square canvas, scaled so its longest side is [frac] of it.
  img.Image onCanvas(int size, double frac) {
    final scale = size * frac / math.max(markW, markH);
    final w = (markW * scale).round(), h = (markH * scale).round();
    final scaled = img.copyResize(cropped, width: w, height: h, interpolation: img.Interpolation.cubic);
    final c = img.Image(width: size, height: size, numChannels: 4);
    img.compositeImage(c, scaled, dstX: (size - w) ~/ 2, dstY: (size - h) ~/ 2);
    return c;
  }

  // Android adaptive icon foreground: keep inside the central 61% safe zone.
  save('assets/brand/icon_foreground.png', onCanvas(1024, 0.50));

  // Splash logo (Android 12+): same mark, a bit larger.
  save('assets/brand/splash_mark.png', onCanvas(1152, 0.58));

  // Rounded lime square with transparent corners, for the older native splash.
  final rounded = img.Image(width: side, height: side, numChannels: 4);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      if (insideShape(L + x, top + y, inset: 3)) {
        final p = full.getPixel(x, y);
        rounded.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
      }
    }
  }
  save('assets/brand/splash_icon.png', img.copyResize(rounded, width: 512, height: 512, interpolation: img.Interpolation.cubic));

  // 3) Notification small icon: white silhouette on transparent. Android tints these.
  final sil = img.Image(width: markW, height: markH, numChannels: 4);
  for (var y = 0; y < markH; y++) {
    for (var x = 0; x < markW; x++) {
      final p = cropped.getPixel(x, y);
      final isDark = p.r < 120;
      sil.setPixelRgba(x, y, 255, 255, 255, isDark ? p.a.toInt() : 0);
    }
  }
  final side2 = math.max(markW, markH) + 16;
  final silSq = img.Image(width: side2, height: side2, numChannels: 4);
  img.compositeImage(silSq, sil, dstX: (side2 - markW) ~/ 2, dstY: (side2 - markH) ~/ 2);
  for (final (dir, px) in [('mdpi', 24), ('hdpi', 36), ('xhdpi', 48), ('xxhdpi', 72), ('xxxhdpi', 96)]) {
    save('android/app/src/main/res/drawable-$dir/ic_stat_useitup.png',
        img.copyResize(silSq, width: px, height: px, interpolation: img.Interpolation.cubic));
  }
}
