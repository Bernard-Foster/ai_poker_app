import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// NOTE: Replace with your server's IP.
// - Use http://10.0.2.2:8000 for the Android emulator.
// - Use your computer's local network IP for a physical device.
// - Use http://127.0.0.1:8000 for an iOS simulator or desktop/web app.
const String baseUrl = 'http://127.0.0.1:8080'; // Server runs on 8080

void main() {
  runApp(const MyApp());
}

enum Suit { hearts, diamonds, clubs, spades }

enum Street { preflop, flop, turn, river }

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
  final List<Card> _communityCards = [];
  Street _selectedStreet = Street.preflop;
  Suit? _selectedSuit;
  Rank? _selectedRank;
  double? _heroEquity;
  double? _villainEquity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void _onHeroCardTapped(Card card) {
    setState(() {
      _heroCards.remove(card);
      _resetEquity();
    });
  }

  void _onVillainCardTapped(Card card) {
    setState(() {
      _villainCards.remove(card);
      _resetEquity();
    });
  }

  void _onBoardCardTapped(Card card) {
    setState(() {
      _communityCards.remove(card);
      _resetEquity();
    });
  }

  void _addCard(List<Card> cardList, int limit) {
    if (_selectedSuit == null || _selectedRank == null) return;

    final newCard = Card(suit: _selectedSuit!, rank: _selectedRank!);

    // A card cannot be in play more than once.
    final isCardDealt = _heroCards.contains(newCard) ||
        _villainCards.contains(newCard) ||
        _communityCards.contains(newCard);

    if (cardList.length < limit && !isCardDealt) {
      setState(() {
        cardList.add(newCard);
        _resetEquity();
      });
    }
  }

  void _resetEquity() {
    if (_heroEquity != null || _villainEquity != null) {
      setState(() {
        _heroEquity = null;
        _villainEquity = null;
      });
    }
  }

  int get _boardCardLimit {
    switch (_selectedStreet) {
      case Street.preflop:
        return 0;
      case Street.flop:
        return 3;
      case Street.turn:
        return 4;
      case Street.river:
        return 5;
    }
  }

  Future<void> _calculateEquity() async {
    if (_heroCards.length != 2 || _villainCards.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select 2 cards for Hero and Villain.')),
      );
      return;
    }

    if (_communityCards.length != _boardCardLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Please select ${_boardCardLimit} cards for the ${_selectedStreet.name} board.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final heroHandString = _heroCards.map((c) => c.toServerString()).join();
    final villainHandString =
        _villainCards.map((c) => c.toServerString()).join();
    final boardString = _communityCards.map((c) => c.toServerString()).join();

    late final Uri url;
    late final Map<String, dynamic> requestBody;

    if (_selectedStreet == Street.preflop) {
      url = Uri.parse('$baseUrl/equity/preflop');
      requestBody = {'hands': [heroHandString, villainHandString]};
    } else {
      url = Uri.parse('$baseUrl/equity/street');
      requestBody = {
        'street': _selectedStreet.name,
        'hero': heroHandString,
        'villain': villainHandString,
        'board': boardString,
      };
    }

    // Log the data being sent to the server
    print('Sending to server: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        setState(() {
          _heroEquity = result['hero_equity']?.toDouble();
          _villainEquity = result['villain_equity']?.toDouble();
        });
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        print('Server Error: $error');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server Error: $error')));
      }
    } catch (e) {
      print('Network Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCard = (_selectedSuit != null && _selectedRank != null)
        ? Card(suit: _selectedSuit!, rank: _selectedRank!)
        : null;

    final isCardDealt = selectedCard != null &&
        (_heroCards.contains(selectedCard) ||
            _villainCards.contains(selectedCard) ||
            _communityCards.contains(selectedCard));

    final canAddHeroCard =
        selectedCard != null && !isCardDealt && _heroCards.length < 2;
    final canAddVillainCard =
        selectedCard != null && !isCardDealt && _villainCards.length < 2;
    final canAddBoardCard = selectedCard != null &&
        !isCardDealt &&
        _communityCards.length < _boardCardLimit;
    final canCalculate =
        _heroCards.length == 2 && _villainCards.length == 2 && !_isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Hero Cards',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (_heroEquity != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text('(${( _heroEquity! * 100).toStringAsFixed(1)}%)',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Villain Cards',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (_villainEquity != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text('(${( _villainEquity! * 100).toStringAsFixed(1)}%)',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
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
                const Text('Street',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ToggleButtons(
                  onPressed: (int index) {
                    setState(() {
                      _selectedStreet = Street.values[index];
                      // Remove cards from board if they are invalid for the new street
                      if (_communityCards.length > _boardCardLimit) {
                        _communityCards.removeRange(
                            _boardCardLimit, _communityCards.length);
                      }
                      _resetEquity();
                    });
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  isSelected: Street.values.map((s) => s == _selectedStreet).toList(),
                  children: Street.values
                      .map((s) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          if (_selectedStreet != Street.preflop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                children: [
                  const Text('Board Cards',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90, // Provide a fixed height for the cards area
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _communityCards.isEmpty
                          ? [
                              Text(
                                  'Select $_boardCardLimit cards for the ${_selectedStreet.name}')
                            ]
                          : _communityCards
                              .map((card) => GestureDetector(
                                    onTap: () => _onBoardCardTapped(card),
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
                      onPressed: canAddHeroCard
                          ? () => _addCard(_heroCards, 2)
                          : null,
                      child: const Text('Add to Hero'),
                    ),
                    ElevatedButton(
                      onPressed: canAddVillainCard
                          ? () => _addCard(_villainCards, 2)
                          : null,
                      child: const Text('Add to Villain'),
                    ),
                    if (_selectedStreet != Street.preflop)
                      ElevatedButton(
                        onPressed: canAddBoardCard
                            ? () => _addCard(_communityCards, _boardCardLimit)
                            : null,
                        child: const Text('Add to Board'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: canCalculate ? _calculateEquity : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 40),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3,))
                      : const Text('Calculate Equity'),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}