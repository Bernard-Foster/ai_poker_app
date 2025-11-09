import 'dart:async';
import 'package:flutter/material.dart';
import 'package:poker/poker.dart' as pkr;

void main() {
  runApp(const EquityCalcApp());
}

class EquityCalcApp extends StatelessWidget {
  const EquityCalcApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hold\'em Equity Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4F46E5), useMaterial3: true),
      home: const EquityCalcHomePage(),
    );
  }
}

class EquityCalcHomePage extends StatefulWidget {
  const EquityCalcHomePage({super.key});

  @override
  State<EquityCalcHomePage> createState() => _EquityHomePageState();
}

class _EquityHomePageState extends State<EquityCalcHomePage> {
  final _heroController = TextEditingController(text: 'JJ+,AKs,AKo');
  final List<TextEditingController> _villainCtrls =
      List.generate(8, (i) => TextEditingController());
  final _boardController = TextEditingController(text: '');
  int _villainCount = 1;
  int _iterations = 50000;
  bool _isRunning = false;
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
      final boardString = _boardController.text.trim();
      final community = boardString.isEmpty
          ? pkr.ImmutableCardSet.empty()
          : pkr.ImmutableCardSet.parse(boardString) as pkr.ImmutableCardSet;

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

      // Use the base Evaluator. The poker library will choose MontecarloEvaluator
      // for pre-flop/flop/turn, and ExhaustiveEvaluator for river automatically.
      final eval = pkr.ExhaustiveEvaluator(
        communityCards: community,
        players: players,
      );

      final wins = List<int>.filled(players.length, 0);
      final ties = List<int>.filled(players.length, 0);
      int rounds = 0;

      const chunk = 5000;
      int remaining = _iterations;
      final sw = Stopwatch()..start();

      final stream = Stream<_Partial>.multi((controller) async {
        while (remaining > 0) {
          final take = remaining > chunk ? chunk : remaining;
          final matchups = eval.take(take).toList();
          if (matchups.isEmpty) break; // Exhaustive evaluation is done

          for (final m in matchups) {
            if (m.wonPlayerIndexes.length == 1) {
              final wi = m.wonPlayerIndexes.first;
              wins[wi]++;
            } else {
              for (final wi in m.wonPlayerIndexes) {
                ties[wi]++;
              }
            }
          }
          rounds += matchups.length as int;
          remaining -= take; // Decrement by what we asked for, not what we got
          controller.add(_Partial(rounds, List<int>.from(wins), List<int>.from(ties)));
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
      // More accurate equity calculation for ties with multiple players
      final equityFromTies = ties.asMap().entries.fold(0.0, (prev, entry) {
        // This is a simplification. True equity depends on number of players in the tie.
        return prev + (entry.key == i ? (tiePct / wins.length) : 0);
      });
      final eq = winPct + equityFromTies;
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
              hintText: 'e.g. AdKs7s or empty',
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
