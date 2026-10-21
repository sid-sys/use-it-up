import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../billing.dart';
import '../config.dart';
import '../main.dart';
import '../theme.dart';
import 'paywall.dart' show restorePurchasesWithFeedback;
import 'profile.dart' show openUrl;

/// "We'll send you a reminder before your trial ends." Shown after "Start 7-day free trial",
/// before the store's own purchase box. The reminder is real: [Billing] plans a notification
/// two days before the trial ends.
class TrialReminderScreen extends StatelessWidget {
  final PlanKind plan;
  const TrialReminderScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final price = billing.priceFor(plan);
    final then = plan == PlanKind.monthly
        ? '${AppConfig.trialDays} days free, then ${price.replaceFirst(' / month', ' per month')}'
        : '${AppConfig.trialDays} days free, then ${price.replaceFirst(' / year', ' per year')}'
            '${billing.storePricesLoaded ? '' : ' (${AppConfig.money(double.parse((AppConfig.yearlyPrice / 12).toStringAsFixed(2)))}/mo)'}';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: cardWhite, foregroundColor: charcoal),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(height: 8),
            Text("WE'LL SEND YOU A\nREMINDER BEFORE\nYOUR TRIAL ENDS", textAlign: TextAlign.center, style: display(34)),
            const Expanded(child: Center(child: SizedBox(width: 250, height: 250, child: CustomPaint(painter: _BellPainter())))),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check, size: 22),
              const SizedBox(width: 8),
              Text('No commitment, cancel anytime', style: body(16, FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            FilledButton(style: darkButton(), onPressed: () => Navigator.of(context).pop(true), child: const Text('Continue')),
            const SizedBox(height: 10),
            Text(then, textAlign: TextAlign.center, style: body(13.5, FontWeight.w500, Colors.black54)),
            const SizedBox(height: 2),
            Wrap(alignment: WrapAlignment.center, children: [
              TextButton(onPressed: () => openUrl(context, AppConfig.termsUrl), child: Text('Terms of Use', style: body(13, FontWeight.w600).copyWith(decoration: TextDecoration.underline))),
              TextButton(onPressed: () => restorePurchasesWithFeedback(context), child: Text('Restore', style: body(13, FontWeight.w600).copyWith(decoration: TextDecoration.underline))),
              TextButton(onPressed: () => openUrl(context, AppConfig.privacyUrl), child: Text('Privacy Policy', style: body(13, FontWeight.w600).copyWith(decoration: TextDecoration.underline))),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// A friendly bell with a face, drawn in the app's colours: a round dome that flares out at the
/// bottom, a rim, a little knob on top and a clapper underneath.
class _BellPainter extends CustomPainter {
  const _BellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final light = Paint()..color = lime;
    final dark = Paint()..color = const Color(0xFFB7DD2E);

    // Knob on top, joined to the dome
    canvas.drawCircle(Offset(w * .5, h * .12), w * .05, dark);
    canvas.drawRect(Rect.fromLTWH(w * .47, h * .12, w * .06, h * .08), dark);

    // Body: a round dome, then the sides flare outwards at the bottom
    final body = Path()
      ..moveTo(w * .5, h * .17)
      ..cubicTo(w * .78, h * .17, w * .79, h * .50, w * .79, h * .62)
      ..cubicTo(w * .79, h * .70, w * .86, h * .72, w * .90, h * .78)
      ..lineTo(w * .10, h * .78)
      ..cubicTo(w * .14, h * .72, w * .21, h * .70, w * .21, h * .62)
      ..cubicTo(w * .21, h * .50, w * .22, h * .17, w * .5, h * .17)
      ..close();
    canvas.drawPath(body, light);

    // Shade on the right side of the body
    canvas.save();
    canvas.clipPath(body);
    final shade = Path()
      ..moveTo(w * .62, h * .17)
      ..cubicTo(w * .74, h * .22, w * .76, h * .50, w * .74, h * .78)
      ..lineTo(w * .95, h * .78)
      ..lineTo(w * .95, h * .1)
      ..close();
    canvas.drawPath(shade, dark);
    canvas.restore();

    // Rim (a rounded bar along the bottom edge)
    final rim = RRect.fromRectAndRadius(Rect.fromLTWH(w * .08, h * .76, w * .84, h * .075), Radius.circular(h * .04));
    canvas.drawRRect(rim, light);
    canvas.save();
    canvas.clipRRect(rim);
    canvas.drawRect(Rect.fromLTWH(w * .66, h * .76, w * .30, h * .08), dark);
    canvas.restore();

    // Clapper under the rim
    final clapper = Path()
      ..addArc(Rect.fromCenter(center: Offset(w * .5, h * .835), width: w * .2, height: h * .17), 0, math.pi);
    canvas.drawPath(clapper, dark);

    // Shine: two soft marks on the left of the dome
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .022
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(w * .27, h * .26, w * .14, h * .24), math.pi * .95, math.pi * .55, false, shine);
    canvas.drawCircle(Offset(w * .26, h * .54), w * .01, Paint()..color = Colors.white.withValues(alpha: .75));

    // Face: two eyes with a small shine, a smile, soft cheeks
    final ink = Paint()..color = charcoal;
    canvas.drawCircle(Offset(w * .40, h * .52), w * .026, ink);
    canvas.drawCircle(Offset(w * .60, h * .52), w * .026, ink);
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * .405, h * .512), w * .008, white);
    canvas.drawCircle(Offset(w * .605, h * .512), w * .008, white);
    canvas.drawArc(Rect.fromLTWH(w * .455, h * .535, w * .09, h * .06), 0.15, math.pi - 0.3, false,
        Paint()
          ..color = charcoal
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .014
          ..strokeCap = StrokeCap.round);
    final cheek = Paint()..color = const Color(0xFFFF9E80).withValues(alpha: .55);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .33, h * .565), width: w * .06, height: h * .035), cheek);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .67, h * .565), width: w * .06, height: h * .035), cheek);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
