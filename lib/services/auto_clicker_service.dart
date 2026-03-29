import 'dart:async';

import 'package:flutter/services.dart';

class AutoClickerService {
  static const _methodChannel =
      MethodChannel('com.autofarmer.autoclicker/control');
  static const _eventChannel =
      EventChannel('com.autofarmer.autoclicker/events');

  Stream<Map<dynamic, dynamic>>? _eventStream;

  /// Broadcast stream of events from the native overlay and auto-clicker.
  Stream<Map<dynamic, dynamic>> get events {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as Map<dynamic, dynamic>);
    return _eventStream!;
  }

  Future<bool> checkOverlayPermission() async {
    return await _methodChannel
            .invokeMethod<bool>('checkOverlayPermission') ??
        false;
  }

  Future<void> requestOverlayPermission() async {
    await _methodChannel.invokeMethod<void>('requestOverlayPermission');
  }

  Future<bool> checkAccessibilityPermission() async {
    return await _methodChannel
            .invokeMethod<bool>('checkAccessibilityPermission') ??
        false;
  }

  Future<void> requestAccessibilityPermission() async {
    await _methodChannel.invokeMethod<void>('requestAccessibilityPermission');
  }

  Future<void> startOverlay() async {
    await _methodChannel.invokeMethod<void>('startOverlay');
  }

  Future<void> stopOverlay() async {
    await _methodChannel.invokeMethod<void>('stopOverlay');
  }

  Future<void> startAutoClicker({
    required List<Map<String, dynamic>> points,
    required int delayMs,
    required int randomVarianceMs,
  }) async {
    await _methodChannel.invokeMethod<void>('startAutoClicker', {
      'points': points,
      'delay': delayMs,
      'randomVariance': randomVarianceMs,
    });
  }

  Future<void> stopAutoClicker() async {
    await _methodChannel.invokeMethod<void>('stopAutoClicker');
  }

  Future<bool> isAutoClickerRunning() async {
    return await _methodChannel.invokeMethod<bool>('isAutoClickerRunning') ??
        false;
  }
}
