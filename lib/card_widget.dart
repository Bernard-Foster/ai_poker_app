import 'package:flutter/material.dart' hide Card;
import 'package:poker_app/poker_card.dart';

class CardWidget extends StatelessWidget {
  final Card card;

  const CardWidget({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.white,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                card.rankString,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: card.suitColor,
                ),
              ),
              Text(
                card.suitString,
                style: TextStyle(
                  fontSize: 18,
                  color: card.suitColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}