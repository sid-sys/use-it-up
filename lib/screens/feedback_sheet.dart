import 'package:flutter/material.dart';
import '../analytics.dart';
import '../config.dart';
import '../feedback_log.dart';
import '../theme.dart';
import '../toast.dart';
import 'profile.dart' show openUrl;

/// "Send feedback or report a bug". The text is kept on this phone (so the admin panel can list it)
/// and, in a real build, the email app opens with the same text ready to send.
/// That way it reaches the developer even before a server exists.
Future<void> showFeedbackSheet(BuildContext context) async {
  final text = TextEditingController();
  var kind = 'Feedback';
  final send = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ivory,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tell us what you think', style: body(20, FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final k in const ['Feedback', 'Bug'])
              ChoiceChip(
                label: Text(k == 'Bug' ? 'Something is broken' : 'An idea or thanks'),
                selected: kind == k,
                selectedColor: lime,
                onSelected: (_) => setSheet(() => kind = k),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: text,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: kind == 'Bug' ? 'What happened? What did you expect?' : 'Your message'),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: limeButton(),
            onPressed: () => Navigator.pop(ctx, text.text.trim().isNotEmpty),
            child: Text(AppConfig.mock ? 'Send' : 'Send by email'),
          ),
        ]),
      ),
    ),
  );
  final message = text.text.trim();
  if (send != true || message.isEmpty) return;
  await FeedbackLog.instance.add(kind, message);
  Analytics.instance.log(Ev.feedbackSent, kind);
  if (AppConfig.mock) {
    toast('Thank you! Your message was saved.');
    return;
  }
  if (!context.mounted) return;
  final subject = Uri.encodeComponent(kind == 'Bug' ? 'Use It Up: bug report' : 'Use It Up: feedback');
  await openUrl(context, 'mailto:${AppConfig.contactEmail}?subject=$subject&body=${Uri.encodeComponent(message)}');
  toast('Thank you! Please press send in your email app.');
}
