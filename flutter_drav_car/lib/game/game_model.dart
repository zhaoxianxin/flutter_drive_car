import 'dart:math';

enum PlayState { ready, countdown, driving, paused, finished }

enum ItemKind {
  coin,
  cone,
  bubble,
  magnet,
  rainbow,
  plane,
  tank,
  dinosaur,
  peppa,
}

enum VehicleForm { car, plane, tank, dinosaur, peppa }

extension VehicleFormInfo on VehicleForm {
  String get title => switch (this) {
    VehicleForm.car => '小汽车',
    VehicleForm.plane => '小飞机',
    VehicleForm.tank => '玩具坦克',
    VehicleForm.dinosaur => '小恐龙',
    VehicleForm.peppa => '小猪佩奇',
  };
  ItemKind get pickup => ItemKind.values[index + 4];
}

bool isTransform(ItemKind kind) => kind.index >= ItemKind.plane.index;

enum PowerUp { bubble, magnet, rainbow }

extension PowerUpInfo on PowerUp {
  String get title => switch (this) {
    PowerUp.bubble => '泡泡盾',
    PowerUp.magnet => '小磁铁',
    PowerUp.rainbow => '彩虹星',
  };
  String get hint => switch (this) {
    PowerUp.bubble => '保护8秒',
    PowerUp.magnet => '吸金币8秒',
    PowerUp.rainbow => '双倍金币6秒',
  };
  ItemKind get item => ItemKind.values[index + 2];
}

class RoadItem {
  RoadItem(this.x, this.y, this.kind);
  double x;
  double y;
  bool resolved = false;
  final ItemKind kind;
}

class Spark {
  Spark(this.x, this.y, this.vx, this.vy, this.color, {this.shard = false});
  final bool shard;
  double x, y, vx, vy;
  final int color;
  double life = 1;
}

class FloatingReward {
  FloatingReward(this.x, this.y, this.value);
  final double x, y;
  final int value;
  double life = 1;
}

class GameModel {
  GameModel({Random? random}) : random = random ?? Random();
  final Random random;
  PlayState state = PlayState.ready;
  PlayState _beforePause = PlayState.driving;
  double x = 0, target = 0, time = 90, distance = 0, shield = 0;
  double slow = 0, countdown = 3, spawnIn = 1.3, celebration = 0;
  int coins = 0, bumps = 0;
  int combo = 0, bestCombo = 0, dodges = 0;
  double comboTime = 0, transition = 0, impact = 0, lean = 0;
  double voiceIn = 1.4;
  final rewards = <FloatingReward>[];
  // Modest increase from 0.24/0.32, with a gentle eight-second launch ramp.
  double get cruiseSpeed => fast ? .37 : .28;
  double get speed =>
      cruiseSpeed *
      (.9 + .1 * (rideTime / 8).clamp(0, 1)) *
      (slow > 0 ? .5 : 1);
  double get motion => distance * 28;

  bool fast = false, rocking = true;
  double magnetTime = 0, rainbowTime = 0, rideTime = 0, formTime = 0;
  VehicleForm form = VehicleForm.car;
  int transformCycle = 0, smashed = 0;
  bool get transformed => form != VehicleForm.car && formTime > 0;
  void transform(VehicleForm value) {
    if (value == VehicleForm.car || transformed) return;
    form = value;
    formTime = 10;
    transition = .65;
    voiceIn = 1.2;
    slow = 0;
    // A second transformation cannot appear while the current one is active.
    items.removeWhere((item) => isTransform(item.kind));
    notice = '${form.title}变身！撞开路障吧';
    noticeTime = 3;
    events.add('transform');
    burst(x, .76, 0xffffdc77, 34);
  }

  void shatter(double px, double py) {
    for (var i = 0; i < 18; i++) {
      sparks.add(
        Spark(
          px,
          py,
          (random.nextDouble() - .5) * 1.7,
          -.25 - random.nextDouble() * .45,
          [0xffffaf64, 0xffffe6be, 0xffe38348][i % 3],
          shard: true,
        ),
      );
    }
    impact = .24;
    smashed++;
    events.add('smash');
  }

  int rows = 0, powersCollected = 0, powersUsed = 0;
  String notice = "";
  double noticeTime = 0;
  final inventory = {for (final p in PowerUp.values) p: 0};
  bool get moving => state == PlayState.driving;
  bool active(PowerUp p) => switch (p) {
    PowerUp.bubble => shield > 0,
    PowerUp.magnet => magnetTime > 0,
    PowerUp.rainbow => rainbowTime > 0,
  };
  double remaining(PowerUp p) => switch (p) {
    PowerUp.bubble => shield,
    PowerUp.magnet => magnetTime,
    PowerUp.rainbow => rainbowTime,
  };
  bool usePower(PowerUp power) {
    if (!moving || inventory[power]! <= 0 || active(power)) return false;
    inventory[power] = inventory[power]! - 1;
    switch (power) {
      case PowerUp.bubble:
        shield = 8;
        slow = 0;
      case PowerUp.magnet:
        magnetTime = 8;
      case PowerUp.rainbow:
        rainbowTime = 6;
    }
    notice = '${power.title}开启啦！';
    noticeTime = 2.5;
    powersUsed++;
    events.add('power');
    burst(x, .76, [0xff70d8fa, 0xffef97b7, 0xffffd45f][power.index], 26);
    return true;
  }

  final items = <RoadItem>[];
  final sparks = <Spark>[];
  final events = <String>[];
  int get stars => coins >= 24
      ? 3
      : coins >= 12
      ? 2
      : 1;
  void start() {
    state = PlayState.countdown;
    countdown = 3;
    events.add('start');
    // A centered gift introduces collecting before the first random rows arrive.
    items.add(RoadItem(0, .28, ItemKind.bubble));
  }

  void pause() {
    if (state == PlayState.driving || state == PlayState.countdown) {
      _beforePause = state;
      state = PlayState.paused;
    }
  }

  void resume() {
    if (state == PlayState.paused) state = _beforePause;
  }

  void steer(double value) => target = value.clamp(-1.0, 1.0);
  void burst(double px, double py, int color, [int count = 16]) {
    for (var i = 0; i < count; i++) {
      sparks.add(
        Spark(
          px,
          py,
          (random.nextDouble() - .5) * .8,
          (random.nextDouble() - .6) * .7,
          color,
        ),
      );
    }
  }

  void spawn() {
    const lanes = [-.72, 0.0, .72];
    rows++;
    final obstacle = random.nextInt(3);
    // One obstacle per row always leaves two open lanes.
    if (distance > .6 && random.nextDouble() < .72) {
      items.add(RoadItem(lanes[obstacle], -.12, ItemKind.cone));
    }
    final lane = (obstacle + 1 + random.nextInt(2)) % 3;
    final transformRow = rows % 6 == 2 && !transformed;
    final transformKind = VehicleForm.values[1 + transformCycle % 4].pickup;
    if (transformRow) transformCycle++;
    for (var i = 0; i < 3; i++) {
      final kind = i == 0 && rows % 4 == 0
          ? PowerUp.values[(rows ~/ 4) % 3].item
          : ItemKind.coin;
      items.add(
        RoadItem(
          lanes[lane],
          -.12 - i * .105,
          i == 0 && transformRow ? transformKind : kind,
        ),
      );
    }
  }

  void update(double delta) {
    // Short substeps prevent tunneling and keep timers consistent at 30/60/120 Hz.
    var remaining = delta.clamp(0.0, .15);
    while (remaining > .0000001) {
      final dt = min(remaining, 1 / 60);
      _step(dt);
      remaining -= dt;
    }
  }

  void _step(double dt) {
    if (state == PlayState.finished) {
      celebration += dt;
      _particles(dt);
      return;
    }
    if (state == PlayState.countdown) {
      countdown -= dt;
      if (countdown <= 0) {
        state = PlayState.driving;
        events.add('go');
      }
      return;
    }
    if (state != PlayState.driving) return;
    time = max(0, time - dt);
    rideTime += dt;
    transition = max(0, transition - dt);
    impact = max(0, impact - dt);
    comboTime = max(0, comboTime - dt);
    if (comboTime <= 0) combo = 0;
    lean +=
        (((target - x) * 1.4).clamp(-.18, .18) - lean) * (1 - exp(-dt * 10));
    if (transformed && formTime > 3 && formTime - dt <= 3) {
      events.add('warning');
    }
    if (transformed &&
        (form == VehicleForm.dinosaur || form == VehicleForm.peppa)) {
      voiceIn -= dt;
      if (voiceIn <= 0) {
        events.add(form == VehicleForm.dinosaur ? 'dino_voice' : 'pig_voice');
        voiceIn = 3.2;
      }
    }
    noticeTime = max(0, noticeTime - dt);
    if (formTime > 0) {
      formTime = max(0, formTime - dt);
      if (formTime <= 0) {
        form = VehicleForm.car;
        transition = .45;
        events.add('revert');
        shield = max(shield, 1.2);
        notice = '变回小汽车，继续兜风';
        noticeTime = 2;
      }
    }
    // Exponential easing is independent of frame rate, with an easy return to center.
    x += (target - x) * (1 - exp(-dt * 7));
    magnetTime = max(0, magnetTime - dt);
    rainbowTime = max(0, rainbowTime - dt);
    shield = max(0, shield - dt);
    slow = max(0, slow - dt);
    distance += speed * dt;
    spawnIn -= dt;
    if (spawnIn <= 0) {
      spawn();
      spawnIn += 1.25;
    }
    for (final item in List<RoadItem>.of(items)) {
      if (!items.contains(item)) continue;
      item.y += dt * speed;
      if (item.kind == ItemKind.coin &&
          magnetTime > 0 &&
          (item.y - .76).abs() < .24) {
        item.x += (x - item.x) * (1 - exp(-dt * 11));
      }
      if ((item.y - .76).abs() < .047 && (item.x - x).abs() < .22) {
        if (item.kind == ItemKind.coin) {
          final value = rainbowTime > 0 ? 2 : 1;
          coins += value;
          combo++;
          bestCombo = max(combo, bestCombo);
          comboTime = 2.4;
          rewards.add(FloatingReward(item.x, .7, value));
          if (combo % 6 == 0) {
            events.add('combo');
            notice = '连吃$combo枚！真棒';
            noticeTime = 1.4;
          }
          events.add('coin');
          burst(item.x, item.y, 0xffffc843);
          items.remove(item);
        } else if (isTransform(item.kind)) {
          if (!transformed) transform(VehicleForm.values[item.kind.index - 4]);
          items.remove(item);
        } else if (item.kind != ItemKind.cone) {
          final power = PowerUp.values[item.kind.index - 2];
          inventory[power] = min(3, inventory[power]! + 1);
          notice = '${power.title}收好啦，点上方按钮使用';
          noticeTime = 4;
          powersCollected++;
          events.add('pickup');
          burst(item.x, item.y, 0xff91e4fa, 22);
          items.remove(item);
        } else if (transformed) {
          shatter(item.x, item.y);
          items.remove(item);
        } else if (shield > 0) {
          burst(item.x, item.y, 0xffb5f1ff);
          events.add('guard');
          items.remove(item);
        } else {
          bumps++;
          shield = 2.4;
          slow = .65;
          impact = .4;
          events.add('bump');
          burst(x, .76, 0xffffffff);
          items.remove(item);
        }
      }
    }
    for (final item in items) {
      if (item.kind == ItemKind.cone && item.y > .83 && !item.resolved) {
        item.resolved = true;
        final gap = (item.x - x).abs();
        if (gap > .25 && gap < .55 && !transformed && shield <= 0) {
          dodges++;
          events.add('near');
          notice = '躲得真棒！';
          noticeTime = 1.2;
        }
      }
    }
    items.removeWhere((item) => item.y > 1.2);
    _particles(dt);
    if (time <= 0) {
      state = PlayState.finished;
      events.add('finish');
      for (var i = 0; i < 6; i++) {
        burst(
          random.nextDouble() * 2 - 1,
          random.nextDouble() * .7,
          [0xffffb851, 0xff55bba7, 0xfff18c9b][i % 3],
          14,
        );
      }
    }
  }

  void _particles(double dt) {
    for (final reward in rewards) {
      reward.life -= dt * 1.6;
    }
    rewards.removeWhere((reward) => reward.life <= 0);
    if (rewards.length > 12) rewards.removeRange(0, rewards.length - 12);
    // Bursts are bounded even when a tank clears many obstacles at once.
    if (sparks.length > 160) sparks.removeRange(0, sparks.length - 160);
    for (final p in sparks) {
      p.life -= dt * 1.5;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += dt * .25;
    }
    sparks.removeWhere((p) => p.life <= 0);
  }
}

class TiltController {
  double neutral = 0, filtered = 0, lastAngle = 0;
  bool hasReading = false;
  void calibrate() {
    neutral = lastAngle;
    filtered = 0;
  }

  double sample(double ax, double ay, double az) {
    // Ignore a flat phone: the roll angle becomes indeterminate.
    if (sqrt(ax * ax + ay * ay) < 2) return filtered;
    lastAngle = atan2(-ax, ay);
    if (!hasReading) {
      hasReading = true;
      neutral = lastAngle;
    }
    var angle = lastAngle - neutral;
    while (angle > pi) {
      angle -= 2 * pi;
    }
    while (angle < -pi) {
      angle += 2 * pi;
    }
    final value = angle.abs() < .035 ? 0.0 : (angle / .44).clamp(-1.0, 1.0);
    filtered += (value - filtered) * .18;
    return filtered;
  }
}
