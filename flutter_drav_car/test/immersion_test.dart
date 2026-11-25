import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_driver/game/game_model.dart';

GameModel session() => GameModel(random: Random(7))
  ..state = PlayState.driving
  ..spawnIn = 10000;
void advance(GameModel g, double seconds, [double frame = 1 / 60]) {
  for (var i = 0; i < (seconds / frame).round(); i++) {
    g.update(frame);
  }
}

void main() {
  test(
    'Faster cruising still launches gently and respects the chosen speed',
    () {
      final g = session();
      final launch = g.speed;
      advance(g, 8);
      expect(g.speed, greaterThan(launch));
      expect(g.speed, greaterThan(.24));
      expect(g.speed, lessThanOrEqualTo(.28));
      g.fast = true;
      expect(g.speed, lessThanOrEqualTo(.37));
      expect(g.speed, greaterThan(.32));
    },
  );
  test(
    'Driving stays consistent at 30, 60 and 120 render frames per second',
    () {
      final runs = [30, 60, 120].map((fps) {
        final g = session()..target = .6;
        advance(g, 10, 1 / fps);
        return g;
      }).toList();
      for (final g in runs) {
        expect(g.time, closeTo(80, .00001));
        expect(g.distance, closeTo(runs.first.distance, .0004));
        expect(g.x, closeTo(.6, .00001));
      }
    },
  );
  test(
    'Combo expires without removing rewards and the next coin starts fresh',
    () {
      final g = session();
      for (var i = 0; i < 6; i++) {
        g.items.add(RoadItem(0, .75, ItemKind.coin));
        g.update(.016);
      }
      expect(g.combo, 6);
      expect(g.events, contains('combo'));
      expect(g.bestCombo, 6);
      advance(g, 2.5);
      expect(g.combo, 0);
      expect(g.coins, 6);
      g.items.add(RoadItem(0, .75, ItemKind.coin));
      g.update(.016);
      expect(g.combo, 1);
      expect(g.bestCombo, 6);
    },
  );
  test('Paused transformation, voices and suspension remain frozen', () {
    final g = session();
    g.transform(VehicleForm.dinosaur);
    advance(g, 1);
    final snapshot = [
      g.distance,
      g.formTime,
      g.transition,
      g.impact,
      g.voiceIn,
      g.motion,
    ];
    g.pause();
    advance(g, 5);
    expect([
      g.distance,
      g.formTime,
      g.transition,
      g.impact,
      g.voiceIn,
      g.motion,
    ], snapshot);
    g.resume();
    advance(g, 3);
    expect(g.events, contains('dino_voice'));
  });
  test('Busy effects have bounded lifetime and cannot grow without limit', () {
    final g = session();
    for (var i = 0; i < 60; i++) {
      g.shatter(0, .76);
    }
    g.update(.016);
    expect(g.sparks.length, lessThanOrEqualTo(160));
    advance(g, 1);
    expect(g.sparks, isEmpty);
  });
  test(
    'Transform warns once and restores normal driving while still protected',
    () {
      final g = session();
      g.transform(VehicleForm.plane);
      advance(g, 10.1);
      expect(g.events.where((e) => e == 'warning').length, 1);
      expect(g.events.where((e) => e == 'revert').length, 1);
      expect(g.form, VehicleForm.car);
      expect(g.shield, greaterThan(0));
      g.rows = 1;
      g.items.clear();
      g.spawn();
      expect(g.items.where((i) => isTransform(i.kind)), isNotEmpty);
    },
  );
}
