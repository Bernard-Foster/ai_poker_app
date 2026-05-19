// lib/game_table_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:poker/poker.dart' as pkr;
import 'package:poker_app/features/table/game_engine.dart';

class GameTablePage extends StatefulWidget {
  const GameTablePage({super.key});

  @override
  State<GameTablePage> createState() => _GameTablePageState();
}

class _GameTablePageState extends State<GameTablePage> {
  int _seats = 6; // adjustable 2–9
  final List<String?> _board = List<String?>.filled(5, null);
  late List<_SeatModel> _players;
  GameEngine? _gameEngine;

  @override
  void initState() {
    super.initState();
    _players = List.generate(_seats, (i) => _SeatModel(index: i));
  }

  void _setSeats(int v) {
    setState(() {
      _seats = v.clamp(2, 9);
      _players = List.generate(_seats, (i) => _SeatModel(index: i));
      _gameEngine = null; // Reset game on seat change
    });
  }

  void _deal() {
    setState(() {
      int nextButtonPosition = 0;
      if (_gameEngine != null) {
        // If a game engine already exists, advance the button from its current position
        nextButtonPosition = (_gameEngine!.button + 1) % _seats;
      }
      // Always create a new GameEngine for a new hand to get a fresh deck
      _gameEngine = GameEngine(
        playerCount: _seats,
        button: nextButtonPosition,
        startingStack: 1000,
      );
      _gameEngine!.dealPreFlop(); // This will shuffle and deal from a fresh deck

      // Update the UI models with the dealt cards
      for (int i = 0; i < _seats; i++) {
        _players[i].cardA = _gameEngine!.holeCards[i][0].toString();
        _players[i].cardB = _gameEngine!.holeCards[i][1].toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table'),
        actions: [
          IconButton(
            tooltip: 'New Layout',
            onPressed: () {
              setState(() {
                // reset only visuals for now
                for (var i = 0; i < _board.length; i++) _board[i] = null;
                for (final p in _players) {
                  p.cardA = null;
                  p.cardB = null;
                }
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          final tableSize = size * 0.9;
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
          final radius = tableSize * 0.38;

          return Stack(
            children: [
              // Felt/table oval
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: tableSize,
                  height: tableSize * 0.65,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(tableSize),
                    border: Border.all(color: Colors.black12),
                    boxShadow: const [BoxShadow(blurRadius: 24, color: Colors.black12)],
                  ),
                ),
              ),

              // Community cards (center)
              Center(
                child: _boardStrip(context),
              ),

              // Seats around the table (polar positions)
              ...List.generate(_seats, (i) {
                final angle = _seatAngle(i, _seats);
                final pos = _polar(center, radius, angle);
                return Positioned(
                  left: pos.dx - 84,
                  top: pos.dy - 40,
                  child: _seatCard(context, _players[i]),
                );
              }),

              // Top control bar
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _controlBar(context),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Simple horizontal strip for 5 board cards (face-down placeholders for now)
  Widget _boardStrip(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => Padding(
              padding: EdgeInsets.only(right: i == 4 ? 0 : 8),
              child: _cardChip(_board[i], dimIfNull: true),
            ),
          ),
        ),
      ),
    );
  }

  /// A player seat widget (name + 2 card placeholders)
  Widget _seatCard(BuildContext context, _SeatModel m) {
    return Card(
      elevation: 0,
      // Add a subtle border to highlight active players
      shape: RoundedRectangleBorder(
        side: m.cardA != null
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        width: 168,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Player ${m.index + 1}',
                style: Theme.of(context).textTheme.labelLarge),
            if (_gameEngine != null)
              Text('Stack: ${_gameEngine!.stacks[m.index]}',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _cardChip(m.cardA, dimIfNull: true),
                const SizedBox(width: 8),
                _cardChip(m.cardB, dimIfNull: true),
              ],
            ),
            // Blind indicators
            if (_gameEngine != null && m.cardA != null) ...[
              const SizedBox(height: 8),
              if (m.index == _gameEngine!.sbPos)
                _blindIndicator('SB', Colors.blue.shade700)
              else if (m.index == _gameEngine!.bbPos)
                _blindIndicator('BB', Colors.red.shade700)
              else if (m.index == _gameEngine!.button)
                _blindIndicator('D', Colors.grey.shade700),
            ] else ...[
              // Keep consistent height even when there's no indicator
              const SizedBox(height: 8 + 24),]
          ]
        ),
      ),
    );
  }

  /// Bottom controls: seat count and placeholders for later (deal, etc.)
  Widget _controlBar(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          runSpacing: 8,
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Players:'),
            DropdownButton<int>(
              value: _seats,
              items: [2, 3, 4, 5, 6, 7, 8, 9]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) => _setSeats(v ?? _seats),
            ),
            const VerticalDivider(width: 24),
            FilledButton.tonal(onPressed: _deal, child: const Text('Deal')),
            FilledButton.tonal(onPressed: null, child: const Text('Flop')),
            FilledButton.tonal(onPressed: null, child: const Text('Turn')),
            FilledButton.tonal(onPressed: null, child: const Text('River')),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text('Showdown'),
            ),
          ],
        ),
      ),
    );
  }

  /// Simple text chip for a card (e.g., "Ah"), dimmed if null
  Widget _cardChip(String? code, {bool dimIfNull = false}) {
    final t = code ?? '—';
    final isRed = t.endsWith('h') || t.endsWith('d');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Text(
        t,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: code == null
              ? Colors.black38
              : (isRed ? Colors.red.shade700 : Colors.black87),
        ),
      ),
    );
  }

  /// A chip-like indicator for Blinds (SB, BB) or Dealer (D)
  Widget _blindIndicator(String label, Color color) {
    return Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }

  // --- geometry helpers ---
  double _seatAngle(int index, int total) {
    // Distribute seats around the ellipse; start at top and go clockwise.
    // Offset the angle slightly so seats don’t overlap control bar.
    //  -90° so index 0 is at top (12 o'clock)
    return (-90 + (360 / total) * index) * (math.pi / 180.0);
  }

  Offset _polar(Offset center, double radius, double angle) {
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }
}

class _SeatModel {
  final int index;
  String? cardA;
  String? cardB;
  _SeatModel({required this.index, this.cardA, this.cardB});
}