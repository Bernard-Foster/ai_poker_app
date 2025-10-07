import 'package:flutter/material.dart';

enum Suit { hearts, diamonds, clubs, spades }

enum Rank { two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace }

class Card {
  final Suit suit;
  final Rank rank;

  const Card({required this.suit, required this.rank});

  factory Card.fromString(String cardStr) {
    if (cardStr.length != 2) {
      throw ArgumentError('Card string must be 2 characters long: $cardStr');
    }

    final rankChar = cardStr[0];
    final suitChar = cardStr[1];

    final rank = Rank.values.firstWhere(
      (r) => Card(suit: Suit.spades, rank: r).rankString == rankChar,
      orElse: () => throw ArgumentError('Invalid rank character: $rankChar'),
    );

    final suit = Suit.values.firstWhere(
      (s) => Card(suit: s, rank: Rank.ace).serverSuitString == suitChar,
      orElse: () => throw ArgumentError('Invalid suit character: $suitChar'),
    );

    return Card(suit: suit, rank: rank);
  }

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