import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models.dart';
import '../scan/parser.dart';
import '../theme.dart';

/// One form for manual entry, scan review and editing. The user always confirms.
class FoodFormScreen extends StatefulWidget {
  final FoodItem? existing;
  final ScanResult? scan;
  final Uint8List? imageBytes;
  const FoodFormScreen({super.key, this.existing, this.scan, this.imageBytes});

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  late final TextEditingController _name;
  DateTime? _date;
  int _qty = 1;
  int _candidate = 0;
  String? _storage;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final s = widget.scan;
    _name = TextEditingController(text: e?.name ?? s?.name ?? '');
    _date = e?.expiry ?? (s != null && s.dates.isNotEmpty ? s.dates.first.date : null);
    _qty = e?.quantity ?? 1;
    _storage = e?.storage;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null) setState(() => _date = d);
  }

  bool get _valid => _name.text.trim().isNotEmpty && _date != null;

  Future<void> _save() async {
    final name = _name.text.trim();
    final date = DateTime(_date!.year, _date!.month, _date!.day);
    final e = widget.existing;
    if (e != null) {
      e
        ..name = name
        ..expiry = date
        ..quantity = _qty
        ..storage = _storage;
      await store.update(e);
    } else {
      await store.add(FoodItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        expiry: date,
        quantity: _qty,
        storage: _storage,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final editing = widget.existing != null;
    final cand = scan != null && scan.dates.isNotEmpty ? scan.dates[_candidate.clamp(0, scan.dates.length - 1)] : null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'EDIT FOOD' : (scan != null ? 'CHECK DETAILS' : 'NEW FOOD'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (scan != null) ...[
              if (widget.imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(widget.imageBytes!, height: 150, fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              if (cand == null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(14)),
                  child: Text('We could not find a date in the photo. Please pick it below.', style: body(14, FontWeight.w700)),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: lime.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('We read: "${cand.evidence}"', style: body(14, FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      cand.ambiguous
                          ? 'Day and month could be swapped. Please check the date below.'
                          : 'Please check it is right before you save.',
                      style: body(14),
                    ),
                  ]),
                ),
              if (scan.dates.length > 1) ...[
                const SizedBox(height: 12),
                Text('More than one date found. Pick the right one:', style: body(14, FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < scan.dates.length; i++)
                    ChoiceChip(
                      label: Text(DateFormat('d MMM yyyy').format(scan.dates[i].date)),
                      selected: i == _candidate,
                      selectedColor: lime,
                      onSelected: (_) => setState(() {
                        _candidate = i;
                        _date = scan.dates[i].date;
                      }),
                    ),
                ]),
              ],
              const SizedBox(height: 20),
            ],
            Text('Food name', style: body(14, FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              style: body(17),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'For example: Milk'),
            ),
            const SizedBox(height: 18),
            Text('Expiry date', style: body(14, FontWeight.w700)),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pick,
              child: InputDecorator(
                decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined)),
                child: Text(
                  _date == null ? 'Tap to pick a date' : DateFormat('EEE, d MMM yyyy').format(_date!),
                  style: body(17, FontWeight.w400, _date == null ? Colors.black45 : charcoal),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final (label, days) in const [('+3 days', 3), ('+1 week', 7), ('+2 weeks', 14), ('+1 month', 30)])
                ActionChip(
                  label: Text(label),
                  backgroundColor: cardWhite,
                  onPressed: () {
                    final n = DateTime.now();
                    setState(() => _date = DateTime(n.year, n.month, n.day).add(Duration(days: days)));
                  },
                ),
            ]),
            const SizedBox(height: 18),
            Text('Quantity (optional)', style: body(14, FontWeight.w700)),
            const SizedBox(height: 6),
            Row(children: [
              IconButton.filledTonal(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(width: 56, child: Center(child: Text('$_qty', style: body(20, FontWeight.w700)))),
              IconButton.filledTonal(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add)),
            ]),
            const SizedBox(height: 18),
            Text('Where is it kept? (optional)', style: body(14, FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final t in storageTags)
                ChoiceChip(
                  label: Text(t),
                  selected: _storage == t,
                  selectedColor: lime,
                  onSelected: (v) => setState(() => _storage = v ? t : null),
                ),
            ]),
            const SizedBox(height: 28),
            FilledButton(
              style: limeButton(),
              onPressed: _valid ? _save : null,
              child: const Text('Save food'),
            ),
          ],
        ),
      ),
    );
  }
}
