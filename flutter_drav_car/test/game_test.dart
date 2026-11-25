import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_driver/game/game_model.dart';
import 'package:little_driver/main.dart';

void main() {
  test('Steering is bounded and eased', () {
    final g = GameModel()..state = PlayState.driving;
    g.steer(8);
    g.update(.05);
    expect(g.target, 1);
    expect(g.x, greaterThan(0));
    expect(g.x, lessThan(1));
    for (var i = 0; i < 100; i++) {
      g.update(.05);
    }
    expect(g.x, closeTo(1, .001));
    g.steer(-8);
    expect(g.target, -1);
  });
  test('Coins are collected once', () {
    final g = GameModel()..state = PlayState.driving;
    g.items.add(RoadItem(0, .75, ItemKind.coin));
    g.update(.016);
    expect(g.coins, 1);
    expect(g.events, ['coin']);
    g.update(.016);
    expect(g.coins, 1);
  });
  test('Collision grants protection and never deducts coins', () {
    final g = GameModel()
      ..state = PlayState.driving
      ..coins = 5;
    g.items.add(RoadItem(0, .75, ItemKind.cone));
    g.update(.016);
    expect(g.bumps, 1);
    expect(g.slow, greaterThan(0));
    expect(g.shield, greaterThan(2));
    g.items.add(RoadItem(0, .75, ItemKind.cone));
    g.update(.016);
    expect(g.bumps, 1);
    expect(g.coins, 5);
  });
  test('Pause freezes countdown, driving and particles', () {
    final g = GameModel()..start();
    g.pause();
    g.update(.05);
    expect(g.countdown, 3);
    g.resume();
    g.update(.05);
    expect(g.countdown, lessThan(3));
    g.state = PlayState.driving;
    g.pause();
    g.update(.05);
    expect(g.time, 90);
  });
  test('Every generated row has safe lanes and coins never overlap cones', () {
    final g = GameModel(random: Random(42))..distance = 1;
    for (var i = 0; i < 200; i++) {
      g.items.clear();
      g.spawn();
      final cones = g.items.where((a) => a.kind == ItemKind.cone);
      expect(cones.length, lessThanOrEqualTo(1));
      for (final c in cones) {
        expect(
          g.items.where((a) => a.kind == ItemKind.coin && a.x == c.x),
          isEmpty,
        );
      }
    }
  });
  test('A full session completes with no steering and emits finish once', () {
    final g = GameModel(random: Random(1))..state = PlayState.driving;
    for (var i = 0; i < 1801; i++) {
      g.update(.05);
    }
    expect(g.state, PlayState.finished);
    expect(g.time, 0);
    expect(g.stars, greaterThanOrEqualTo(1));
    expect(g.events.where((e) => e == 'finish').length, 1);
  });
  test('Tilt calibration, direction, jitter and flat-phone guard', () {
    final t = TiltController();
    for (var i = 0; i < 30; i++) {
      t.sample(0, 9, 2);
    }
    expect(t.filtered, 0);
    for (var i = 0; i < 30; i++) {
      t.sample(-4, 8, 2);
    }
    expect(t.filtered, greaterThan(.9));
    t.calibrate();
    expect(t.sample(-4, 8, 2), closeTo(0, .001));
    expect(t.sample(0, 0, 9), closeTo(0, .001));
    for (var i = 0; i < 30; i++) {
      t.sample(4, 8, 2);
    }
    expect(t.filtered, lessThan(-.9));
  });
  testWidgets('Home and preparation flow render without overflow', (
    tester,
  ) async {
    // A widget test has no physical sensor; acknowledge stream registration.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('little_driver/tilt'),
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('little_driver/tilt'),
        null,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const LittleDriverApp());
    await tester.pump();
    expect(find.text('小小司机'), findsOneWidget);
    await tester.tap(find.text('开车出发'));
    await tester.pump();
    expect(find.text('准备好小手了吗？'), findsOneWidget);
    await tester.tap(find.text('准备好啦，出发！'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.pumpWidget(const LittleDriverApp(key: ValueKey('reset')));
  });
}
