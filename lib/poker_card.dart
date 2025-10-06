import 'package:flutter/material.dart';

enum Suit { hearts, diamonds, clubs, spades }

enum Rank { two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace }

class Card {
  final Suit suit;
  final Rank rank;

  const Card({required this.suit, required this.rank});

  String get rankString {
    switch (rank) {
      case Rank.two: return '2';
      case Rank.three: return '3';
      case Rank.four: return '4';
      case Rank.five: return '5';
      case Rank.six: return '6';
      case Rank.seven: return '7';
      case Rank.eight: return '8';
      case Rank.nine: return '9';
      case Rank.ten: return 'T';
      case Rank.jack: return 'J';
      case Rank.queen: return 'Q';
      case Rank.king: return 'K';
      case Rank.ace: return 'A';
    }
  }

  String get suitString {
    switch (suit) {
      case Suit.hearts: return '♥';
      case Suit.diamonds: return '♦';
      case Suit.clubs: return '♣';
      case Suit.spades: return '♠';
    }
  }

  String get serverSuitString {
    switch (suit) {
      case Suit.hearts: return 'h';
      case Suit.diamonds: return 'd';
      case Suit.clubs: return 'c';
      case Suit.spades: return 's';
    }
  }

  String toServerString() => '$rankString$serverSuitString';

  Color get suitColor {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red;
      case Suit.clubs:
      case Suit.spades:
        return Colors.black;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Card &&
          runtimeType == other.runtimeType &&
          suit == other.suit &&
          rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;
}