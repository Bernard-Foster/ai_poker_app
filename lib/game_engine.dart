import 'package:poker_solver/poker_solver.dart' as pkr;

/// -------------------------------
///  DECK (poker_solver only)
/// -------------------------------
class Deck {
  late List<pkr.Card> _cards;

  Deck() {
    // Poker solver uses "As", "Td", "5c", etc.
    const values = ['2','3','4','5','6','7','8','9','T','J','Q','K','A'];
    const suits  = ['d','c','h','s']; // diamonds, clubs, hearts, spades

    _cards = [
      for (final v in values)
        for (final s in suits)
          pkr.Card("$v$s")
    ];
  }

  void shuffle() => _cards.shuffle();

  List<pkr.Card> deal(int count) {
    if (count > _cards.length) return [];
    final out = _cards.sublist(0, count);
    _cards.removeRange(0, count);
    return out;
  }
}

/// -------------------------------
/// GAME ENGINE (Texas Hold'em)
/// -------------------------------
class GameEngine {
  final int playerCount;
  final Deck _deck;

  final List<List<pkr.Card>> _holeCards;
  List<pkr.Card> _community;

  final List<int> _stacks;
  final List<int> _bets;
  final List<bool> _folded;

  int currentPlayer;
  int button;
  int currentBetToCall;
  int? lastAggressor;

  int _pot = 0;
  bool bettingDone = false;
  bool handOver = false;

  List<int>? winners;
  String? winningHandDescription;

  static const int sb = 1;
  static const int bb = 2;

  GameEngine({
    required this.playerCount,
    required int startingStack,
    this.button = 0,
  }) :
    _deck = Deck(),
    _holeCards = List.generate(playerCount, (_) => []),
    _community = [],
    _stacks = List.generate(playerCount, (_) => startingStack),
    _bets = List.generate(playerCount, (_) => 0),
    _folded = List.generate(playerCount, (_) => false),
    currentPlayer = (button + 3) % playerCount,
    currentBetToCall = bb;

  List<pkr.Card> get communityCards => _community;
  List<List<pkr.Card>> get holeCards => _holeCards;
  List<int> get stacks => _stacks;
  List<bool> get folded => _folded;

  int get sbPos => (button + 1) % playerCount;
  int get bbPos => (button + 2) % playerCount;

  /// -------------------------------
  /// PRE-FLOP
  /// -------------------------------
  void dealPreFlop() {
    _deck.shuffle();
    for (int i = 0; i < playerCount; i++) {
      _holeCards[i] = _deck.deal(2);
    }
  }

  void postBlinds() {
    _stacks[sbPos] -= sb;
    _bets[sbPos] = sb;

    _stacks[bbPos] -= bb;
    _bets[bbPos] = bb;

    lastAggressor = bbPos;
  }

  /// -------------------------------
  /// DEALING STREETS
  /// -------------------------------
  void flop() {
    if (!bettingDone) return;
    _community.addAll(_deck.deal(3));
    _startNewRound();
  }

  void turn() {
    if (!bettingDone) return;
    _community.addAll(_deck.deal(1));
    _startNewRound();
  }

  void river() {
    if (!bettingDone) return;
    _community.addAll(_deck.deal(1));
    _startNewRound();
  }

  void _startNewRound() {
    _pot += _bets.fold(0, (a, b) => a + b);
    for (int i = 0; i < playerCount; i++) _bets[i] = 0;

    currentBetToCall = 0;
    lastAggressor = null;
    bettingDone = false;
    currentPlayer = sbPos; // start next street at SB
  }

  /// -------------------------------
  /// PLAYER ACTIONS
  /// -------------------------------
  void fold() {
    _folded[currentPlayer] = true;
    _checkRoundEnd(currentPlayer);
    if (!bettingDone) _nextPlayer();
  }

  void call() {
    int diff = currentBetToCall - _bets[currentPlayer];

    if (diff > 0) {
      int pay = diff > _stacks[currentPlayer]
          ? _stacks[currentPlayer]
          : diff;

      _stacks[currentPlayer] -= pay;
      _bets[currentPlayer] += pay;
    }

    // Special rule: BB checking preflop
    if (lastAggressor == bbPos &&
        currentPlayer == bbPos &&
        _bets[currentPlayer] == currentBetToCall) {
      lastAggressor = currentPlayer;
    }

    _checkRoundEnd(currentPlayer);
    if (!bettingDone) _nextPlayer();
  }

  void bet(int amount) {
    int diff = currentBetToCall - _bets[currentPlayer];
    int total = diff + amount;

    if (total >= _stacks[currentPlayer]) {
      _bets[currentPlayer] += _stacks[currentPlayer];
      _stacks[currentPlayer] = 0;
    } else {
      _bets[currentPlayer] += total;
      _stacks[currentPlayer] -= total;
    }

    currentBetToCall = _bets[currentPlayer];
    lastAggressor = currentPlayer;
    bettingDone = false;

    _nextPlayer();
  }

  /// -------------------------------
  /// ROUND-END LOGIC
  /// -------------------------------
  void _nextPlayer() {
    do {
      currentPlayer = (currentPlayer + 1) % playerCount;
    } while (_folded[currentPlayer]);
  }

  void _checkRoundEnd(int actedPlayer) {
    final active = List.generate(playerCount, (i) => i)
        .where((i) => !_folded[i])
        .toList();

    if (active.length <= 1) {
      bettingDone = true;
      determineWinner();
      return;
    }

    bool everyoneMatched = active.every(
      (p) => _bets[p] == currentBetToCall || _stacks[p] == 0,
    );

    final actionClosed =
        actedPlayer == lastAggressor ||
        (lastAggressor == null);

    if (everyoneMatched && actionClosed) {
      bettingDone = true;
    }
  }

  /// -------------------------------
  /// SHOWDOWN (poker_solver correct)
  /// -------------------------------
  void determineWinner() {
    if (handOver) return;

    final active = List.generate(playerCount, (i) => i)
        .where((i) => !_folded[i])
        .toList();

    if (active.length == 1) {
      winners = [active.first];
      winningHandDescription = "Wins by fold";
      _stacks[active.first] += _pot;
      _pot = 0;
      handOver = true;
      return;
    }

    if (_community.length != 5) return;

    /// Evaluate each player's best hand via solveHand
    final hands = <pkr.Hand>[];
    for (final p in active) {
      final seven = [..._community, ..._holeCards[p]];
      hands.add(pkr.Hand.solveHand(seven));
    }

    final bestHands = pkr.Hand.winners(hands);

    winners = [
      for (final h in bestHands) active[hands.indexOf(h)]
    ];

    final share = _pot ~/ winners!.length;
    for (final w in winners!) _stacks[w] += share;

    winningHandDescription = bestHands.first.toString();
    handOver = true;
    _pot = 0;
  }
}
