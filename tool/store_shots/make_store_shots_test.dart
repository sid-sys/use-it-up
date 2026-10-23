// Makes the store screenshots: a headline, a phone frame with a real app screen inside, and a floating
// callout card. Run it with:
//   flutter test tool/store_shots/make_store_shots_test.dart
// Raw phone screenshots go in tool/store_shots/raw/ (720x1612). Results go to store_screenshots/:
//   store_screenshots/                   App Store, iPhone 6.1": 1179 x 2556
//   store_screenshots/play_phone/        Google Play phone:      1080 x 1920 (9:16)
//   store_screenshots/play_tablet_7/     Google Play 7" tablet:  1080 x 1920 (9:16)
//   store_screenshots/play_tablet_10/    Google Play 10" tablet: 1440 x 2560 (9:16)
//   store_screenshots/play_feature_graphic.png   1024 x 500
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _unitW = 1179.0; // every poster is laid out 1179 units wide. Only the height changes.
const _ivory = Color(0xFFF4F3E9);
const _lime = Color(0xFFD7FF5A);
const _charcoal = Color(0xFF22241F);

class _Shot {
  final String raw, out, title, sub;
  final Color statusColor;
  final _Callout? callout;
  const _Shot(this.raw, this.out, this.title, this.sub, this.statusColor, [this.callout]);
}

class _Callout {
  final IconData icon;
  final String big, small;
  final double? left, right;
  final double top; // as laid out on the tall (iPhone) poster
  final Color iconBg;
  const _Callout(this.icon, this.big, this.small, {this.left, this.right, required this.top, this.iconBg = _lime});
}

class _Target {
  final String dir;
  final double width, height;
  const _Target(this.dir, this.width, this.height);
}

const _targets = <_Target>[
  _Target('store_screenshots', 1179, 2556),
  _Target('store_screenshots/play_phone', 1080, 1920),
  _Target('store_screenshots/play_tablet_7', 1080, 1920),
  _Target('store_screenshots/play_tablet_10', 1440, 2560),
];

const _ivoryScreen = Color(0xFFF4F3E9);

const _shots = <_Shot>[
  _Shot('home', '1_home', 'NEVER WASTE\nFOOD AGAIN', 'See what to eat first, at a glance', _ivoryScreen,
      _Callout(Icons.eco_rounded, '15 foods', 'all in one place', right: 36, top: 800)),
  _Shot('add', '2_add', 'ADD FOOD\nIN SECONDS', 'Pick a date with one tap', _ivoryScreen,
      _Callout(Icons.bolt_rounded, 'One tap', 'quick date buttons', left: 36, top: 508)),
  _Shot('foods', '3_foods', 'ALL YOUR FOOD,\nONE LIST', 'Search, sort and tick off what you use', _ivoryScreen,
      _Callout(Icons.search_rounded, 'Search', 'find any food fast', right: 36, top: 508)),
  _Shot('groups', '4_groups', 'KNOW WHAT TO\nEAT FIRST', 'Red dates show what needs you now', _ivoryScreen,
      _Callout(Icons.warning_amber_rounded, 'Check today', 'spinach is due', left: 36, top: 508, iconBg: Color(0xFFFFD9D2))),
  _Shot('reminders', '5_reminders', 'REMINDERS THAT\nHELP', '3 days before, 1 day before, on the day', _ivoryScreen,
      _Callout(Icons.notifications_active_rounded, 'On the day', 'never miss a date', right: 36, top: 508)),
  _Shot('paywall', '6_premium', 'GO PREMIUM,\nFREE FOR 7 DAYS', 'Unlimited foods and more scans', _ivoryScreen,
      _Callout(Icons.workspace_premium_rounded, '7-day trial', 'cancel any time', left: 36, top: 508)),
];

Future<void> _loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
  // Icons are not loaded in tests by default. Use the font that ships with the Flutter SDK.
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf').readAsBytes().then((b) => ByteData.sublistView(b)));
  await icons.load();
}

Future<ui.Image> _decode(WidgetTester tester, String path) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    image = (await codec.getNextFrame()).image;
  });
  return image;
}

/// Draws [child] at the logical size and saves it as a PNG of exactly [outW] x [outH] pixels.
Future<void> _render(WidgetTester tester, Widget child, double unitsW, double unitsH, int outW, int outH, String path) async {
  tester.view.physicalSize = Size(unitsW, unitsH);
  tester.view.devicePixelRatio = 1;
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(
      color: _ivory,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: RepaintBoundary(key: key, child: child),
      ),
    ),
  ));
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: outW / unitsW);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).createSync(recursive: true);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    if (img.width != outW || img.height != outH) print('WARNING $path is ${img.width}x${img.height}, wanted ${outW}x$outH');
  });
}

void main() {
  testWidgets('make the store screenshots', (tester) async {
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadFonts);

    for (final s in _shots) {
      final file = 'tool/store_shots/raw/${s.raw}.png';
      if (!File(file).existsSync()) {
        // ignore: avoid_print
        print('skipped ${s.out}: $file not found');
        continue;
      }
      final screen = await _decode(tester, file);
      for (final t in _targets) {
        final unitsH = (_unitW * t.height / t.width).roundToDouble();
        await _render(tester, _Poster(shot: s, screen: screen, height: unitsH), _unitW, unitsH, t.width.round(), t.height.round(), '${t.dir}/${s.out}.png');
      }
    }

    // Google Play feature graphic, 1024 x 500.
    final home = File('tool/store_shots/raw/home.png');
    if (home.existsSync()) {
      final screen = await _decode(tester, home.path);
      final logo = await _decode(tester, 'assets/brand/splash_icon.png');
      await _render(tester, _FeatureGraphic(screen: screen, logo: logo), 1024, 500, 1024, 500, 'store_screenshots/play_feature_graphic.png');
    }
  });
}

class _Poster extends StatelessWidget {
  final _Shot shot;
  final ui.Image screen;
  final double height; // in layout units (the width is always 1179)
  const _Poster({required this.shot, required this.screen, required this.height});

  @override
  Widget build(BuildContext context) {
    // The whole phone is shown, with rounded corners at the bottom too.
    final tall = height / _unitW > 2.0; // the iPhone poster. The Google Play posters are 9:16 and a little shorter.
    const bezel = 18.0;
    final titleSize = tall ? 150.0 : 124.0;
    final subSize = tall ? 50.0 : 44.0;
    final titleTop = tall ? 110.0 : 80.0;
    final phoneTop = tall ? 650.0 : 590.0;
    // The phone is as wide as the room allows.
    final phoneW = tall ? 880.0 : ((height - phoneTop - 50 - bezel * 2) / (1532 / 720) + bezel * 2).clamp(500.0, 880.0);
    final screenW = phoneW - bezel * 2;
    final screenH = screenW * 1532 / 720; // the Android bar at the bottom is cropped off
    final phoneH = screenH + bezel * 2;
    final k = screenW / 974; // everything inside the screen is drawn at this scale
    final phoneScale = phoneW / 880;

    return Container(
      width: _unitW,
      height: height,
      color: _ivory,
      child: ClipRect(
        child: Stack(children: [
          // soft brand colour behind the phone
          Positioned(
            left: -240,
            top: height - 1300,
            child: Container(width: 900, height: 900, decoration: BoxDecoration(color: _lime.withValues(alpha: .55), shape: BoxShape.circle)),
          ),
          Positioned(
            right: -300,
            top: 560,
            child: Container(width: 700, height: 700, decoration: BoxDecoration(color: _lime.withValues(alpha: .35), shape: BoxShape.circle)),
          ),
          // headline
          Positioned(
            top: titleTop,
            left: 60,
            right: 60,
            child: Column(children: [
              Text(shot.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Anton', fontSize: titleSize, height: 1.02, color: _charcoal)),
              const SizedBox(height: 22),
              Text(shot.sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: subSize, fontWeight: FontWeight.w500, color: const Color(0xFF55574F))),
            ]),
          ),
          // the phone
          Positioned(
            top: phoneTop,
            left: (_unitW - phoneW) / 2,
            child: Container(
              width: phoneW,
              height: phoneH,
              padding: const EdgeInsets.all(bezel),
              decoration: BoxDecoration(
                color: const Color(0xFF111210),
                borderRadius: BorderRadius.circular(135 * phoneScale),
                border: Border.all(color: const Color(0xFF3A3C36), width: 4),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 80, offset: const Offset(0, 36))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(117 * phoneScale),
                child: SizedBox(
                  width: screenW,
                  height: screenH,
                  child: Stack(children: [
                    Positioned.fill(child: RawImage(image: screen, fit: BoxFit.cover, alignment: Alignment.topCenter)),
                    // clean iPhone-style status bar over the real one
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 118 * k,
                      child: Container(
                        color: shot.statusColor,
                        padding: EdgeInsets.only(left: 96 * k, right: 84 * k, top: 18 * k),
                        child: Row(children: [
                          Text('9:41', style: TextStyle(fontFamily: 'Inter', fontSize: 44 * k, fontWeight: FontWeight.w700, color: _charcoal)),
                          const Spacer(),
                          Icon(Icons.signal_cellular_alt_rounded, size: 46 * k, color: _charcoal),
                          SizedBox(width: 12 * k),
                          Icon(Icons.wifi_rounded, size: 46 * k, color: _charcoal),
                          SizedBox(width: 12 * k),
                          Icon(Icons.battery_full_rounded, size: 50 * k, color: _charcoal),
                        ]),
                      ),
                    ),
                    // Dynamic Island
                    Positioned(
                      top: 22 * k,
                      left: (screenW - 300 * k) / 2,
                      child: Container(
                          width: 300 * k,
                          height: 86 * k,
                          decoration: BoxDecoration(color: const Color(0xFF050505), borderRadius: BorderRadius.circular(60 * k))),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          if (shot.callout != null) _CalloutCard(c: shot.callout!, tall: tall, phoneTop: phoneTop, phoneScale: phoneScale),
        ]),
      ),
    );
  }
}

class _CalloutCard extends StatelessWidget {
  final _Callout c;
  final bool tall;
  final double phoneTop;
  final double phoneScale;
  const _CalloutCard({required this.c, required this.tall, required this.phoneTop, required this.phoneScale});

  @override
  Widget build(BuildContext context) {
    // On the tall poster the card positions were placed by hand. On a shorter poster, keep the same place
    // relative to the phone: just above its top edge, or the same distance inside it.
    final rel = c.top - 650; // distance from the phone's top edge
    final top = tall ? c.top : phoneTop + (rel >= 0 ? rel * phoneScale : rel);
    return Positioned(
      left: c.left,
      right: c.right,
      top: top,
      child: Container(
        padding: const EdgeInsets.fromLTRB(34, 28, 48, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(56),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .20), blurRadius: 60, offset: const Offset(0, 24))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(color: c.iconBg, shape: BoxShape.circle),
            child: Icon(c.icon, size: 60, color: _charcoal),
          ),
          const SizedBox(width: 28),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.big, style: const TextStyle(fontFamily: 'Anton', fontSize: 72, height: 1.05, color: _charcoal)),
            Text(c.small, style: const TextStyle(fontFamily: 'Inter', fontSize: 34, fontWeight: FontWeight.w500, color: Color(0xFF6A6C64))),
          ]),
        ]),
      ),
    );
  }
}

/// Google Play feature graphic: 1024 x 500. Brand lime, the app name, one line, and the Home screen in a phone.
class _FeatureGraphic extends StatelessWidget {
  final ui.Image screen;
  final ui.Image logo;
  const _FeatureGraphic({required this.screen, required this.logo});

  @override
  Widget build(BuildContext context) {
    const phoneW = 250.0;
    const bezel = 8.0;
    const screenW = phoneW - bezel * 2;
    const screenH = screenW * 1532 / 720;
    return Container(
      width: 1024,
      height: 500,
      color: _lime,
      child: ClipRect(
        child: Stack(children: [
          Positioned(right: -120, top: -120, child: Container(width: 420, height: 420, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .35), shape: BoxShape.circle))),
          Positioned(
            left: 64,
            top: 0,
            bottom: 0,
            width: 560,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(18), child: RawImage(image: logo, width: 64, height: 64, fit: BoxFit.cover)),
                const SizedBox(width: 16),
                const Text('Use It Up', style: TextStyle(fontFamily: 'Anton', fontSize: 40, color: _charcoal)),
              ]),
              const SizedBox(height: 20),
              const Text('NEVER WASTE\nFOOD AGAIN', style: TextStyle(fontFamily: 'Anton', fontSize: 84, height: 1.0, color: _charcoal)),
              const SizedBox(height: 16),
              const Text('Food expiry tracker with friendly reminders', style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600, color: _charcoal)),
            ]),
          ),
          // The phone is cut off at the bottom on purpose: a banner is short.
          Positioned(
            right: 78,
            top: 56,
            child: Container(
              width: phoneW,
              height: 480,
              padding: const EdgeInsets.all(bezel),
              decoration: BoxDecoration(
                color: const Color(0xFF111210),
                borderRadius: BorderRadius.circular(44),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 30, offset: const Offset(0, 14))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: SizedBox(
                  width: screenW,
                  height: screenH,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: screenH,
                    child: Stack(children: [
                      RawImage(image: screen, fit: BoxFit.cover, alignment: Alignment.topCenter, width: screenW, height: screenH),
                      // a clean status bar over the real one
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 26,
                        child: Container(
                          color: _ivory,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 18),
                          child: const Text('9:41', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: _charcoal)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
