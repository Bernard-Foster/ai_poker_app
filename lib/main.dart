import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PokerPage(title: 'Hero Card Selection'),
    );
  }
}

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
    );
  }
}

class PokerPage extends StatefulWidget {
  const PokerPage({super.key, required this.title});

  final String title;

  @override
  State<PokerPage> createState() => _PokerPageState();
}

class _PokerPageState extends State<PokerPage> {
  final List<Card> _heroCards = [];
  final List<Card> _villainCards = [];
  Suit? _selectedSuit;
  Rank? _selectedRank;

  @override
  void initState() {
    super.initState();
  }

  void _onHeroCardTapped(Card card) {
    setState(() {
      _heroCards.remove(card);
    });
  }

  void _onVillainCardTapped(Card card) {
    setState(() {
      _villainCards.remove(card);
    });
  }

  void _addCard(List<Card> hand) {
    if (_selectedSuit == null || _selectedRank == null) return;

    final newCard = Card(suit: _selectedSuit!, rank: _selectedRank!);

    // A card cannot be in play more than once.
    final isCardDealt =
        _heroCards.contains(newCard) || _villainCards.contains(newCard);

    if (hand.length < 2 && !isCardDealt) {
      setState(() {
        hand.add(newCard);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCard = (_selectedSuit != null && _selectedRank != null)
        ? Card(suit: _selectedSuit!, rank: _selectedRank!)
        : null;

    final isCardDealt = selectedCard != null &&
        (_heroCards.contains(selectedCard) ||
            _villainCards.contains(selectedCard));

    final canAddHeroCard =
        selectedCard != null && !isCardDealt && _heroCards.length < 2;
    final canAddVillainCard =
        selectedCard != null && !isCardDealt && _villainCards.length < 2;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text('Hero Cards',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90, // Provide a fixed height for the hero cards area
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _heroCards.isEmpty
                        ? [
                            const Text(
                                'Select 2 cards using the dropdowns below')
                          ]
                        : _heroCards
                            .map((card) => GestureDetector(
                                  onTap: () => _onHeroCardTapped(card),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0),
                                    child: SizedBox(
                                        width: 65, child: CardWidget(card: card)),
                                  ),
                                ))
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: Column(
              children: [
                const Text('Villain Cards',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90, // Provide a fixed height for the hero cards area
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _villainCards.isEmpty
                        ? [
                            const Text(
                                'Select 2 cards using the dropdowns below')
                          ]
                        : _villainCards
                            .map((card) => GestureDetector(
                                  onTap: () => _onVillainCardTapped(card),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0),
                                    child: SizedBox(
                                        width: 65, child: CardWidget(card: card)),
                                  ),
                                ))
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DropdownButton<Suit>(
                      hint: const Text('Suit'),
                      value: _selectedSuit,
                      onChanged: (Suit? newValue) {
                        setState(() {
                          _selectedSuit = newValue;
                        });
                      },
                      items: Suit.values.map((Suit suit) {
                        return DropdownMenuItem<Suit>(
                          value: suit,
                          child: Text(
                            Card(suit: suit, rank: Rank.ace).suitString,
                            style: TextStyle(
                                color:
                                    Card(suit: suit, rank: Rank.ace).suitColor,
                                fontSize: 24),
                          ),
                        );
                      }).toList(),
                    ),
                    DropdownButton<Rank>(
                      hint: const Text('Rank'),
                      value: _selectedRank,
                      onChanged: (Rank? newValue) {
                        setState(() {
                          _selectedRank = newValue;
                        });
                      },
                      items: Rank.values.map((Rank rank) {
                        return DropdownMenuItem<Rank>(
                          value: rank,
                          child: Text(
                              Card(suit: Suit.spades, rank: rank).rankString),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed:
                          canAddHeroCard ? () => _addCard(_heroCards) : null,
                      child: const Text('Add to Hero'),
                    ),
                    ElevatedButton(
                      onPressed: canAddVillainCard
                          ? () => _addCard(_villainCards)
                          : null,
                      child: const Text('Add to Villain'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
