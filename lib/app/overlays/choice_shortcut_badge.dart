import 'package:flutter/material.dart';

const List<String> choiceShortcutLabels = <String>['J', 'K', 'L'];

final class ChoiceShortcutBadge extends StatelessWidget {
  const ChoiceShortcutBadge({required this.index, super.key});

  final int index;

  @override
  Widget build(BuildContext context) {
    final label = choiceShortcutLabels[index];
    return Semantics(
      label: label,
      button: true,
      child: Container(
        key: ValueKey<String>('choice-shortcut-$label'),
        width: 30,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x3336E1FF),
          border: Border.all(color: const Color(0xFF36E1FF)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFF4F7FF),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
