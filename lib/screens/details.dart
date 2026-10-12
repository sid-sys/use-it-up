import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'food_card.dart';
import 'form.dart';

class DetailsScreen extends StatelessWidget {
  final FoodItem item;
  const DetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final d = item.daysLeft();
        return Scaffold(
          appBar: AppBar(),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  Expanded(child: Text('${emojiFor(item.name)} ${item.name.toUpperCase()}', style: display(36))),
                  if (item.isExpired) const ExpiredStamp(size: 20),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(20)),
                  child: Column(children: [
                    _Row('Expiry date', DateFormat('EEE, d MMM yyyy').format(item.expiry)),
                    _Row('Status', daysLabel(d)),
                    _Row('Quantity', '${item.quantity}'),
                    if (item.storage != null) _Row('Kept in', item.storage!),
                    _Row('Reminders', store.prefs.threeDays || store.prefs.oneDay || store.prefs.onDay ? 'On' : 'Off'),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dates on labels are a guide. Always check the label and the food itself.',
                  style: body(13, FontWeight.w400, Colors.black54),
                ),
                const SizedBox(height: 24),
                if (!item.used)
                  FilledButton.icon(
                    style: limeButton(),
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      await store.markUsed(item);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    label: const Text('Mark as used'),
                  )
                else
                  FilledButton.icon(
                    style: limeButton(),
                    icon: const Icon(Icons.undo),
                    onPressed: () async {
                      await store.restoreItem(item);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    label: const Text('Move back to Home'),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: charcoal,
                    side: const BorderSide(color: charcoal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => FoodFormScreen(existing: item))),
                  label: const Text('Edit'),
                ),
                const SizedBox(height: 28),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: redDark),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete this food?'),
                          content: const Text('This removes it for good. It will not count as used.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Delete', style: TextStyle(color: redDark))),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await store.delete(item);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final String k;
  final String v;
  const _Row(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: body(15, FontWeight.w400, Colors.black54)),
        Text(v, style: body(16, FontWeight.w700)),
      ]),
    );
  }
}
