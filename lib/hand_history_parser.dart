class Player {
  final int seat;
  final String name;
  final int stack;

  Player({required this.seat, required this.name, required this.stack});

  @override
  String toString() {
    return 'Player(seat: $seat, name: $name, stack: $stack)';
  }
}

class GameState {
  final String gameId;
  final List<Player> players;
  final int? buttonSeat;
  // ... other properties like button position, actions, etc. will be added later

  GameState({required this.gameId, required this.players, this.buttonSeat});
}

class HandHistoryParser {
  final String _fullHistoryText;
  late final List<String> _handHistories;

  HandHistoryParser(this._fullHistoryText) {
    // Split the full text into individual hand histories.
    // We split by the lookahead `(?=...)` to keep the "Game #... starts" delimiter.
    final handStartRegex = RegExp(r'Game #\d+-\d+ starts');
    _handHistories = _fullHistoryText.trim()
        .split(RegExp(r'(?=' + handStartRegex.pattern + ')', multiLine: true))
        // Ensure we only process chunks that actually start with the required pattern.
        .where((s) => s.trim().startsWith(handStartRegex))
        .toList();
  }

  int get handCount => _handHistories.length;

  GameState? parseHand(int handIndex) {
    if (handIndex < 0 || handIndex >= _handHistories.length) {
      return null;
    }

    final handText = _handHistories[handIndex];

    // 1. Parse Game ID
    final gameIdRegex = RegExp(r'Game #(\d+-\d+) starts');
    final gameIdMatch = gameIdRegex.firstMatch(handText);
    if (gameIdMatch == null) return null;
    final gameId = 'Game #${gameIdMatch.group(1)!}';

    // 2. Parse Players and their stacks
    final List<Player> players = [];
    // This regex finds the block of "Seat X: ..." lines that appears at the start of a hand.
    final seatBlockRegex = RegExp(r'Seat \d+: .* \(.*\)\s*(?=Seat \d+:|\n\n|The button is at)');
    final seatMatches = seatBlockRegex.allMatches(handText);

    final playerRegex = RegExp(r'Seat (\d+): (.*) \((\d+) Tournament chips\)');

    for (final match in seatMatches) {
      final seatLine = match.group(0)!;
      final playerMatch = playerRegex.firstMatch(seatLine);
      if (playerMatch != null) {
        final seat = int.parse(playerMatch.group(1)!);
        final name = playerMatch.group(2)!;
        final stack = int.parse(playerMatch.group(3)!);
        players.add(Player(seat: seat, name: name, stack: stack));
      }
    }

    // 3. Parse Button Position
    int? buttonSeat;
    // The "moved to" line indicates the button for the current hand.
    final buttonRegex = RegExp(r'The button is moved to seat (\d+)\.');
    final buttonMatch = buttonRegex.firstMatch(handText);
    if (buttonMatch != null) {
      buttonSeat = int.parse(buttonMatch.group(1)!);
    }

    return GameState(gameId: gameId, players: players, buttonSeat: buttonSeat);
  }
}