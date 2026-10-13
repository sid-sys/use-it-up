import 'package:flutter/material.dart';
import '../theme.dart';
import '../config.dart';
import '../main.dart';
import 'add.dart';
import 'paywall.dart';

/// The one big primary action. Shown on Home and on Foods.
class AddFoodButton extends StatelessWidget {
  const AddFoodButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: lime,
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (store.atItemLimit) {
              Navigator.of(context).push(MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => PaywallScreen(reason: 'Free plan holds ${AppConfig.freeItemLimit} foods. Upgrade to add more.')));
            } else {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddScreen()));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: charcoal, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: lime, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('Add food', style: body(17, FontWeight.w800)),
                  Text('Scan a label or enter a date', style: body(12.5)),
                ]),
              ),
              const Icon(Icons.photo_camera_outlined),
            ]),
          ),
        ),
      ),
    );
  }
}
