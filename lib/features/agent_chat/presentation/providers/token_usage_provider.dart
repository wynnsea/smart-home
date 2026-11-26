import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/app_local_storage.dart';
import '../../domain/entities/token_usage_entities.dart';

class TokenUsageNotifier extends Notifier<TokenUsageState> {
  @override
  TokenUsageState build() {
    return AppLocalStorage.loadTokenUsage();
  }

  void recordUsage({
    required String model,
    required int promptTokens,
    required int completionTokens,
    required int totalTokens,
    required String source,
  }) {
    final safeTotal = totalTokens > 0
        ? totalTokens
        : (promptTokens + completionTokens);
    if (safeTotal <= 0) return;

    final entry = TokenUsageRecord(
      timestampIso: DateTime.now().toIso8601String(),
      model: model,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: safeTotal,
      source: source,
    );
    final updated = [entry, ...state.records].take(200).toList();
    state = state.copyWith(records: updated);
    unawaited(AppLocalStorage.saveTokenUsage(state));
  }

  void setDailyBudget(int budget) {
    final clamped = budget.clamp(10000, 5000000);
    state = state.copyWith(dailyBudget: clamped);
    unawaited(AppLocalStorage.saveTokenUsage(state));
  }

  void resetToday() {
    final now = DateTime.now();
    final remaining = state.records.where((r) {
      final dt = r.timestamp;
      if (dt == null) return false;
      return !(dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day);
    }).toList();
    state = state.copyWith(records: remaining);
    unawaited(AppLocalStorage.saveTokenUsage(state));
  }

  void resetAll() {
    state = state.copyWith(records: const []);
    unawaited(AppLocalStorage.saveTokenUsage(state));
  }
}

final tokenUsageProvider =
    NotifierProvider<TokenUsageNotifier, TokenUsageState>(
      TokenUsageNotifier.new,
    );
