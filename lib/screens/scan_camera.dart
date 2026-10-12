import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';

/// A captured photo plus where the scan frame was on screen, so OCR can crop to it.
class ScanCapture {
  final XFile file;
  final List<double>? frame; // [screenW, screenH, left, top, width, height]
  ScanCapture(this.file, [this.frame]);
}

/// Full-screen camera with a rounded 4-corner frame, a scan line that sweeps
/// top to bottom and back, and the app logo under the frame.
/// Pops with a [ScanCapture], or null if the user closes it.
class ScanCameraScreen extends StatefulWidget {
  const ScanCameraScreen({super.key});

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen> with SingleTickerProviderStateMixin {
  CameraController? _cam;
  String? _error;
  bool _torch = false;
  bool _busy = false;
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'No camera found on this phone.');
        return;
      }
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await c.initialize();
      try {
        await c.setFocusMode(FocusMode.auto);
      } catch (_) {}
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _cam = c);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = e.code.toLowerCase().contains('permission')
            ? 'Camera permission is off. Allow it in phone settings, or pick a photo instead.'
            : 'The camera did not start (${e.code}).');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'The camera did not start. $e');
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _cam?.dispose();
    super.dispose();
  }

  /// Scan frame in screen pixels: [screenW, screenH, left, top, width, height].
  List<double> _frame(Size size) {
    final w = size.width - 64;
    final h = w * 0.72;
    return [size.width, size.height, 32, (size.height - h) / 2 - 50, w, h];
  }

  Future<void> _shoot() async {
    final c = _cam;
    if (c == null || _busy || !c.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final f = await c.takePicture();
      if (mounted) Navigator.of(context).pop(ScanCapture(f, _frame(MediaQuery.of(context).size)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 90);
    if (f != null && mounted) Navigator.of(context).pop(ScanCapture(f));
  }

  Future<void> _toggleTorch() async {
    final c = _cam;
    if (c == null) return;
    try {
      await c.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      setState(() => _torch = !_torch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fr = _frame(size);
    final frameLeft = fr[2], frameTop = fr[3], frameW = fr[4], frameH = fr[5];
    final c = _cam;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (c != null && c.value.isInitialized)
          _Preview(controller: c)
        else
          Center(
            child: _error == null
                ? const CircularProgressIndicator(color: lime)
                : Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: body(16, FontWeight.w500, Colors.white)),
                      const SizedBox(height: 16),
                      FilledButton(style: limeButton(), onPressed: _gallery, child: const Text('Pick a photo')),
                    ]),
                  ),
          ),
        // Dim outside the frame.
        IgnorePointer(
          child: CustomPaint(
            painter: _DimPainter(Rect.fromLTWH(frameLeft, frameTop, frameW, frameH)),
            size: size,
          ),
        ),
        // Four rounded corners.
        Positioned(
          left: frameLeft,
          top: frameTop,
          width: frameW,
          height: frameH,
          child: const IgnorePointer(child: CustomPaint(painter: _CornerPainter())),
        ),
        // Scan line: top to bottom, then bottom to top.
        AnimatedBuilder(
          animation: _sweep,
          builder: (_, _) {
            final t = Curves.easeInOut.transform(_sweep.value);
            return Positioned(
              left: frameLeft + 14,
              width: frameW - 28,
              top: frameTop + 10 + t * (frameH - 20),
              height: 4,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: [lime.withValues(alpha: 0), lime, lime.withValues(alpha: 0)]),
                    boxShadow: [BoxShadow(color: lime.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 1)],
                  ),
                ),
              ),
            );
          },
        ),
        // Logo under the frame.
        Positioned(
          left: 0,
          right: 0,
          top: frameTop + frameH + 22,
          child: const IgnorePointer(child: Center(child: AppLogo())),
        ),
        // Hint.
        Positioned(
          left: 24,
          right: 24,
          top: frameTop - 54,
          child: IgnorePointer(
            child: Text('Point at the expiry date',
                textAlign: TextAlign.center, style: body(16, FontWeight.w600, Colors.white)),
          ),
        ),
        // Top bar.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Flash',
                icon: Icon(_torch ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 28),
                onPressed: _toggleTorch,
              ),
            ]),
          ),
        ),
        // Bottom controls.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(
                  tooltip: 'Pick a photo',
                  iconSize: 30,
                  color: Colors.white,
                  icon: const Icon(Icons.photo_library_outlined),
                  onPressed: _gallery,
                ),
                GestureDetector(
                  onTap: _shoot,
                  child: Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _busy ? Colors.white54 : lime),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Camera preview scaled to fill the screen (cover), not stretched.
class _Preview extends StatelessWidget {
  final CameraController controller;
  const _Preview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(scale: scale, child: Center(child: CameraPreview(controller))),
    );
  }
}

class _DimPainter extends CustomPainter {
  final Rect hole;
  const _DimPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(26))),
    );
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}

/// White rounded corner brackets, like a viewfinder.
class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 46.0, r = 26.0;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final corner = Path()
      ..moveTo(0, len)
      ..lineTo(0, r)
      ..arcTo(const Rect.fromLTWH(0, 0, r * 2, r * 2), math.pi, math.pi / 2, false)
      ..lineTo(len, 0);
    for (final (x, y, sx, sy) in [
      (0.0, 0.0, 1.0, 1.0),
      (size.width, 0.0, -1.0, 1.0),
      (0.0, size.height, 1.0, -1.0),
      (size.width, size.height, -1.0, -1.0),
    ]) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(sx, sy);
      canvas.drawPath(corner, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
