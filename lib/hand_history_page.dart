import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
        });
      } catch (e) {
        setState(() => _handHistoryText = 'Error reading file: $e');
      }
    } else {
      // User canceled the picker
    }
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
                  // For now, let's just display the info for the first hand.
                  final gameState = _parser?.parseHand(0);
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.4,
                    ),
                    child: GameBoardWidget(
                        gameId: gameState?.gameId,
                        buttonSeat: gameState?.buttonSeat,
                        players: gameState?.players,
                        bets: gameState?.bets),
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
                        onPressed: null, // Dummy button
                        icon: const Icon(Icons.skip_previous),
                        label: const Text('Last Hand'),
                      ),
                      ElevatedButton.icon(
                        onPressed: null, // Dummy button
                        icon: const Icon(Icons.fast_rewind),
                        label: const Text('Prev Move'),
                      ),
                      ElevatedButton.icon(
                        onPressed: null, // Dummy button
                        icon: const Icon(Icons.fast_forward),
                        label: const Text('Next Move'),
                      ),
                      ElevatedButton.icon(
                        onPressed: null, // Dummy button
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