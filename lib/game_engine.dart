import 'package:poker/poker.dart' as pkr;

/// Represents a standard 52-card deck.
class Deck {
  late List<pkr.Card> _cards;

  /// Creates a new, unshuffled 52-card deck.
  Deck() {
    _cards = pkr.Suit.values
        .expand((suit) => pkr.Rank.values.map((rank) => pkr.Card(rank, suit)))
        .toList();
  }

  /// Shuffles the deck randomly.
  void shuffle() {
    _cards.shuffle();
  }

  /// Deals a specified number of cards from the top of the deck.
  /// Returns an empty list if not enough cards are available.
  List<pkr.Card> deal(int count) {
    if (count > _cards.length) {
      return [];
    }
    final dealtCards = _cards.sublist(0, count);
    _cards.removeRange(0, count);
    return dealtCards;
  }
}

/// Manages the state and logic of a single poker hand.
class GameEngine {
  final int playerCount;
  final Deck _deck;
  final List<List<pkr.Card>> _holeCards;
  int buttonPosition;

  List<List<pkr.Card>> get holeCards => _holeCards;
  int get smallBlindPosition => (buttonPosition + 1) % playerCount;
  int get bigBlindPosition => (buttonPosition + 2) % playerCount;

  GameEngine({required this.playerCount, this.buttonPosition = 0})
      : _deck = Deck(),
        _holeCards = List.generate(playerCount, (_) => []);

  /// Moves the button to the next player.
  void advanceButton() {
    buttonPosition = (buttonPosition + 1) % playerCount;
  }

  /// Shuffles the deck and deals two cards to each player.
  void dealPreFlop() {
    _deck.shuffle();
    for (int i = 0; i < playerCount; i++) {
      _holeCards[i] = _deck.deal(2);
    }
  }
}