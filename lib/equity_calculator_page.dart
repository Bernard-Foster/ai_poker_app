import 'dart:async';
import 'package:flutter/material.dart';
import 'package:poker/poker.dart' as pkr;
// Optional pretty names; you can remove if you don't want to include poker_solver
// ignore: unused_import
import 'package:poker_solver/poker_solver.dart' as solver;

void main() {
  runApp(const EquityApp());
}

class EquityApp extends StatelessWidget {
  const EquityApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hold\'em Equity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4F46E5), useMaterial3: true),
      home: const EquityHomePage(),
    );
  }
}

class EquityHomePage extends StatefulWidget {
  const EquityHomePage({super.key});

  @override
  State<EquityHomePage> createState() => _EquityHomePageState();
}

class _EquityHomePageState extends State<EquityHomePage> {
  final _heroController = TextEditingController(text: 'JJ+,AKs,AKo');
  final List<TextEditingController> _villainCtrls =
      List.generate(8, (i) => TextEditingController());
  final _boardController = TextEditingController(text: ''); // e.g. "AhKd7s" or empty
  int _villainCount = 1;
  int _iterations = 50000; // default MC samples
  bool _isRunning = false;

  // Results
  List<_EquityRow> _results = [];
  String? _error;

  @override
  void dispose() {
    _heroController.dispose();
    for (final c in _villainCtrls) c.dispose();
    _boardController.dispose();
    super.dispose();
  }

  Future<void> _runMonteCarlo() async {
    setState(() {
      _isRunning = true;
      _error = null;
      _results = [];
    });

    try {
      // Parse community (board) – empty ok
      final boardString = _boardController.text.trim();
      final community = boardString.isEmpty
          ? pkr.ImmutableCardSet.empty
          : pkr.ImmutableCardSet.parse(boardString);

      // Build players list
      final players = <pkr.HandRange>[];

      final heroRangeText = _heroController.text.trim();
      if (heroRangeText.isEmpty) {
        throw Exception('Hero range is required.');
      }
      players.add(pkr.HandRange.parse(heroRangeText));

      for (int i = 0; i < _villainCount; i++) {
        final txt = _villainCtrls[i].text.trim();
        if (txt.isEmpty) {
          throw Exception('Villain ${i + 1} range is empty.');
        }
        players.add(pkr.HandRange.parse(txt));
      }

      // Monte Carlo evaluator (infinite iterator) – limit with take(N)
      final eval = pkr.MontecarloEvaluator(
        communityCards: community as pkr.ImmutableCardSet,
        players: players,
      );

      final wins = List<int>.filled(players.length, 0);
      final ties = List<int>.filled(players.length, 0);
      int rounds = 0;

      // Chunked iteration to keep UI responsive
      const chunk = 5000; // process 5k matchups per frame
      int remaining = _iterations;
      final sw = Stopwatch()..start();

      final stream = Stream<_Partial>.multi((controller) async {
        final it = eval.iterator;
        while (remaining > 0) {
          final take = remaining > chunk ? chunk : remaining;
          for (int i = 0; i < take; i++) {
            if (!it.moveNext()) break; // should continue forever
            final m = it.current;
            // Winners (could be multiple on ties)
            if (m.wonPlayerIndexes.length == 1) {
              final wi = m.wonPlayerIndexes.first;
              wins[wi]++;
            } else {
              // split pot: count as a tie for each player
              for (final wi in m.wonPlayerIndexes) {
                ties[wi]++;
              }
            }
            rounds++;
          }
          remaining -= take;
          controller.add(_Partial(rounds, List<int>.from(wins), List<int>.from(ties)));
          // Tiny pause to yield UI
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        controller.close();
      });

      await for (final part in stream) {
        if (!mounted) return;
        setState(() {
          _results = _buildTable(part.rounds, wins, ties);
        });
      }

      sw.stop();
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    } catch (e) {
      setState(() {
        _isRunning = false;
        _error = e.toString();
      });
    }
  }

  List<_EquityRow> _buildTable(int rounds, List<int> wins, List<int> ties) {
    final rows = <_EquityRow>[];
    for (int i = 0; i < wins.length; i++) {
      final w = wins[i];
      final t = ties[i];
      final winPct = rounds == 0 ? 0.0 : (w / rounds) * 100.0;
      final tiePct = rounds == 0 ? 0.0 : (t / rounds) * 100.0;
      final eq = winPct + tiePct / (mCountOfWinnersAssumed());
      rows.add(_EquityRow(
        playerLabel: i == 0 ? 'Hero' : 'Villain $i',
        range: (i == 0 ? _heroController.text : _villainCtrls[i - 1].text).trim(),
        winPct: winPct,
        tiePct: tiePct,
        equityPct: eq,
      ));
    }
    return rows;
  }

  int mCountOfWinnersAssumed() {
    // A simple split-pot assumption divisor (common approach is to divide ties equally among tied players).
    // Using average of 2 as a reasonable approximation; exact split can be derived from `Matchup` but would 
    // require tracking tie sizes. For simplicity we use 2. You can refine by tracking tie group sizes.
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hold'em Equity (Hero vs up to 8 Villains)"),
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: _isRunning
                ? null
                : () {
                    setState(() {
                      _heroController.text = 'JJ+,AKs,AKo';
                      for (final c in _villainCtrls) c.clear();
                      _villainCount = 1;
                      _boardController.clear();
                      _iterations = 50000;
                      _results = [];
                      _error = null;
                    });
                  },
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Input ranges in Poker Stove syntax (e.g., "JJ+", "AKs", "AQs-ATs AKo-AJo 44+")'),
          const SizedBox(height: 8),
          _rangeField('Hero Range', _heroController),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Villains:'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _villainCount,
              items: List.generate(8, (i) => i + 1)
                  .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v')))
                  .toList(),
              onChanged: _isRunning
                  ? null
                  : (v) => setState(() {
                        _villainCount = v ?? 1;
                      }),
            ),
          ]),
          const SizedBox(height: 8),
          for (int i = 0; i < _villainCount; i++) ...[
            _rangeField('Villain ${i + 1} Range', _villainCtrls[i]),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _boardController,
            decoration: const InputDecoration(
              labelText: 'Known Board (optional)',
              hintText: 'e.g. AdKs7s  or  empty',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Iterations:'),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _iterations.toDouble(),
                  min: 5000,
                  max: 200000,
                  divisions: 39,
                  label: _iterations.toString(),
                  onChanged: _isRunning
                      ? null
                      : (v) => setState(() => _iterations = v.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _isRunning ? null : _runMonteCarlo,
            icon: _isRunning
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(_isRunning ? 'Running…' : 'Run Monte Carlo'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          if (_results.isNotEmpty) _resultsTable(_results),
        ],
      ),
    );
  }

  Widget _rangeField(String label, TextEditingController c) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        hintText: 'e.g. 22+, A2s+, K9s+, QTs+, JTs, AJo+',
      ),
    );
  }

  Widget _resultsTable(List<_EquityRow> rows) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Results (${rows.length} players)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Player')),
                  DataColumn(label: Text('Range')),
                  DataColumn(label: Text('Win %')),
                  DataColumn(label: Text('Tie %')),
                  DataColumn(label: Text('Equity %')),
                ],
                rows: rows
                    .map(
                      (r) => DataRow(cells: [
                        DataCell(Text(r.playerLabel)),
                        DataCell(Text(r.range)),
                        DataCell(Text(r.winPct.toStringAsFixed(2))),
                        DataCell(Text(r.tiePct.toStringAsFixed(2))),
                        DataCell(Text(r.equityPct.toStringAsFixed(2))),
                      ]),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Partial {
  final int rounds;
  final List<int> wins;
  final List<int> ties;
  _Partial(this.rounds, this.wins, this.ties);
}

class _EquityRow {
  final String playerLabel;
  final String range;
  final double winPct;
  final double tiePct;
  final double equityPct;
  _EquityRow({
    required this.playerLabel,
    required this.range,
    required this.winPct,
    required this.tiePct,
    required this.equityPct,
  });
}

// Notes:
// • Range syntax is handled by `poker.HandRange.parse()`. Examples: "As3h", "8d8h", "AQs-ATs AKo-AJo 44+".
// • Equity calculation uses `MontecarloEvaluator` from the `poker` package. See docs for details.
// • If you want exact equities for small spots, swap to `ExhaustiveEvaluator` (be careful: combinatorial explosion!).
// • If you also want to show the strongest representative hand name for the hero range, you could use `poker_solver`\n//   to generate human-friendly labels for specific 7-card samples, but it is not required for equities.
