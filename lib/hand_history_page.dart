import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:poker_app/hand_history_parser.dart';
import 'package:poker_app/game_board_widget.dart';

class HandHistoryPage extends StatefulWidget {
  const HandHistoryPage({super.key, required this.title});

  final String title;

  @override
  State<HandHistoryPage> createState() => _HandHistoryPageState();
}

class _HandHistoryPageState extends State<HandHistoryPage> {
  String? _handHistoryText;
  HandHistoryParser? _parser;
  int _currentHandIndex = 0;
  int _currentActionIndex = -1; // -1 represents the initial state before any actions
  GameState? _currentGameState;

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
          _parser = HandHistoryParser(contents);
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
    if (_parser == null) return;

    final baseGameState = _parser!.parseHand(_currentHandIndex);
    if (baseGameState == null) return;

    // Create a new state by applying actions up to the current index
    final activeActions = _currentActionIndex >= 0
        ? baseGameState.actions.sublist(0, _currentActionIndex + 1)
        : <Action>[];

    final Set<String> foldedPlayers = activeActions
        .where((a) => a.type == ActionType.fold)
        .map((a) => a.playerName)
        .toSet();

    final updatedPlayers = baseGameState.players.map((p) {
      return Player(
        seat: p.seat,
        name: p.name,
        stack: p.stack,
        holeCards: p.holeCards,
        isActive: p.isActive && !foldedPlayers.contains(p.name),
      );
    }).toList();

    final currentBets = List<Bet>.from(baseGameState.bets);
    for (final action in activeActions) {
      if ((action.type == ActionType.call || action.type == ActionType.raise || action.type == ActionType.bet) && action.amount > 0) {
        final player = updatedPlayers.firstWhere((p) => p.name == action.playerName);
        currentBets.add(Bet(seat: player.seat, amount: action.amount));
      }
    }

    setState(() {
      _currentGameState = GameState(
        gameId: baseGameState.gameId,
        players: updatedPlayers,
        buttonSeat: baseGameState.buttonSeat,
        bets: currentBets,
        actions: baseGameState.actions,
      );
    });
  }

  void _nextMove() {
    if (_currentGameState == null || _currentActionIndex >= _currentGameState!.actions.length - 1) return;
    setState(() {
      _currentActionIndex++;
      _updateGameState();
    });
  }

  void _prevMove() {
    if (_currentGameState == null || _currentActionIndex < 0) return;
    setState(() {
      _currentActionIndex--;
      _updateGameState();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      maxHeight: screenHeight * 0.4,
                    ),
                    child: GameBoardWidget(
                        gameId: _currentGameState?.gameId,
                        buttonSeat: _currentGameState?.buttonSeat,
                        players: _currentGameState?.players,
                        bets: _currentGameState?.bets),
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
                        onPressed: null, // TODO: Implement
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
                      ElevatedButton.icon( // TODO: Implement
                        onPressed: null,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Next Hand'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_handHistoryText!), // This part will be scrollable
                  ),
                ),
              ],
            ),
    );
  }
}