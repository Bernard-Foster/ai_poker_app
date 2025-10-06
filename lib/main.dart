import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:poker_app/hand_history_page.dart';
import 'package:http/http.dart' as http;
import 'package:poker_app/poker_card.dart' as poker;
import 'package:poker_app/card_widget.dart';
// NOTE: Replace with your server's IP.
// - Use http://10.0.2.2:8000 for the Android emulator.
// - Use your computer's local network IP for a physical device.
// - Use http://127.0.0.1:8000 for an iOS simulator or desktop/web app.
const String baseUrl = 'http://127.0.0.1:5001'; // pokerkit server runs on 5001

void main() {
  runApp(const MyApp());
}

enum Street { preflop, flop, turn, river }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(title: 'Poker App'),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PokerPage(title: 'Hand Equity Calculator')),
                );
              },
              child: const Text('Hand Equity Calculator'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HandHistoryPage(title: 'Hand History Playback')),
                );
              },
              child: const Text('Hand History Playback'),
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
  // State for Hero's hand: can be a range string like "AKs" or "77".
  String? _heroHand;
  poker.Rank? _heroRank1;
  poker.Rank? _heroRank2;
  bool _heroSuited = false;
  final List<List<poker.Card>> _villainHands = [[]]; // Start with one villain
  final List<poker.Card> _communityCards = [];
  Street _selectedStreet = Street.preflop;
  poker.Suit? _selectedSuit;
  poker.Rank? _selectedRank;
  double? _heroEquity;
  List<double?>? _villainEquities;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void _onVillainCardTapped(int villainIndex, poker.Card card) {
    setState(() {
      _villainHands[villainIndex].remove(card);
      _resetEquity();
    });
  }

  void _onBoardCardTapped(poker.Card card) {
    setState(() {
      _communityCards.remove(card);
      _resetEquity();
    });
  }

  void _addCard(List<poker.Card> cardList, int limit) {
    if (_selectedSuit == null || _selectedRank == null) return;

    final newCard = poker.Card(suit: _selectedSuit!, rank: _selectedRank!);

    // A card cannot be in play more than once.
    final isCardDealt = _villainHands
            .any((hand) => hand.contains(newCard)) ||
        _communityCards.contains(newCard);

    if (cardList.length < limit && !isCardDealt) { // Hero hand is now a range, not specific cards
      setState(() {
        cardList.add(newCard);
        _resetEquity();
      });
    }
  }

  void _resetEquity() {
    if (_heroEquity != null || _villainEquities != null) {
      setState(() {
        _heroEquity = null;
        _villainEquities = null;
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
    final allHandsComplete = _heroHand != null && _heroHand!.isNotEmpty && _villainHands.every((hand) => hand.length == 2);
    if (!allHandsComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a hand for Hero and select 2 cards for all Villains.')),
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

    final villainHandStrings = _villainHands
        .map((hand) => hand.map((c) => c.toServerString()).join())
        .toList();
    final boardString = _communityCards.map((c) => c.toServerString()).join();

    final allHands = [_heroHand!, ...villainHandStrings];

    final url = Uri.parse('$baseUrl/equity');
    final requestBody = {
      'players': allHands, // pokerkit server expects 'players'
      'board': boardString,
    };

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
        // Assuming response is like: {"equities": [0.6, 0.2, 0.2]}
        final equities = (data['equities'] as List).cast<double>();
        setState(() {
          if (equities.isNotEmpty) {
            _heroEquity = equities[0];
          }
          if (equities.length > 1) {
            _villainEquities = equities.sublist(1);
          }
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
        ? poker.Card(suit: _selectedSuit!, rank: _selectedRank!)
        : null;

    final isCardDealt = selectedCard != null &&
        (_villainHands.any((hand) => hand.contains(selectedCard)) ||
            _communityCards.contains(selectedCard));

    final canAddBoardCard = selectedCard != null &&
        !isCardDealt &&
        _communityCards.length < _boardCardLimit;
    final canCalculate = _heroHand != null && _heroHand!.isNotEmpty && _villainHands.isNotEmpty &&
        _villainHands.every((h) => h.length == 2) && !_isLoading;

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
                  child: Center(
                    child: _heroHand == null
                        ? const Text('Select a hand range for Hero below')
                        : Text(
                            _heroHand!,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DropdownButton<poker.Rank>(
                      hint: const Text('Rank 1'),
                      value: _heroRank1,
                      onChanged: (poker.Rank? newValue) {
                        setState(() => _heroRank1 = newValue);
                      },
                      items: poker.Rank.values.reversed.map((poker.Rank rank) {
                        return DropdownMenuItem<poker.Rank>(
                          value: rank,
                          child: Text(poker.Card(suit: poker.Suit.spades, rank: rank).rankString),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<poker.Rank>(
                      hint: const Text('Rank 2'),
                      value: _heroRank2,
                      onChanged: (poker.Rank? newValue) {
                        setState(() => _heroRank2 = newValue);
                      },
                      items: poker.Rank.values.reversed.map((poker.Rank rank) {
                        return DropdownMenuItem<poker.Rank>(
                          value: rank,
                          child: Text(poker.Card(suit: poker.Suit.spades, rank: rank).rankString),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 10),
                    if (_heroRank1 != null && _heroRank2 != null && _heroRank1 != _heroRank2) ...[
                      const Text('Suited'),
                      Switch(
                        value: _heroSuited,
                        onChanged: (value) {
                          setState(() => _heroSuited = value);
                        },
                      ),
                    ]
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_heroRank1 != null && _heroRank2 != null) {
                      if (_heroRank1 == _heroRank2) {
                        // Pocket pair
                        final rankStr = poker.Card(suit: poker.Suit.spades, rank: _heroRank1!).rankString;
                        setState(() => _heroHand = '$rankStr$rankStr');
                      } else {
                        // Ensure ranks are ordered correctly (high then low)
                        final r1Index = poker.Rank.values.indexOf(_heroRank1!);
                        final r2Index = poker.Rank.values.indexOf(_heroRank2!);
                        final highRank = r1Index > r2Index ? _heroRank1! : _heroRank2!;
                        final lowRank = r1Index > r2Index ? _heroRank2! : _heroRank1!;

                        final highRankStr = poker.Card(suit: poker.Suit.spades, rank: highRank).rankString;
                        final lowRankStr = poker.Card(suit: poker.Suit.spades, rank: lowRank).rankString;
                        final suitedStr = _heroSuited ? 's' : 'o';

                        setState(() => _heroHand = '$highRankStr$lowRankStr$suitedStr');
                      }
                      _resetEquity();
                    }
                  },
                  child: const Text('Set Hero Hand'),
                ),
              ],
            ),
          ),
          const Divider(),
          ..._villainHands.asMap().entries.map((entry) {
            final index = entry.key;
            final villainHand = entry.value;
            final villainEquity = (_villainEquities != null && index < _villainEquities!.length)
                ? _villainEquities![index]
                : null;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Villain ${index + 1} Cards',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      if (villainEquity != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text('(${(villainEquity * 100).toStringAsFixed(1)}%)',
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90, // Provide a fixed height for the villain cards area
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: villainHand.isEmpty
                          ? [
                              const Text(
                                  'Select 2 cards using the card selector below')
                            ]
                          : villainHand
                              .map((card) => GestureDetector(
                                    onTap: () => _onVillainCardTapped(index, card),
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
            );
          }).toList(),
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
                const Text('Card Selector (for Villains & Board)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DropdownButton<poker.Suit>(
                      hint: const Text('Suit'),
                      value: _selectedSuit,
                      onChanged: (poker.Suit? newValue) {
                        setState(() {
                          _selectedSuit = newValue;
                        });
                      },
                      items: poker.Suit.values.map((poker.Suit suit) {
                        return DropdownMenuItem<poker.Suit>(
                          value: suit,
                          child: Text(
                            poker.Card(suit: suit, rank: poker.Rank.ace).suitString,
                            style: TextStyle(
                                color:
                                    poker.Card(suit: suit, rank: poker.Rank.ace).suitColor,
                                fontSize: 24),
                          ),
                        );
                      }).toList(),
                    ),
                    DropdownButton<poker.Rank>(
                      hint: const Text('Rank'),
                      value: _selectedRank,
                      onChanged: (poker.Rank? newValue) {
                        setState(() {
                          _selectedRank = newValue;
                        });
                      },
                      items: poker.Rank.values.map((poker.Rank rank) {
                        return DropdownMenuItem<poker.Rank>(
                          value: rank,
                          child: Text(
                              poker.Card(suit: poker.Suit.spades, rank: rank).rankString),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ..._villainHands.asMap().entries.map((entry) {
                      final index = entry.key;
                      final villainHand = entry.value;
                      final canAddVillainCard = selectedCard != null &&
                          !isCardDealt &&
                          villainHand.length < 2;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ElevatedButton(
                          onPressed: canAddVillainCard
                              ? () => _addCard(_villainHands[index], 2)
                              : null,
                          child: Text('To V${index + 1}'),
                        ),
                      );
                    }).toList(),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _villainHands.length < 9 ? () {
                        setState(() {
                          _villainHands.add([]);
                          _resetEquity();
                        });
                      } : null,
                      child: const Text('Add Villain'),
                    ),
                    ElevatedButton(
                      onPressed: _villainHands.length > 1 ? () {
                        setState(() {
                          _villainHands.removeLast();
                          _resetEquity();
                        });
                      } : null,
                      child: const Text('Remove Villain'),
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