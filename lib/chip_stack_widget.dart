import 'package:flutter/material.dart';

class ChipStackWidget extends StatelessWidget {
  final int amount;

  const ChipStackWidget({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    // Simple representation of chips. A more complex version could show different chip values.
    const chipHeight = 2.0;
    const chipsInStack = 5;
    final numChips = (amount / 25).clamp(1, 20).toInt(); // Example: 1 chip per 25 currency, max 20 chips
    final numStacks = (numChips / chipsInStack).ceil();

    return LayoutBuilder(builder: (context, constraints) {
      final chipRadius = constraints.maxWidth / 2.5;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: chipRadius * 2,
            width: chipRadius * 2,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(numStacks, (i) {
                return Positioned(
                  left: i * chipRadius * 0.3, // Stagger the stacks
                  child: SizedBox(
                    height: chipRadius * 2,
                    width: chipRadius * 2,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: List.generate(chipsInStack, (j) {
                        if (i * chipsInStack + j >= numChips) return const SizedBox.shrink();
                        return Positioned(
                          bottom: j * chipHeight,
                          child: CircleAvatar(radius: chipRadius, backgroundColor: Colors.red.shade800),
                        );
                      }),
                    ),
                  ),
                );
              }),
            ),
          ),
          Text(amount.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2)])),
        ],
      );
    });
  }
}