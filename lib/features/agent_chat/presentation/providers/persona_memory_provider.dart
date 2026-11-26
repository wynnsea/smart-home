import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/app_local_storage.dart';
import '../../domain/entities/ai_gateway_entities.dart';

class PersonaMemoryNotifier extends Notifier<String> {
  @override
  String build() => AppLocalStorage.loadPersonaMemory();

  void updateMemory(String text) {
    state = text.trim();
    unawaited(AppLocalStorage.savePersonaMemory(state));
  }

  void resetToDefault() {
    state = kDefaultPersonalMemory;
    unawaited(AppLocalStorage.savePersonaMemory(state));
  }
}

final personaMemoryProvider = NotifierProvider<PersonaMemoryNotifier, String>(
  PersonaMemoryNotifier.new,
);
