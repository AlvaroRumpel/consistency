import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

abstract class BaseController<State> {
  final ValueNotifier<State> _state;

  State get state => _state.value;

  ValueNotifier<State> get stateNotifier => _state;

  BaseController(
    State initialState,
  ) : _state = ValueNotifier(initialState) {
    onInit();
  }
  void onInit() {}

  void onDispose() {
    _state.dispose();
  }

  void emit(State newState) {
    _state.value = newState;
  }

  FutureOr<void> emitGuard({
    required State loadingState,
    required FutureOr<State> Function(State oldState) newState,
    required State Function(Object? err) errorState,
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
