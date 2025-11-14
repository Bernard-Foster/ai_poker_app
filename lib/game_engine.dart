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
  final List<int> _stacks; // The master list of player stacks
  List<pkr.Card> _communityCards;
  final List<int> _bets;
  final List<bool> _hasFolded;
  int buttonPosition;
  int currentPlayerIndex;
  int currentBetToCall;
  int? _lastAggressorIndex;
  bool isBettingRoundOver;

  // Game parameters
  final int smallBlindAmount = 1;
  final int bigBlindAmount = 2;

  List<List<pkr.Card>> get holeCards => _holeCards;
  List<pkr.Card> get communityCards => _communityCards;
  List<int> get playerStacks => _stacks;
  List<int> get bets => _bets;
  List<bool> get hasFolded => _hasFolded;
  int get smallBlindPosition => (buttonPosition + 1) % playerCount;
  int get bigBlindPosition => (buttonPosition + 2) % playerCount;

  GameEngine({required this.playerCount, this.buttonPosition = 0, required int startingStack})
      : _deck = Deck(),
        _holeCards = List.generate(playerCount, (_) => []),
        _communityCards = [],
        _stacks = List.generate(playerCount, (_) => startingStack),
        _bets = List.generate(playerCount, (_) => 0),
        _hasFolded = List.generate(playerCount, (_) => false),
        // Pre-flop action starts after the big blind
        currentPlayerIndex = (buttonPosition + 3) % playerCount,
        currentBetToCall = 0,
        isBettingRoundOver = false
  {
    currentBetToCall = bigBlindAmount;
  }

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

  /// Posts the small and big blinds.
  void postBlinds() {
    // Note: This is a simplified version. A full implementation would handle
    // players not having enough chips for a full blind (all-in scenarios).

    _stacks[smallBlindPosition] -= smallBlindAmount;
    _bets[smallBlindPosition] = smallBlindAmount;

    _stacks[bigBlindPosition] -= bigBlindAmount;
    _bets[bigBlindPosition] = bigBlindAmount;

    // The big blind is the initial "last aggressor" for the pre-flop round.
    _lastAggressorIndex = bigBlindPosition;
  }

  /// Deals the three flop cards.
  void dealFlop() {
    // This should only be called after a betting round is complete.
    if (!isBettingRoundOver) return;

    _communityCards.addAll(_deck.deal(3));
    startNewBettingRound();
  }

  /// Resets betting state for a new round (e.g., post-flop, post-turn).
  void startNewBettingRound() {
    // TODO: Collect bets from _bets into a central pot.
    for (int i = 0; i < playerCount; i++) {
      _bets[i] = 0;
    }
    currentBetToCall = 0;
    isBettingRoundOver = false;
    _lastAggressorIndex = null; // No aggressor at the start of a new round.
    currentPlayerIndex = (buttonPosition + 1) % playerCount; // Action starts left of button.
  }

  void playerFolds() {
    final playerWhoJustActed = currentPlayerIndex;
    _hasFolded[playerWhoJustActed] = true;
    _checkRoundEnd(playerWhoJustActed);
    if (!isBettingRoundOver) {
      _advanceToNextPlayer();
    }
  }

  void playerCalls() {
    final amountToCall = currentBetToCall - _bets[currentPlayerIndex];
    if (amountToCall > 0) {
      // Handle all-in scenario for calls
      if (_stacks[currentPlayerIndex] <= amountToCall) {
        _bets[currentPlayerIndex] += _stacks[currentPlayerIndex];
        _stacks[currentPlayerIndex] = 0;
      } else {
        _stacks[currentPlayerIndex] -= amountToCall;
        _bets[currentPlayerIndex] += amountToCall;
      }
    }

    // Special case for pre-flop: if the BB calls (i.e., checks when facing no raise),
    // the action is now closed. The BB becomes the effective "last aggressor" for the
    // purpose of ending the round.
    if (_lastAggressorIndex == bigBlindPosition &&
        currentPlayerIndex == bigBlindPosition &&
        _bets[currentPlayerIndex] == currentBetToCall) {
      _lastAggressorIndex = currentPlayerIndex;
    }
    final playerWhoJustActed = currentPlayerIndex;
    _checkRoundEnd(playerWhoJustActed);
    if (!isBettingRoundOver) {
      _advanceToNextPlayer();
    }
  }

  void playerBets(int amount) {
    final amountToCall = currentBetToCall - _bets[currentPlayerIndex];
    int totalBetAmount = amountToCall + amount;

    // Handle all-in scenario for bets/raises
    if (_stacks[currentPlayerIndex] <= totalBetAmount) {
      _bets[currentPlayerIndex] += _stacks[currentPlayerIndex];
      _stacks[currentPlayerIndex] = 0;
      currentBetToCall = _bets[currentPlayerIndex]; // New bet to call is their all-in amount
    } else {
      _stacks[currentPlayerIndex] -= totalBetAmount;
      _bets[currentPlayerIndex] += totalBetAmount;
      currentBetToCall = _bets[currentPlayerIndex]; // New bet to call is the full bet
    }

    currentBetToCall = _bets[currentPlayerIndex];
    _lastAggressorIndex = currentPlayerIndex; // This player is the new last aggressor.

    // After a bet, the round is definitely not over yet.
    isBettingRoundOver = false;
    _advanceToNextPlayer();
  }

  void _checkRoundEnd(int playerWhoJustActedIndex) {
    // 1. Get all players who are still in the hand (not folded).
    final playersStillInHand = List<int>.generate(playerCount, (i) => i)
        .where((i) => !_hasFolded[i])
        .toList();

    // 2. If only one player remains, the round is over.
    if (playersStillInHand.length <= 1) {
      isBettingRoundOver = true;
      print("Betting round has ended. Only one player remains.");
      return;
    }

    // 3. Check if all players still in the hand have matched the currentBetToCall
    //    or are all-in for less than the currentBetToCall.
    bool allPlayersHaveActedAndMatchedBet = true;
    for (final playerIndex in playersStillInHand) {
      // If a player's current bet is less than the currentBetToCall,
      // AND they are not all-in (i.e., they still have chips to bet),
      // then the action is not closed for them.
      if (_bets[playerIndex] < currentBetToCall && _stacks[playerIndex] > 0) {
        allPlayersHaveActedAndMatchedBet = false;
        break;
      }
    }

    // 4. The round ends if all active players have voluntarily contributed an equal amount
    //    (or are all-in). This is checked by `allPlayersHaveActedAndMatchedBet`.
    //    Additionally, the action must be "closed". This happens when the player who just acted
    //    was the last aggressor, meaning the action made it all the way around the table
    //    without being re-opened.
    //
    //    A special case is when no one has raised yet (e.g., everyone calls the big blind).
    //    In this case, `_lastAggressorIndex` is still the big blind. The round ends when
    //    the action gets back to the big blind and they check (call).
    final actionIsClosed = (playerWhoJustActedIndex == _lastAggressorIndex) || (_lastAggressorIndex == null && playersStillInHand.isNotEmpty);

    if (allPlayersHaveActedAndMatchedBet && actionIsClosed) {
      isBettingRoundOver = true;
      print("Betting round has ended. Action was closed by Player ${playerWhoJustActedIndex + 1}.");
      // We should not automatically start the next round here.
      // The UI should trigger the next street (e.g., dealing the flop).
      // The call to startNewBettingRound() was moved to dealFlop().
    } else {
      isBettingRoundOver = false; // Explicitly set to false if not over
    }
  }

  void _advanceToNextPlayer() {
    // Move to the next player who hasn't folded.
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
    } while (_hasFolded[currentPlayerIndex]);
  }
}