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

/// A friendly bell, drawn in the app's colours.
class _BellPainter extends CustomPainter {
  const _BellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final light = Paint()..color = lime;
    final dark = Paint()..color = const Color(0xFFB7DD2E);

    // Top knob
    canvas.drawCircle(Offset(w * .5, h * .185), w * .06, dark);
    // Dome
    final dome = Path()
      ..moveTo(w * .22, h * .72)
      ..cubicTo(w * .24, h * .50, w * .28, h * .22, w * .5, h * .2)
      ..cubicTo(w * .72, h * .22, w * .76, h * .50, w * .78, h * .72)
      ..close();
    canvas.drawPath(dome, light);
    // Shade on the right side
    final shade = Path()
      ..moveTo(w * .62, h * .24)
      ..cubicTo(w * .74, h * .32, w * .76, h * .52, w * .78, h * .72)
      ..lineTo(w * .64, h * .72)
      ..cubicTo(w * .64, h * .52, w * .64, h * .36, w * .62, h * .24)
      ..close();
    canvas.drawPath(shade, dark);
    // Rim
    final rim = RRect.fromRectAndRadius(Rect.fromLTWH(w * .12, h * .70, w * .76, h * .1), Radius.circular(h * .05));
    canvas.drawRRect(rim, light);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .62, h * .70, w * .26, h * .1), Radius.circular(h * .05)), dark);
    // Clapper
    canvas.drawCircle(Offset(w * .5, h * .86), w * .07, dark);
    // Shine
    canvas.drawArc(Rect.fromLTWH(w * .3, h * .3, w * .12, h * .2), math.pi * .9, math.pi * .6, false,
        Paint()
          ..color = Colors.white.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .022
          ..strokeCap = StrokeCap.round);
    // Face
    final ink = Paint()..color = charcoal;
    canvas.drawCircle(Offset(w * .42, h * .52), w * .025, ink);
    canvas.drawCircle(Offset(w * .58, h * .52), w * .025, ink);
    canvas.drawArc(Rect.fromLTWH(w * .45, h * .53, w * .1, h * .07), 0.2, math.pi - 0.4, false,
        Paint()
          ..color = charcoal
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .016
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
