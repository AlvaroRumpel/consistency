import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

abstract class BaseController<S> {
  final ValueNotifier<S> _state;
  bool _disposed = false;

  S get state => _state.value;

  ValueNotifier<S> get stateNotifier => _state;

  BaseController(
    S initialState,
  ) : _state = ValueNotifier(initialState) {
    onInit();
  }
  void onInit() {}

  void onDispose() {
    _disposed = true;
    _state.dispose();
  }

  /// Late listeners (a store notifying after the page is gone) must not
  /// touch a disposed notifier.
  void emit(S newState) {
    if (_disposed) return;
    _state.value = newState;
  }

  FutureOr<void> emitGuard({
    required S loadingState,
    required FutureOr<S> Function(S oldState) newState,
    required S Function(Object? err) errorState,
  }) async {
    try {
      final oldState = state;
      emit(loadingState);
      final resultState = await newState(oldState);
      emit(resultState);
    } catch (e, s) {
      log('Error on Emit Guard', error: e, stackTrace: s);
      emit(errorState(e));
    }
  }
}
