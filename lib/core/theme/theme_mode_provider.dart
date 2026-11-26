import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_local_storage.dart';

class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() => AppLocalStorage.loadDarkMode();

  void setDarkMode(bool value) {
    if (state == value) return;
    state = value;
    unawaited(AppLocalStorage.saveDarkMode(value));
  }

  void toggle() => setDarkMode(!state);
}

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);
