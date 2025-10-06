import 'dart:math';
import 'package:flutter/material.dart';

class GameBoardWidget extends StatelessWidget {
  final int playerCount;
  final String? gameId;

  const GameBoardWidget({
    super.key,
    this.playerCount = 9,
    this.gameId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make the table width responsive to the available space, maintaining an aspect ratio.
        final double tableWidth = constraints.maxWidth * 0.9;
        final double tableHeight = tableWidth * (200.0 / 350.0); // Maintain aspect ratio
        final double seatRadius = tableWidth / 14; // Scale seat size with table

        // The total width and height of the widget including seats
        final double totalWidth = tableWidth + seatRadius * 2;
        final double totalHeight = tableHeight + seatRadius * 2;

        // Generate player seat widgets
        final List<Widget> playerSeats = List.generate(playerCount, (index) {
          // Calculate position for each seat around an ellipse
          // We add pi/2 to start the first player at the bottom center
          final double angle = (index / playerCount) * 2 * pi + (pi / 2);

          // The ellipse radii for placing the seats
          final double xRadius = tableWidth / 2;
          final double yRadius = tableHeight / 2;

          final double x = xRadius * cos(angle);
          final double y = yRadius * sin(angle);

          return Positioned(
            left: (totalWidth / 2) + x - seatRadius,
            top: (totalHeight / 2) + y - seatRadius,
            child: CircleAvatar(
              radius: seatRadius,
              backgroundColor: Colors.blueGrey,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'S${index + 1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        });

        return Center(
          child: Container(
            width: totalWidth,
            height: totalHeight,
            margin: const EdgeInsets.symmetric(vertical: 20.0),
            child: Stack(
              children: [
                // The table itself
                Center(
                  child: Container(
                    width: tableWidth,
                    height: tableHeight,
                    decoration: BoxDecoration(
                      color: Colors.green.shade800,
                      borderRadius: BorderRadius.circular(tableHeight / 2), // Oval shape
                      border: Border.all(color: Colors.brown.shade800, width: 10),
                    ),
                    child: gameId != null
                        ? Center(
                            child: Text(
                              gameId!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                // The player seats overlaid on the table
                ...playerSeats,
              ],
            ),
          ),
        );
      },
    );
  }
}