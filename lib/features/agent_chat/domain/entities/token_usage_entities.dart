import 'package:material_ui/material_ui.dart';

/// Single AI request token usage record.
@immutable
class TokenUsageRecord {
  const TokenUsageRecord({
    required this.timestampIso,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.source,
  });

  final String timestampIso;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final String source;

  DateTime? get timestamp => DateTime.tryParse(timestampIso);

  Map<String, Object?> toJson() => {
    'timestampIso': timestampIso,
    'model': model,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
    'source': source,
  };

  factory TokenUsageRecord.fromJson(Map<String, dynamic> map) {
    final p = (map['promptTokens'] as num?)?.toInt() ?? 0;
    final c = (map['completionTokens'] as num?)?.toInt() ?? 0;
    final t = (map['totalTokens'] as num?)?.toInt() ?? (p + c);
    return TokenUsageRecord(
      timestampIso: map['timestampIso']?.toString() ?? '',
      model: map['model']?.toString() ?? 'unknown',
      promptTokens: p,
      completionTokens: c,
      totalTokens: t,
      source: map['source']?.toString() ?? 'OpenRouter',
    );
  }
}

/// Aggregated AI token consumption state with customizable daily budget.
@immutable
class TokenUsageState {
  const TokenUsageState({
    this.dailyBudget = 100000,
    this.records = const [],
  });

  final int dailyBudget;
  final List<TokenUsageRecord> records;

  List<TokenUsageRecord> get todayRecords {
    final now = DateTime.now();
    return records.where((r) {
      final dt = r.timestamp;
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
  }

  int get todayPromptTokens =>
      todayRecords.fold(0, (sum, r) => sum + r.promptTokens);

  int get todayCompletionTokens =>
      todayRecords.fold(0, (sum, r) => sum + r.completionTokens);

  int get todayTotalTokens =>
      todayRecords.fold(0, (sum, r) => sum + r.totalTokens);

  int get allTimeTotalTokens =>
      records.fold(0, (sum, r) => sum + r.totalTokens);

  int get todayRequestCount => todayRecords.length;

  double get budgetProgress =>
      dailyBudget <= 0 ? 0.0 : (todayTotalTokens / dailyBudget).clamp(0.0, 1.0);

  int get budgetPercent => (budgetProgress * 100).round();

  bool get isNearLimit => budgetProgress >= 0.8;

  Map<String, int> get todayByModel {
    final map = <String, int>{};
    for (final r in todayRecords) {
      map[r.model] = (map[r.model] ?? 0) + r.totalTokens;
    }
    return map;
  }

  TokenUsageState copyWith({
    int? dailyBudget,
    List<TokenUsageRecord>? records,
  }) {
    return TokenUsageState(
      dailyBudget: dailyBudget ?? this.dailyBudget,
      records: records ?? this.records,
    );
  }
}

/// Compact token count formatter (e.g. `12.4K`, `1.2M`, `840`).
String formatTokenCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return '$count';
}
