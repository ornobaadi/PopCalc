import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class HistoryEntry {
  final String id;
  final String expression;
  final String result;
  final DateTime timestamp;

  HistoryEntry({
    required this.id,
    required this.expression,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'expression': expression,
        'result': result,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        expression: json['expression'] as String,
        result: json['result'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  HistoryNotifier() : super([]) {
    loadHistory();
  }

  static const int maxFreeEntries = 50;
  File? _file;
  int _idCounter = 0;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/calc_history.jsonl');
      return _file!;
    } catch (_) {
      // In web or tests where path_provider might not have native paths
      return File('calc_history.jsonl');
    }
  }

  Future<void> loadHistory() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;

      final lines = await file.readAsLines();
      final loaded = <HistoryEntry>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          loaded.add(HistoryEntry.fromJson(jsonDecode(line) as Map<String, dynamic>));
        } catch (_) {}
      }
      // Merge with entries added while loading was in flight, then cap.
      final merged = [...state, ...loaded.reversed];
      state = merged.take(maxFreeEntries).toList();

      // The file is append-only, so compact it once it outgrows the cap.
      if (lines.length > maxFreeEntries * 2) {
        await _saveAll();
      }
    } catch (_) {}
  }

  Future<void> addEntry(String expression, String result) async {
    if (expression.isEmpty || result.isEmpty) return;

    final entry = HistoryEntry(
      // Counter suffix keeps ids unique even within the same millisecond.
      id: '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
      expression: expression,
      result: result,
      timestamp: DateTime.now(),
    );

    final updated = [entry, ...state];
    if (updated.length > maxFreeEntries) {
      updated.removeLast();
    }
    state = updated;

    try {
      final file = await _getFile();
      await file.writeAsString(
        '${jsonEncode(entry.toJson())}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  Future<void> removeEntry(String id) async {
    state = state.where((e) => e.id != id).toList();
    _saveAll();
  }

  Future<void> clearHistory() async {
    state = [];
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _saveAll() async {
    try {
      final file = await _getFile();
      final buffer = StringBuffer();
      for (final entry in state.reversed) {
        buffer.writeln(jsonEncode(entry.toJson()));
      }
      await file.writeAsString(buffer.toString());
    } catch (_) {}
  }
}
