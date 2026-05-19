import 'package:flutter/material.dart' hide Card;
import 'package:poker_app/features/cards/poker_card.dart';

class CardWidget extends StatelessWidget {
  final Card? card;
  final bool isFaceDown;

  const CardWidget({
    super.key,
    this.card,
    this.isFaceDown = false,
  }) : assert(isFaceDown || card != null, 'Card must be provided if not face down');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.white,
      ),
      child: isFaceDown
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.blue.shade900,
                border: Border.all(color: Colors.white, width: 2.0),
              ),
            )
          : Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card!.rankString,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: card!.suitColor,
                      ),
                    ),
                    Text(
                      card!.suitString,
                      style: TextStyle(
                        fontSize: 18,
                        color: card!.suitColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}