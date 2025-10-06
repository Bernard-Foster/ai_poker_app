import 'package:flutter/material.dart' hide Chip;
import 'package:poker_app/chip_widget.dart';

class ChipStackWidget extends StatelessWidget {
  final int amount;
  final double chipDiameter;

  const ChipStackWidget({super.key, required this.amount, this.chipDiameter = 50});

  // Standard chip denominations
  static const List<Chip> chipDenominations = [
    Chip(value: 1000, color: Colors.orange, stripeColor: Colors.black),
    Chip(value: 500, color: Colors.purple, stripeColor: Colors.white),
    Chip(value: 100, color: Colors.black, stripeColor: Colors.white),
    Chip(value: 25, color: Colors.green, stripeColor: Colors.white),
    Chip(value: 5, color: Colors.red, stripeColor: Colors.white),
    Chip(value: 1, color: Colors.white, stripeColor: Colors.blue),
  ];

  @override
  Widget build(BuildContext context) {
    final chipsToRender = _calculateChips(amount);
    final double chipHeight = chipDiameter * 0.1; // Each chip is 10% of its diameter in height
    // Calculate the total height needed for the stack.
    // (number of overlaps * overlap_height) + one_full_chip_diameter
    final double stackHeight = chipsToRender.isEmpty ? 0 : (chipsToRender.length - 1) * chipHeight + chipDiameter;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: chipDiameter,
          height: stackHeight,
          child: Stack(
            children: List.generate(chipsToRender.length, (index) {
              final chip = chipsToRender[index];
              return Positioned(
                bottom: index * chipHeight,
                child: ChipWidget(chip: chip, diameter: chipDiameter),
              );
            }),
          ),
        ),
        Text(amount.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2)])),
      ],
    );
  }

  // Calculates the list of chips to represent the total amount.
  List<Chip> _calculateChips(int totalAmount) {
    List<Chip> chips = [];
    int remainingAmount = totalAmount;

    for (final denomination in chipDenominations) {
      if (remainingAmount >= denomination.value) {
        int count = remainingAmount ~/ denomination.value;
        for (int i = 0; i < count; i++) {
          chips.add(denomination);
        }
        remainingAmount %= denomination.value;
      }
    }
    // To keep stack size reasonable, we can clamp it.
    if (chips.length > 15) {
      chips = chips.sublist(0, 15);
    }
    return chips.isEmpty && totalAmount > 0 ? [chipDenominations.last] : chips;
  }
}