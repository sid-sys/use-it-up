import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'theme.dart';
import 'toast.dart';

/// Asking for a rating.
///
/// The store's own rating box (Google Play or Apple) is used in a real build. Neither store tells an
/// app whether a review was written, and both limit how often the box can appear. So the app keeps its
/// own simple rule:
///   * It asks once during onboarding.
///   * It asks again once a week, until the person taps "Rate now" or "I already rated".
class Review {
  Review._();

  static const askEvery = Duration(days: 7);
  static const _kDone = 'review_done';
  static const _kAsked = 'review_asked_at';

  static Future<bool> isDone() async => (await SharedPreferences.getInstance()).getBool(_kDone) ?? false;

  static Future<void> markDone() async => (await SharedPreferences.getInstance()).setBool(_kDone, true);

  static Future<void> markAsked([DateTime? when]) async =>
      (await SharedPreferences.getInstance()).setString(_kAsked, (when ?? DateTime.now()).toIso8601String());

  /// True when a week has passed since the last time we asked, and the person has not rated yet.
  static Future<bool> isDue([DateTime? now]) async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kDone) ?? false) return false;
    final asked = DateTime.tryParse(p.getString(_kAsked) ?? '');
    if (asked == null) {
      // First time we see this person: start counting from now, do not ask yet.
      await markAsked(now);
      return false;
    }
    return (now ?? DateTime.now()).difference(asked) >= askEvery;
  }

  /// Opens the store's rating box. A demo build shows a look-alike box so it can be tried.
  /// Returns true once the person has gone through it.
  static Future<bool> rateNow(BuildContext context) async {
    await markAsked();
    if (!context.mounted) return false;
    if (AppConfig.mock) {
      final submitted = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF1F2120),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const _DemoRatingSheet(),
      );
      if (submitted == true) await markDone();
      return submitted == true;
    }
    try {
      final r = InAppReview.instance;
      if (await r.isAvailable()) {
        await r.requestReview(); // the store decides how it looks, and whether it shows
        await markDone();
        return true;
      }
    } catch (_) {}
    toast('Ratings open once the app is in the store. Thank you!');
    return false;
  }

  /// Called when the app opens. Shows a small question if a week has passed.
  static Future<void> maybeAskWeekly(BuildContext context) async {
    if (!await isDue()) return;
    if (!context.mounted) return;
    final answer = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enjoying Use It Up?'),
        content: const Text('A rating helps other people find the app and waste less food. It takes a few seconds.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'later'), child: const Text('Not now')),
          TextButton(onPressed: () => Navigator.pop(c, 'done'), child: const Text('I already rated')),
          TextButton(onPressed: () => Navigator.pop(c, 'rate'), child: Text('Rate now', style: body(14, FontWeight.w800))),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (answer) {
      case 'rate':
        await rateNow(context);
      case 'done':
        await markDone();
      default:
        await markAsked(); // ask again in a week
    }
  }
}

/// A look-alike of the store's rating box, for demo builds.
class _DemoRatingSheet extends StatefulWidget {
  const _DemoRatingSheet();

  @override
  State<_DemoRatingSheet> createState() => _DemoRatingSheetState();
}

class _DemoRatingSheetState extends State<_DemoRatingSheet> {
  int _stars = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Image.asset('assets/brand/splash_icon.png', width: 44, height: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rate Use It Up', style: body(18, FontWeight.w700, Colors.white)),
                Text('Demo: in the real app the store shows its own rating box.', style: body(12.5, FontWeight.w400, Colors.white70)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 40,
                onPressed: () => setState(() => _stars = i),
                icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: i <= _stars ? lime : Colors.white70),
              ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: lime,
                  side: const BorderSide(color: Colors.white54),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: lime,
                  foregroundColor: charcoal,
                  disabledBackgroundColor: Colors.white12,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: _stars == 0 ? null : () => Navigator.pop(context, true),
                child: const Text('Submit'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
