import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:poker_app/hand_history_parser.dart' as parser;
import 'package:poker_app/game_board_widget.dart';

class HandHistoryPage extends StatefulWidget {
  const HandHistoryPage({super.key, required this.title});

  final String title;

  @override
  State<HandHistoryPage> createState() => _HandHistoryPageState();
}

class _LastActionInfo {
  final String playerName;
  final parser.ActionType actionType;

  _LastActionInfo(this.playerName, this.actionType);
}

class _HandHistoryPageState extends State<HandHistoryPage> {
  String? _handHistoryText;
  parser.HandHistoryParser? _parser;
  int _currentHandIndex = 0;
  int _currentActionIndex = -1; // -1 represents the initial state before any actions
  parser.GameState? _currentGameState;
  _LastActionInfo? _lastActionInfo;
  Timer? _actionBillboardTimer;

  Future<void> _pickFile() async {
    // Use file_picker to open the file explorer
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      try {
        String contents;
        if (kIsWeb) {
          // On web, we get the file's content as bytes.
          if (file.bytes != null) {
            contents = utf8.decode(file.bytes!);
          } else {
            throw Exception("File bytes are null on web.");
          }
        } else {
          // On mobile/desktop, we can read the file from its path.
          if (file.path != null) {
            contents = await File(file.path!).readAsString();
          } else {
            throw Exception("File path is null on mobile/desktop.");
          }
        }
        setState(() {
          _handHistoryText = contents;
          _parser = parser.HandHistoryParser(contents);
          _updateGameState();
        });
      } catch (e) {
        setState(() => _handHistoryText = 'Error reading file: $e');
      }
    } else {
      // User canceled the picker
    }
  }

  void _updateGameState() {
    print('Updating game state for hand index: $_currentHandIndex, action index: $_currentActionIndex');
    if (_parser == null) return;

    final baseGameState = _parser!.parseHand(_currentHandIndex);
    if (baseGameState == null) return;

    // Create a new state by applying actions up to the current index
    final activeActions = _currentActionIndex >= 0
        ? baseGameState.actions.sublist(0, _currentActionIndex + 1)
        : <parser.Action>[];

    final Set<String> foldedPlayers = activeActions
        .where((a) => a.type == parser.ActionType.fold)
        .map((a) => a.playerName)
        .toSet();

    // Create a mutable map of players to update their cards at showdown
    final Map<String, parser.Player> playerMap = {for (var p in baseGameState.players) p.name: p};

    // Process actions sequentially to build the current state
    int accumulatedPot = 0;
    Map<int, int> currentStreetBets = {};
    List<parser.Card> visibleCommunityCards = [];

    // Start with blinds as the first bets of the pre-flop round
    baseGameState.bets.forEach((blind) {
      currentStreetBets[blind.seat] = blind.amount;
    });

    for (final currentAction in activeActions) {
      if (currentAction.type == parser.ActionType.dealFlop || currentAction.type == parser.ActionType.dealTurn || currentAction.type == parser.ActionType.dealRiver) {
        // End of a street, collect bets into the pot
        accumulatedPot += currentStreetBets.values.fold(0, (a, b) => a + b);
        currentStreetBets.clear();

        if (currentAction.type == parser.ActionType.dealFlop) {
          visibleCommunityCards = baseGameState.communityCards.take(3).toList();
        } else if (currentAction.type == parser.ActionType.dealTurn) {
          visibleCommunityCards = baseGameState.communityCards.take(4).toList();
        } else if (currentAction.type == parser.ActionType.dealRiver) {
          visibleCommunityCards = baseGameState.communityCards.take(5).toList();
        }
      } else if (currentAction.type == parser.ActionType.call || currentAction.type == parser.ActionType.raise || currentAction.type == parser.ActionType.bet) {
        final player = baseGameState.players.firstWhere((p) => p.name == currentAction.playerName);
        currentStreetBets[player.seat] = currentAction.amount;
      } else if (currentAction.type == parser.ActionType.showCards) {
        // Update the player's hole cards when they are shown
        final showingPlayer = playerMap[currentAction.playerName];
        if (showingPlayer != null) {
          playerMap[currentAction.playerName] = parser.Player(
              seat: showingPlayer.seat,
              name: showingPlayer.name,
              stack: showingPlayer.stack,
              holeCards: currentAction.cards, // The revealed cards
              isActive: showingPlayer.isActive);
        }
      } else if (currentAction.type == parser.ActionType.uncalledBet) {
        final player = baseGameState.players.firstWhere((p) => p.name == currentAction.playerName);
        // Subtract the returned amount from the player's bet for this street
        currentStreetBets.update(player.seat, (value) => value - currentAction.amount, ifAbsent: () => 0);
      } else if (currentAction.type == parser.ActionType.winsPot) {
        final winningPlayer = playerMap[currentAction.playerName];
        if (winningPlayer != null) {
          playerMap[currentAction.playerName] = parser.Player(
              seat: winningPlayer.seat,
              name: winningPlayer.name,
              stack: winningPlayer.stack + currentAction.amount, // Add winnings to stack
              holeCards: winningPlayer.holeCards,
              isActive: winningPlayer.isActive);
        }
      }
    }

    final updatedPlayers = playerMap.values.map((p) {
      return parser.Player(
        seat: p.seat,
        name: p.name,
        stack: p.stack,
        holeCards: p.holeCards,
        isActive: p.isActive && !foldedPlayers.contains(p.name), // Keep isActive logic
      );
    }).toList();

    final currentBetsOnTable = currentStreetBets.entries.map((e) => parser.Bet(seat: e.key, amount: e.value)).toList();
    
    // Calculate the pot on the table *before* distribution
    int potBeforeDistribution = accumulatedPot + currentStreetBets.values.fold(0, (a, b) => a + b);

    // Subtract any winnings that have been distributed in the current set of actions
    final winningsDistributed = activeActions
        .where((a) => a.type == parser.ActionType.winsPot)
        .fold<int>(0, (sum, action) => sum + action.amount);

    final potOnTableAfterDistribution = potBeforeDistribution - winningsDistributed;
    final pots = potOnTableAfterDistribution > 0 ? [parser.Pot(amount: potOnTableAfterDistribution)] : <parser.Pot>[];

    setState(() {
      _currentGameState = parser.GameState(
        gameId: baseGameState.gameId,
        players: updatedPlayers,
        buttonSeat: baseGameState.buttonSeat,
        // Only show bets for the current street on the table
        bets: currentBetsOnTable,
        actions: baseGameState.actions,
        pots: pots,
        communityCards: visibleCommunityCards,
      );
    });
  }

  void _nextMove() {
    if (_currentGameState == null || _currentActionIndex >= _currentGameState!.actions.length - 1) return;

    _actionBillboardTimer?.cancel();

    setState(() {
      _currentActionIndex++;
      final lastAction = _currentGameState!.actions[_currentActionIndex];

      // Set the info for the billboard, but only for player actions (not dealing cards)
      if (lastAction.playerName.isNotEmpty) {
        _lastActionInfo = _LastActionInfo(lastAction.playerName, lastAction.type as parser.ActionType);

        // Set a timer to clear the billboard after 1 second
        _actionBillboardTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _lastActionInfo = null;
            });
          }
        });
      } else {
        // If it's a dealing action, ensure no billboard is shown
        _lastActionInfo = null;
      }

      _updateGameState();
    });
  }

  void _prevMove() {
    if (_currentGameState == null || _currentActionIndex < 0) return;

    _actionBillboardTimer?.cancel();

    setState(() {
      _currentActionIndex--;
      print('Prev Move: new index $_currentActionIndex');
      _lastActionInfo = null; // Clear billboard when going backwards
      _updateGameState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canGoToPrevHand = _parser != null && _currentHandIndex > 0;
    final canGoToNextHand = _parser != null && _currentHandIndex < _parser!.handCount - 1;

    void _prevHand() {
      if (!canGoToPrevHand) return;
      setState(() {
        _currentHandIndex--;
        _currentActionIndex = -1;
        _lastActionInfo = null;
        _updateGameState();
      });
    }

    void _nextHand() {
      if (!canGoToNextHand) return;
      setState(() {
        _currentHandIndex++;
        _currentActionIndex = -1;
        _lastActionInfo = null;
        _updateGameState();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _handHistoryText == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Load a hand history file to begin.'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Load .txt File'),
                    onPressed: _pickFile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Builder(builder: (context) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.7,
                    ),
                    child: GameBoardWidget(
                        gameId: _currentGameState?.gameId,
                        buttonSeat: _currentGameState?.buttonSeat,
                        players: _currentGameState?.players,
                        bets: _currentGameState?.bets,
                        pots: _currentGameState?.pots,
                        communityCards: _currentGameState?.communityCards,
                        lastAction: _lastActionInfo != null ? _lastActionInfo! : null),
                  );
                }),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      ElevatedButton.icon(
                        onPressed: canGoToPrevHand ? _prevHand : null,
                        icon: const Icon(Icons.skip_previous),
                        label: const Text('Last Hand'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _prevMove,
                        icon: const Icon(Icons.fast_rewind),
                        label: const Text('Prev Move'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _nextMove,
                        icon: const Icon(Icons.fast_forward),
                        label: const Text('Next Move'),
                      ),
                      ElevatedButton.icon(
                        onPressed: canGoToNextHand ? _nextHand : null,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Next Hand'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}