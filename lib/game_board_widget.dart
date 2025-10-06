import 'dart:math';
import 'package:flutter/material.dart' hide Card;
import 'package:poker_app/hand_history_parser.dart';
import 'package:poker_app/poker_card.dart';
import 'package:poker_app/card_widget.dart';
import 'package:poker_app/chip_stack_widget.dart';

class GameBoardWidget extends StatelessWidget {
  final int playerCount;
  final String? gameId;
  final int? buttonSeat;
  final List<Player>? players;
  final List<Bet>? bets;

  const GameBoardWidget({
    super.key,
    this.playerCount = 9,
    this.gameId,
    this.buttonSeat = 1, // Default to seat 1
    this.players,
    this.bets,
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
          // Find the player for the current seat index. Seat numbers are 1-based.
          final seatNumber = index;
          Player? player;
          try {
            player = players?.firstWhere((p) => p.seat == seatNumber);
          } catch (e) {
            player = null; // Player not found for this seat
          }
          // Calculate position for each seat around an ellipse
          // We add pi/2 to start the first player at the bottom center
          final double angle = (index / playerCount) * 2 * pi + (pi / 2);

          // The ellipse radii for placing the seats
          final double xRadius = tableWidth / 2;
          final double yRadius = tableHeight / 2;

          final double x = xRadius * cos(angle);
          final double y = yRadius * sin(angle);

          // Add a specific pixel offset for seat 2 to fix alignment
          double xOffset = 0;
          if (seatNumber == 2) {
            xOffset = 7.0;
          }

          // If no player is at this seat, show a simple seat indicator.
          if (player == null) {
            return Positioned(
              left: (totalWidth / 2) + x - seatRadius + xOffset,
              top: (totalHeight / 2) + y - seatRadius,
              child: CircleAvatar(
                radius: seatRadius,
                backgroundColor: Colors.blueGrey.withOpacity(0.5),
                child: Text(
                  'S$seatNumber',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }

          // If a player is at the seat, show their info and cards.
          return Positioned(
            // Adjust position to center the new player widget
            left: (totalWidth / 2) + x - (seatRadius * 1.5) + xOffset,
            top: (totalHeight / 2) + y - (seatRadius * 1.2),
            child: Column(
              children: [
                // Dummy Cards for the player
                Row(
                  children: [
                    SizedBox(width: seatRadius * 0.7, height: seatRadius, child: CardWidget(card: Card(suit: Suit.clubs, rank: Rank.ace))),
                    SizedBox(width: seatRadius * 0.7, height: seatRadius, child: CardWidget(card: Card(suit: Suit.spades, rank: Rank.king))),
                  ],
                ),
                const SizedBox(height: 4),
                // Player name and stack
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  constraints: BoxConstraints(maxWidth: seatRadius * 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey.shade600, width: 1),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 14, // Give a specific height for the FittedBox to work within
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            player.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          player.stack.toString(),
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });

        // Generate dealer button widget if seat is specified
        final List<Widget> dealerButton = [];
        if (buttonSeat != null && buttonSeat! > 0 && buttonSeat! <= playerCount) {
          // Calculate position for the button. `buttonSeat` is the 0-indexed seat number.
          // We add a small offset to the angle to place it "to the right" of the seat.
          final double angle = (buttonSeat! / playerCount) * 2 * pi + (pi / 2) - (pi / playerCount);

          // The ellipse radii for placing the button slightly inside the player seats
          final double xRadius = tableWidth / 2 - seatRadius * 0.6; // Was 0.8, now 25% closer
          final double yRadius = tableHeight / 2 - seatRadius * 0.6; // Was 0.8, now 25% closer

          final double x = xRadius * cos(angle);
          final double y = yRadius * sin(angle);

          final double buttonRadius = seatRadius * 0.3; // 40% smaller than 0.5

          dealerButton.add(
            Positioned(
              left: (totalWidth / 2) + x - buttonRadius,
              top: (totalHeight / 2) + y - buttonRadius,
              child: CircleAvatar(
                radius: buttonRadius,
                backgroundColor: Colors.white,
                child: Text(
                  'D',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: buttonRadius * 1.2,
                  ),
                ),
              ),
            ),
          );
        }

        // Generate bet widgets
        final List<Widget> betWidgets = [];
        if (bets != null) {
          for (final bet in bets!) {
            // Calculate position for the bet, in front of the player
            final double angle = (bet.seat / playerCount) * 2 * pi + (pi / 2);

            // Place the bet closer to the center of the table than the player
            final double xRadius = tableWidth / 2 - seatRadius * 2.5;
            final double yRadius = tableHeight / 2 - seatRadius * 2.5;

            final double x = xRadius * cos(angle);
            final double y = yRadius * sin(angle);

            final double betWidgetSize = seatRadius * 1.2;

            betWidgets.add(
              Positioned(
                left: (totalWidth / 2) + x - (betWidgetSize / 2),
                top: (totalHeight / 2) + y - (betWidgetSize / 2),
                child: SizedBox(width: betWidgetSize, height: betWidgetSize * 1.2, child: ChipStackWidget(amount: bet.amount)),
              ),
            );
          }
        }

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
                ...dealerButton,
                ...betWidgets,
              ],
            ),
          ),
        );
      },
    );
  }
}