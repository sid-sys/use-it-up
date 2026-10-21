// Makes the App Store screenshots: a headline, a phone frame with a real app screen inside,
// and a floating callout card. Run it with:
//   flutter test tool/store_shots/make_store_shots_test.dart
// Raw phone screenshots go in tool/store_shots/raw/ (720x1612). Results go to store_screenshots/.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 1179.0; // App Store size for 6.1" iPhones: 1179 x 2556
const _h = 2556.0;
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
  final double top;
  final Color iconBg;
  const _Callout(this.icon, this.big, this.small, {this.left, this.right, required this.top, this.iconBg = _lime});
}

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

void main() {
  testWidgets('make the store screenshots', (tester) async {
    tester.view.physicalSize = const Size(_w, _h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadFonts);
    Directory('store_screenshots').createSync(recursive: true);

    for (final s in _shots) {
      final file = File('tool/store_shots/raw/${s.raw}.png');
      if (!file.existsSync()) {
        // ignore: avoid_print
        print('skipped ${s.out}: tool/store_shots/raw/${s.raw}.png not found');
        continue;
      }
      late ui.Image screen;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        screen = (await codec.getNextFrame()).image;
      });
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: _ivory,
          child: DefaultTextStyle(
            style: const TextStyle(decoration: TextDecoration.none),
            child: RepaintBoundary(key: key, child: _Poster(shot: s, screen: screen)),
          ),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 1);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('store_screenshots/${s.out}.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}

class _Poster extends StatelessWidget {
  final _Shot shot;
  final ui.Image screen;
  const _Poster({required this.shot, required this.screen});

  @override
  Widget build(BuildContext context) {
    // The whole phone is shown, with rounded corners at the bottom too.
    const bezel = 18.0;
    const phoneW = 880.0;
    const screenW = phoneW - bezel * 2;
    const screenH = screenW * 1532 / 720; // the Android bar at the bottom is cropped off
    const phoneH = screenH + bezel * 2;
    const phoneTop = 650.0;
    const k = screenW / 974; // everything inside the screen is drawn at this scale
    return Container(
      width: _w,
      height: _h,
      color: _ivory,
      child: ClipRect(
        child: Stack(children: [
          // soft brand colour behind the phone
          Positioned(
            left: -240,
            top: 1250,
            child: Container(width: 900, height: 900, decoration: BoxDecoration(color: _lime.withValues(alpha: .55), shape: BoxShape.circle)),
          ),
          Positioned(
            right: -300,
            top: 560,
            child: Container(width: 700, height: 700, decoration: BoxDecoration(color: _lime.withValues(alpha: .35), shape: BoxShape.circle)),
          ),
          // headline
          Positioned(
            top: 110,
            left: 60,
            right: 60,
            child: Column(children: [
              Text(shot.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Anton', fontSize: 150, height: 1.02, color: _charcoal)),
              const SizedBox(height: 22),
              Text(shot.sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 50, fontWeight: FontWeight.w500, color: Color(0xFF55574F))),
            ]),
          ),
          // the phone
          Positioned(
            top: phoneTop,
            left: (_w - phoneW) / 2,
            child: Container(
              width: phoneW,
              height: phoneH,
              padding: const EdgeInsets.all(bezel),
              decoration: BoxDecoration(
                color: const Color(0xFF111210),
                borderRadius: BorderRadius.circular(135),
                border: Border.all(color: const Color(0xFF3A3C36), width: 4),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 80, offset: const Offset(0, 36))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(117),
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
          if (shot.callout != null) _CalloutCard(c: shot.callout!),
        ]),
      ),
    );
  }
}

class _CalloutCard extends StatelessWidget {
  final _Callout c;
  const _CalloutCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: c.left,
      right: c.right,
      top: c.top,
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
