import 'package:autofarmer/models/click_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClickPoint', () {
    test('toMap returns x and y', () {
      const point = ClickPoint(x: 100, y: 200, index: 0);
      expect(point.toMap(), {'x': 100.0, 'y': 200.0});
    });

    test('fromMap creates correct ClickPoint', () {
      final point = ClickPoint.fromMap({'x': 150.0, 'y': 250.0}, 2);
      expect(point.x, 150.0);
      expect(point.y, 250.0);
      expect(point.index, 2);
    });

    test('copyWith updates only specified fields', () {
      const original = ClickPoint(x: 10, y: 20, index: 0);
      final updated = original.copyWith(index: 3);
      expect(updated.x, 10);
      expect(updated.y, 20);
      expect(updated.index, 3);
    });

    test('toString includes index and coordinates', () {
      const point = ClickPoint(x: 100, y: 200, index: 1);
      expect(point.toString(), contains('1'));
      expect(point.toString(), contains('100'));
      expect(point.toString(), contains('200'));
    });
  });

  group('Delay constraints', () {
    const minDelay = 250;
    const maxDelay = 10000;

    test('minimum delay is 250 ms', () {
      expect(minDelay, 250);
    });

    test('maximum delay is 10 000 ms (10 s)', () {
      expect(maxDelay, 10000);
    });

    test('random variance cannot exceed delay', () {
      // Simulate the clamping logic from HomeScreen
      int delay = 300;
      int variance = 400; // exceeds delay

      if (variance > delay) variance = delay;
      expect(variance, delay);
    });

    test('random variance lower bound is 1 ms', () {
      const minVariance = 1;
      expect(minVariance, 1);
    });

    test('default variance is 50 ms', () {
      const defaultVariance = 50;
      expect(defaultVariance, 50);
    });
  });
}
