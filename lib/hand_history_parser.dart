import 'package:poker_app/poker_card.dart';

class Player {
  final int seat;
  final String name;
  final int stack;
  final List<Card> holeCards;
  final bool isActive;

  Player({required this.seat, required this.name, required this.stack, this.holeCards = const [], this.isActive = true});

  @override
  String toString() {
    return 'Player(seat: $seat, name: $name, stack: $stack, isActive: $isActive, cards: [${holeCards.map((c) => c.toServerString()).join(', ')}])';
  }
}

class Bet {
  final int seat;
  final int amount;

  Bet({required this.seat, required this.amount});

  @override
  String toString() {
    return 'Bet(seat: $seat, amount: $amount)';
  }
}

enum ActionType { fold, check, call, bet, raise, dealFlop, dealTurn, dealRiver }

class Action {
  final String playerName;
  final ActionType type;
  final int amount;

  Action({required this.playerName, required this.type, this.amount = 0});

  @override
  String toString() {
    return 'Action(player: $playerName, type: $type, amount: $amount)';
  }
}

class Pot {
  final int amount;
  // In the future, we can add eligible players for side pots.
  // final List<String> eligiblePlayers;

  Pot({required this.amount});

  @override
  String toString() => 'Pot(amount: $amount)';
}

class GameState {
  final String gameId;
  final List<Player> players;
  final int? buttonSeat;
  final List<Bet> bets;
  final List<Action> actions;
  final List<Pot> pots;
  final List<Card> communityCards;
  // ... other properties like button position, actions, etc. will be added later

  GameState({
    required this.gameId,
    required this.players,
    this.buttonSeat,
    this.bets = const [],
    this.actions = const [],
    this.pots = const [],
    this.communityCards = const [],
  });

  @override
  String toString() {
    final playersString = players.map((p) => '    $p').join(',\n');
    final betsString = bets.map((b) => '    $b').join(',\n');
    final actionsString = actions.map((a) => '    $a').join(',\n');
    final potsString = pots.map((p) => '    $p').join(',\n');
    final communityCardsString = communityCards.map((c) => c.toServerString()).join(' ');
    return '''
GameState(
  gameId: $gameId,
  buttonSeat: $buttonSeat,
  players: [\n$playersString\n  ],
  bets: [\n$betsString\n  ],
  actions: [\n$actionsString\n  ],
  pots: [\n$potsString\n  ],
  communityCards: [$communityCardsString]
)''';
  }
}

class HandHistoryParser {
  final String _fullHistoryText;
  late final List<String> _handHistories;

  HandHistoryParser(this._fullHistoryText) {
    // Split the full text into individual hand histories.
    // We split by the lookahead `(?=...)` to keep the "Game #... starts" delimiter.
    final handStartRegex = RegExp(r'^Game #\d+-\d+ starts', multiLine: true);
    _handHistories = _fullHistoryText.trim()
        .split(RegExp(r'(?=' + handStartRegex.pattern + ')', multiLine: true))
        // Ensure we only process chunks that actually start with the required pattern.
        .where((s) => handStartRegex.hasMatch(s.trimLeft()))
        .toList();
  }

  int get handCount => _handHistories.length;

  GameState? parseHand(int handIndex) {
    if (handIndex < 0 || handIndex >= _handHistories.length) {
      return null;
    }

    final handText = _handHistories[handIndex];

    // 1. Parse Game ID
    final gameIdRegex = RegExp(r'^Game #(\d+-\d+) starts');
    final gameIdMatch = gameIdRegex.firstMatch(handText);
    if (gameIdMatch == null) return null;
    final gameId = 'Game #${gameIdMatch.group(1)!}';

    // 2. Parse initial player list (seat, name, stack)
    final List<Player> initialPlayers = [];
    // This regex finds the block of "Seat X: ..." lines that appears at the start of a hand.
    final seatBlockRegex = RegExp(r'Seat \d+: .* \(.*\)\s*(?=Seat \d+:|\n\n|The button is at)');
    final seatMatches = seatBlockRegex.allMatches(handText);

    final playerRegex = RegExp(r'Seat (\d+): (.*) \((\d+) Tournament chips\)');

    for (final seatMatch in seatMatches) {
      final seatLine = seatMatch.group(0)!;
      final playerMatch = playerRegex.firstMatch(seatLine);
      if (playerMatch != null) {
        final seat = int.parse(playerMatch.group(1)!);
        final name = playerMatch.group(2)!;
        final stack = int.parse(playerMatch.group(3)!);
        initialPlayers.add(Player(seat: seat, name: name, stack: stack));
      }
    }

    // 3. Determine active players and parse their dealt cards
    final Set<String> activePlayerNames = {};
    final Map<String, List<Card>> playerHoleCards = {};
    final dealtCardsRegex = RegExp(r'Dealt to (.*) \[ (.*) \]');
    final dealtMatches = dealtCardsRegex.allMatches(handText);

    for (final dealtMatch in dealtMatches) {
      final playerName = dealtMatch.group(1)!;
      // Any player who is dealt cards is considered active for the start of the hand.
      activePlayerNames.add(playerName);

      final cardsString = dealtMatch.group(2)!;
      if (cardsString != '****') {
        final cardStrings = cardsString.split(' ');
        final cards = cardStrings.map((cs) => Card.fromString(cs)).toList();
        playerHoleCards[playerName] = cards;
      }
    }

    // 4. Combine all data to create the final player list
    final List<Player> players = initialPlayers.map((p) {
      final isActive = activePlayerNames.contains(p.name);
      return Player(
          seat: p.seat,
          name: p.name,
          stack: p.stack,
          holeCards: isActive ? (playerHoleCards[p.name] ?? []) : [],
          isActive: isActive);
    }).toList();

    // 5. Parse Button Position
    int? buttonSeat;
    // The "moved to" line indicates the button for the current hand.
    final buttonRegex = RegExp(r'The button is moved to seat (\d+)\.');
    final buttonMatch = buttonRegex.firstMatch(handText);
    if (buttonMatch != null) {
      buttonSeat = int.parse(buttonMatch.group(1)!);
    }

    // 6. Parse Blinds
    final List<Bet> bets = [];
    final blindRegex = RegExp(r'^(.*) posts the (small|big) blind \[(\d+) Tournament chips\]', multiLine: true);
    final blindMatches = blindRegex.allMatches(handText);

    for (final match in blindMatches) {
      final playerName = match.group(1)!;
      final amount = int.parse(match.group(3)!);

      // Find the seat number for the player who posted the blind
      try {
        final player = initialPlayers.firstWhere((p) => p.name == playerName);
        bets.add(Bet(seat: player.seat, amount: amount));
      } catch (e) {
        // Player not found, might happen with inconsistent naming. Skip for now.
        print('Could not find player $playerName to post blind.');
      }
    }

    // 7. Parse all actions and street changes
    final List<Action> actions = [];
    final actionLines = handText.split('\n');

    final actionRegex = RegExp(r'^(.*?)(?: (folds|checks)| (calls|bets for|raises) \[?(\d+) Tournament chips\]?)');
    final dealRegex = RegExp(r'\*\* Dealing (Flop|Turn|River) \*\* \[ (.*) \]');

    for (final line in actionLines) {
      final trimmedLine = line.trim();
      final actionMatch = actionRegex.firstMatch(trimmedLine);
      final dealMatch = dealRegex.firstMatch(trimmedLine);

      if (dealMatch != null) {
        final street = dealMatch.group(1)!;
        ActionType? type;
        if (street == 'Flop') type = ActionType.dealFlop;
        if (street == 'Turn') type = ActionType.dealTurn;
        if (street == 'River') type = ActionType.dealRiver;
        if (type != null) {
          actions.add(Action(playerName: '', type: type));
        }
      } else if (actionMatch != null) {
        final playerName = actionMatch.group(1)!;
        final actionString = actionMatch.group(2) ?? actionMatch.group(3)!;
        final amountString = actionMatch.group(4);
        ActionType? type;
        switch (actionString) {
          case 'folds': type = ActionType.fold; break;
          case 'checks': type = ActionType.check; break;
          case 'calls': type = ActionType.call; break;
          case 'bets for': type = ActionType.bet; break;
          case 'raises': type = ActionType.raise; break;
        }
        if (type != null) {
          actions.add(Action(
            playerName: playerName,
            type: type,
            amount: amountString != null ? int.parse(amountString) : 0,
          ));
        }
      }
    }

    // 8. Parse final community cards state
    final boardRegex = RegExp(r'board:\[ (.*)\]');
    final boardMatch = boardRegex.allMatches(handText).lastOrNull;
    final List<Card> communityCards = [];
    if (boardMatch != null) {
      final cardsString = boardMatch.group(1)!;
      if (cardsString.isNotEmpty) {
        communityCards.addAll(cardsString.split(' ').map((cs) => Card.fromString(cs)));
      }
    }

    return GameState(gameId: gameId, players: players, buttonSeat: buttonSeat, bets: bets, actions: actions, pots: [], communityCards: communityCards);
  }
}