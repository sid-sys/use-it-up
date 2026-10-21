import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../feedback_log.dart';
import '../theme.dart';
import 'models.dart';
import 'widgets.dart';

/// Feedback and bug reports, with a "handled" tick. The panel only reads: the tick is the one
/// thing you can change, and it is kept on this phone until a server exists.
class FeedbackScreen extends StatefulWidget {
  final List<AdminFeedback> items;
  final bool saveOnPhone; // real build: the tick is also saved in the feedback log
  const FeedbackScreen({super.key, required this.items, this.saveOnPhone = false});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _show = 'all'; // all | open | handled

  @override
  Widget build(BuildContext context) {
    final list = widget.items.where((f) => _show == 'all' || (_show == 'open' ? !f.handled : f.handled)).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    final open = widget.items.where((f) => !f.handled).length;
    return Scaffold(
      appBar: AppBar(title: const Text('FEEDBACK')),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final (k, label) in [
              ('all', 'All ${widget.items.length}'),
              ('open', 'Open $open'),
              ('handled', 'Handled ${widget.items.length - open}'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(label), selected: _show == k, selectedColor: lime, onSelected: (_) => setState(() => _show = k)),
              ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(widget.items.isEmpty ? 'No feedback yet' : 'Nothing here', style: body(15))))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final f = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        decoration: BoxDecoration(color: f.handled ? paleLime : cardWhite, borderRadius: BorderRadius.circular(16)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Tag(f.kind == 'Bug' ? 'Bug report' : 'Feedback', color: f.kind == 'Bug' ? charcoal : lime, textColor: f.kind == 'Bug' ? Colors.white : charcoal),
                                Text(f.name, style: body(13, FontWeight.w700)),
                                Text(DateFormat('d MMM, h:mm a').format(f.time), style: body(12, FontWeight.w400, muted)),
                              ]),
                              const SizedBox(height: 6),
                              Text(f.text, style: body(14.5)),
                            ]),
                          ),
                          Column(children: [
                            Checkbox(
                              value: f.handled,
                              activeColor: charcoal,
                              onChanged: (v) {
                                setState(() => f.handled = v ?? false);
                                if (widget.saveOnPhone) FeedbackLog.instance.setHandled(f.id, f.handled);
                              },
                            ),
                            Text('Handled', style: body(10.5, FontWeight.w600, muted)),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
