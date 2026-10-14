import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'details.dart';

const expiredTint = Color(0xFFEAF2D2);

/// One tap from the card. A snackbar offers Undo for a few seconds.
void markUsedWithUndo(BuildContext context, FoodItem item) {
  final messenger = ScaffoldMessenger.of(context);
  store.markUsed(item);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('${item.name} marked as used'),
      persist: false, // a snackbar with an action otherwise stays until dismissed
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: 'Undo', onPressed: () => store.restoreItem(item)),
    ));
}

/// Name on top, then date and tag, then status. Only the tick sits on the right,
/// so long names such as "Strawberries" are never cut off.
class FoodCard extends StatelessWidget {
  final FoodItem item;
  const FoodCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final d = item.daysLeft();
    final expired = item.isExpired;
    final (icon, color) = switch (urgencyOf(d)) {
      Urgency.expired => (Icons.error_outline, redDark),
      Urgency.today => (Icons.warning_amber_rounded, redDark),
      Urgency.soon => (Icons.schedule, redDark),
      Urgency.later => (Icons.event_outlined, charcoal),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: expired ? expiredTint : cardWhite,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(item: item))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: expired ? cardWhite : ivory, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(emojiFor(item.name), style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.quantity > 1 ? '${item.name}  ×${item.quantity}' : item.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: body(17, FontWeight.w700)),
                  const SizedBox(height: 2),
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(DateFormat('d MMM yyyy').format(item.expiry),
                        style: item.isUrgent
                            ? body(14, FontWeight.w700, redDark)
                            : body(14, FontWeight.w400, Colors.black54)),
                    if (item.storage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: ivory, borderRadius: BorderRadius.circular(8)),
                        child: Text(item.storage!, style: body(11, FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  if (item.used)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle, size: 17),
                      const SizedBox(width: 4),
                      Text('Used', style: body(13, FontWeight.w700)),
                    ])
                  else if (expired)
                    const ExpiredStamp()
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 17, color: color),
                      const SizedBox(width: 4),
                      Text(daysLabel(d), style: body(13, FontWeight.w700, color)),
                    ]),
                ]),
              ),
              if (!item.used)
                IconButton(
                  tooltip: 'Mark as used',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.check_circle_outline, size: 28),
                  onPressed: () => markUsedWithUndo(context, item),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Red rubber-stamp look. Word plus border, so it never relies on color alone.
class ExpiredStamp extends StatelessWidget {
  final double size;
  const ExpiredStamp({super.key, this.size = 15});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -math.pi / 40,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.5, vertical: size * 0.15),
        decoration: BoxDecoration(
          border: Border.all(color: redDark, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('EXPIRED', style: display(size, redDark).copyWith(letterSpacing: 1.5)),
      ),
    );
  }
}
