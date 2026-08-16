import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

abstract class BaseController<S> {
  final ValueNotifier<S> _state;

  S get state => _state.value;

  ValueNotifier<S> get stateNotifier => _state;

  BaseController(
    S initialState,
  ) : _state = ValueNotifier(initialState) {
    onInit();
  }
  void onInit() {}

  void onDispose() {
    _state.dispose();
  }

  void emit(S newState) {
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
