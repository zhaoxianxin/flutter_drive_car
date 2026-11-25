import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_driver/game/game_model.dart';
import 'package:little_driver/game/road_painter.dart';
import 'package:little_driver/main.dart';

void main() {
  test(
    'All four pickups immediately transform and clear queued transformations',
    () {
      for (final form in VehicleForm.values.skip(1)) {
        final g = GameModel()..state = PlayState.driving;
        g.items.addAll([
          RoadItem(0, .75, form.pickup),
          RoadItem(0, .1, ItemKind.tank),
        ]);
        g.update(.016);
        expect(g.form, form);
        expect(g.formTime, 10);
        expect(g.items.where((a) => isTransform(a.kind)), isEmpty);
        expect(g.inventory.values.every((a) => a == 0), isTrue);
      }
    },
  );
  test('Transformation smashes obstacles with shards and without slowing', () {
    final g = GameModel()..state = PlayState.driving;
    g.transform(VehicleForm.tank);
    g.items.add(RoadItem(0, .75, ItemKind.cone));
    g.update(.016);
    expect(g.smashed, 1);
    expect(g.bumps, 0);
    expect(g.slow, 0);
    expect(g.sparks.where((p) => p.shard).length, 18);
    expect(g.events, contains('smash'));
  });
  test('No transformation spawns during any active form; expires safely', () {
    final g = GameModel(random: Random(3))..state = PlayState.driving;
    g.transform(VehicleForm.plane);
    for (var i = 0; i < 100; i++) {
      g.spawn();
    }
    expect(g.items.where((a) => isTransform(a.kind)), isEmpty);
    g.pause();
    g.update(.05);
    expect(g.formTime, 10);
    g.resume();
    for (var i = 0; i < 201; i++) {
      g.update(.05);
    }
    expect(g.form, VehicleForm.car);
    expect(g.shield, greaterThan(0));
    g.items.clear();
    g.rows = 1;
    g.spawn();
    expect(g.items.where((a) => isTransform(a.kind)), isNotEmpty);
  });
  test('Cannot override a running transformation', () {
    final g = GameModel()..state = PlayState.driving;
    g.transform(VehicleForm.peppa);
    g.update(.05);
    g.transform(VehicleForm.dinosaur);
    expect(g.form, VehicleForm.peppa);
    expect(g.formTime, lessThan(10));
  });
  test('Pickups are stored, capped, consumed once and frozen on pause', () {
    final g = GameModel()..state = PlayState.driving;
    for (var i = 0; i < 5; i++) {
      g.items.add(RoadItem(0, .75, ItemKind.bubble));
      g.update(.016);
    }
    expect(g.inventory[PowerUp.bubble], 3);
    expect(g.shield, 0);
    expect(g.usePower(PowerUp.bubble), isTrue);
    expect(g.inventory[PowerUp.bubble], 2);
    expect(g.usePower(PowerUp.bubble), isFalse);
    g.pause();
    g.update(.05);
    expect(g.shield, 8);
    expect(g.usePower(PowerUp.magnet), isFalse);
    g.resume();
    for (var i = 0; i < 161; i++) {
      g.update(.05);
    }
    expect(g.usePower(PowerUp.bubble), isTrue);
  });
  test('Magnet attracts adjacent coins and rainbow doubles their value', () {
    final g = GameModel()..state = PlayState.driving;
    g.inventory[PowerUp.magnet] = 1;
    g.inventory[PowerUp.rainbow] = 1;
    g.usePower(PowerUp.magnet);
    g.usePower(PowerUp.rainbow);
    final coin = RoadItem(.72, .6, ItemKind.coin);
    g.items.add(coin);
    for (var i = 0; i < 25; i++) {
      g.update(.04);
    }
    expect(g.coins, 2);
    expect(g.items.contains(coin), isFalse);
  });
  test(
    'Projected positions remain ordered and car and item share contact plane',
    () {
      final road = RoadProjection(const Size(390, 844), 2, .5);
      expect(road.project(0, .3).dy, lessThan(road.project(0, .76).dy));
      expect(road.scale(.3), lessThan(road.scale(.76)));
      expect(road.project(-.72, .76).dx, lessThan(road.project(0, .76).dx));
    },
  );
  testWidgets('All forms and worlds paint without exceptions', (tester) async {
    for (final world in WorldTheme.all) {
      for (final form in VehicleForm.values) {
        final g = GameModel()..state = PlayState.driving;
        if (form != VehicleForm.car) g.transform(form);
        for (final kind in ItemKind.values) {
          g.items.add(RoadItem(-.72, .35 + kind.index * .035, kind));
        }
        await tester.pumpWidget(
          MaterialApp(
            home: CustomPaint(
              painter: RoadPainter(game: g, world: world),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('Collected power can be activated through the gameplay button', (
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
    await tester.binding.setSurfaceSize(const Size(390, 736));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const LittleDriverApp());
    await tester.pump();
    await tester.ensureVisible(find.text('开车出发'));
    await tester.tap(find.text('开车出发'));
    await tester.pump();
    final dynamic state = tester.state(find.byType(DriverHome));
    final GameModel g = state.game as GameModel;
    g.state = PlayState.driving;
    g.inventory[PowerUp.magnet] = 1;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('小磁铁'));
    await tester.pump();
    expect(g.magnetTime, greaterThan(7));
    expect(g.inventory[PowerUp.magnet], 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
