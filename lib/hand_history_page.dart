import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:poker_app/game_board_widget.dart';

class HandHistoryPage extends StatefulWidget {
  const HandHistoryPage({super.key, required this.title});

  final String title;

  @override
  State<HandHistoryPage> createState() => _HandHistoryPageState();
}

class _HandHistoryPageState extends State<HandHistoryPage> {
  String? _handHistoryText;

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
        setState(() => _handHistoryText = contents);
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
                const GameBoardWidget(), // This will stay at the top
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