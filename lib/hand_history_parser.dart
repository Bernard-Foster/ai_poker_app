import 'package:poker_app/poker_card.dart';

class Player {
  final int seat;
  final String name;
  final int stack;
  final List<Card> holeCards;

  Player({required this.seat, required this.name, required this.stack, this.holeCards = const []});

  @override
  String toString() {
    return 'Player(seat: $seat, name: $name, stack: $stack)';
  }
}

class Bet {
  final int seat;
  final int amount;

  Bet({required this.seat, required this.amount});
}

class GameState {
  final String gameId;
  final List<Player> players;
  final int? buttonSeat;
  final List<Bet> bets;
  // ... other properties like button position, actions, etc. will be added later

  GameState({required this.gameId, required this.players, this.buttonSeat, this.bets = const []});
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

    // 3. Parse dealt cards
    final Map<String, List<Card>> playerHoleCards = {};
    final dealtCardsRegex = RegExp(r'Dealt to (.*) \[ (.*) \]');
    final dealtMatches = dealtCardsRegex.allMatches(handText);

    for (final dealtMatch in dealtMatches) {
      final playerName = dealtMatch.group(1)!;
      final cardsString = dealtMatch.group(2)!;
      if (cardsString != '****') {
        final cardStrings = cardsString.split(' ');
        final cards = cardStrings.map((cs) => Card.fromString(cs)).toList();
        playerHoleCards[playerName] = cards;
      }
    }

    // 4. Combine initial player data with their hole cards
    final List<Player> players = initialPlayers.map((p) {
      return Player(seat: p.seat, name: p.name, stack: p.stack, holeCards: playerHoleCards[p.name] ?? []);
    }).toList();

    // 3. Parse Button Position
    int? buttonSeat;
    // The "moved to" line indicates the button for the current hand.
    final buttonRegex = RegExp(r'The button is moved to seat (\d+)\.');
    final buttonMatch = buttonRegex.firstMatch(handText);
    if (buttonMatch != null) {
      buttonSeat = int.parse(buttonMatch.group(1)!);
    }

    // 4. Parse Blinds
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


    return GameState(gameId: gameId, players: players, buttonSeat: buttonSeat, bets: bets);
  }
}