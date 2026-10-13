import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';
import '../main.dart';
import '../scan/ocr_stub.dart' if (dart.library.io) '../scan/ocr_mobile.dart';
import '../scan/parser.dart';
import '../theme.dart';
import 'form.dart';
import 'paywall.dart';
import 'scan_camera.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  bool _busy = false;
  String? _message;
  String? _debug; // what the reader saw, to help when a scan fails

  Future<bool> _checkItemLimit() async {
    if (!store.atItemLimit) return true;
    await _openPaywall('Free plan holds ${AppConfig.freeItemLimit} foods. Upgrade to add more.');
    return false;
  }

  Future<void> _openPaywall(String reason) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => PaywallScreen(reason: reason)));
  }

  Future<void> _manual() async {
    if (!await _checkItemLimit() || !mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const FoodFormScreen()));
  }

  Future<void> _scan() async {
    if (!await _checkItemLimit() || !mounted) return;
    if (!store.canScan) {
      await _openPaywall(store.billing.isPremium
          ? 'You used all scans for this month. They reset next month.'
          : 'You used your ${AppConfig.freeScans} free scans. Premium adds ${AppConfig.premiumScansPerMonth} scans a month.');
      return;
    }
    ScanCapture? cap;
    try {
      if (kIsWeb) {
        final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 90);
        cap = x == null ? null : ScanCapture(x);
      } else {
        cap = await Navigator.of(context)
            .push<ScanCapture>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ScanCameraScreen()));
      }
    } catch (e) {
      setState(() {
        _message = 'The camera did not open. You can type the date instead.';
        _debug = '$e';
      });
      return;
    }
    if (cap == null || !mounted) return;
    final file = cap.file;
    setState(() {
      _busy = true;
      _message = null;
      _debug = null;
    });
    try {
      final bytes = await file.readAsBytes();
      if (!ocrSupported) {
        setState(() => _message = 'Photo scan works in the phone app. Please type it here.');
        return;
      }
      final out = await readLabel(file.path, bytes, frame: cap.frame);
      final lines = [...out.focus, ...out.all];
      if (!mounted) return;
      if (lines.isEmpty) {
        setState(() {
          _message = 'We could not read any text. Try again in better light, closer to the date.';
        });
        return;
      }
      final result = parseLabel(out.all, focus: out.focus);
      if (result.dates.isNotEmpty) await store.recordScan(); // failed scans do not use up a scan
      if (!mounted) return;
      // Always open the review screen so the user can fix or type the date.
      await Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => FoodFormScreen(scan: result, imageBytes: bytes)));
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Something went wrong while reading the photo. You can type it instead.';
          _debug = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ADD FOOD')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _busy
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: charcoal),
                  SizedBox(height: 16),
                  Text('Reading the label...'),
                ]))
              : ListView(children: [
                  _BigChoice(
                    color: lime,
                    icon: Icons.photo_camera_outlined,
                    title: 'Scan expiry date',
                    sub: store.billing.isPremium
                        ? '${store.scansLeft} scans left this month'
                        : '${store.scansLeft} free scans left',
                    onTap: _scan,
                  ),
                  const SizedBox(height: 14),
                  _BigChoice(
                    color: cardWhite,
                    icon: Icons.edit_outlined,
                    title: 'Enter manually',
                    sub: 'Type the name and pick the date',
                    onTap: _manual,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(14)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_message!, style: body(15))),
                        ]),
                        if (_debug != null) ...[
                          const SizedBox(height: 8),
                          SelectableText('Error: $_debug', style: body(12, FontWeight.w400, Colors.black54)),
                        ],
                      ]),
                    ),
                  ],
                ]),
        ),
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _BigChoice({required this.color, required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            Icon(icon, size: 40),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title.toUpperCase(), style: display(26)),
                const SizedBox(height: 4),
                Text(sub, style: body(14)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}
