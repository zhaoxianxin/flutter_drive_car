import 'dart:math';

import 'package:flutter/material.dart';

import 'game_model.dart';

class WorldTheme {
  const WorldTheme(
    this.name,
    this.caption,
    this.icon,
    this.ground,
    this.dark,
    this.accent,
  );
  final String name, caption;
  final IconData icon;
  final Color ground, dark, accent;
  static const all = [
    WorldTheme(
      '青草乐园',
      '和小树一起兜风',
      Icons.park_rounded,
      Color(0xffaede8c),
      Color(0xff69ac69),
      Color(0xff358f73),
    ),
    WorldTheme(
      '海边假日',
      '听海风轻轻唱歌',
      Icons.waves_rounded,
      Color(0xfff2d8a0),
      Color(0xff75c8c9),
      Color(0xff318fba),
    ),
    WorldTheme(
      '糖果小镇',
      '开进甜甜的梦里',
      Icons.icecream_rounded,
      Color(0xfff2c9dd),
      Color(0xffc88fc5),
      Color(0xffa46faf),
    ),
  ];
}

/// All scenery, collectibles, effects and the car use this same ground projection.
/// Model y=.76 is the car's axle/contact plane, regardless of screen dimensions.
class RoadProjection {
  RoadProjection(
    this.size,
    this.distance,
    this.steering, {
    this.preview = false,
  });
  final Size size;
  final double distance, steering;
  final bool preview;
  double get horizon => preview ? .19 : .265;
  double center(double depth) =>
      size.width *
      (.5 +
          sin(distance * .7) * .045 * pow(1 - depth.clamp(0, 1), 2) -
          steering * .025 * (1 - depth.clamp(0, 1)));
  double scale(double depth) => .12 + .88 * pow(depth.clamp(0, 1.4), 1.15);
  double halfWidth(double depth) =>
      size.width * (.035 + .51 * pow(depth.clamp(0, 1.4), 1.15));
  Offset project(double x, double depth) => Offset(
    center(depth) + x * halfWidth(depth) * .76,
    size.height * (horizon + pow(depth.clamp(0, 1.4), 1.65) * (1.02 - horizon)),
  );
  Offset edge(double side, double depth) =>
      Offset(center(depth) + side * halfWidth(depth), project(0, depth).dy);
}

class RoadPainter extends CustomPainter {
  RoadPainter({required this.game, required this.world, this.preview = false});
  final GameModel game;
  final WorldTheme world;
  final bool preview;
  late Canvas c;
  late Size s;
  late RoadProjection road;
  final brush = Paint()..isAntiAlias = true;
  void box(Rect r, Color color, [double radius = 0]) {
    brush
      ..shader = null
      ..color = color
      ..style = PaintingStyle.fill;
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), brush);
  }

  void oval(Offset p, double rx, double ry, Color color) {
    brush
      ..shader = null
      ..color = color
      ..style = PaintingStyle.fill;
    c.drawOval(
      Rect.fromCenter(center: p, width: rx * 2, height: ry * 2),
      brush,
    );
  }

  void line(Offset a, Offset b, Color color, double width) {
    brush
      ..shader = null
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawLine(a, b, brush);
    brush.style = PaintingStyle.fill;
  }

  void poly(List<Offset> points, Color color) {
    final path = Path()..addPolygon(points, true);
    brush
      ..shader = null
      ..color = color
      ..style = PaintingStyle.fill;
    c.drawPath(path, brush);
  }

  void gradientBox(Rect r, List<Color> colors, double radius) {
    brush
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(r);
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), brush);
    brush.shader = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    s = size;
    road = RoadProjection(size, game.distance, game.x, preview: preview);
    c.save();
    c.clipRect(Offset.zero & size);
    final w = s.width, h = s.height, hy = road.horizon * h;
    gradientBox(Offset.zero & s, [
      const Color(0xff87d9ed),
      const Color(0xffdef6e6),
      world.ground,
    ], 0);
    oval(
      Offset(w * .81, hy * .48),
      w * .065,
      w * .065,
      const Color(0x30fff1a9),
    );
    oval(
      Offset(w * .81, hy * .48),
      w * .045,
      w * .045,
      const Color(0xffffeaa0),
    );
    for (var i = 0; i < 4; i++) {
      final x = w * (.05 + i * .29) - game.x * w * .008;
      final y = hy * (.44 + (i % 2) * .19);
      cloud(x, y, w * (.042 + i * .004));
    }
    // Two rounded hill layers create a stable distant horizon, with gentle parallax.
    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(0, hy + 35);
      for (var i = 0; i <= 4; i++) {
        final x = w * i / 4 - game.x * w * .01 * (layer + 1);
        path.quadraticBezierTo(
          x - w * .12,
          hy - h * (layer == 0 ? .065 : .035),
          x + w * .13,
          hy + 12,
        );
      }
      path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      brush
        ..shader = null
        ..color = layer == 0 ? world.dark.withValues(alpha: .5) : world.ground;
      c.drawPath(path, brush);
    }
    if (world == WorldTheme.all[1]) {
      gradientBox(Rect.fromLTRB(0, hy + h * .025, w, h), [
        const Color(0xff6bcbd6),
        const Color(0xffa1e5e3),
      ], 0);
      for (var i = 0; i < 8; i++) {
        final yy = hy + h * (.04 + i * .08);
        line(Offset(0, yy), Offset(w, yy), const Color(0x55edffff), 2 + i * .3);
      }
    }
    // A single continuous surface avoids seams between perspective bands.
    Path corridor(double width) => Path()..addPolygon([
      for (var i = 0; i <= 60; i++) road.edge(-width, i / 60),
      for (var i = 60; i >= 0; i--) road.edge(width, i / 60),
    ], true);
    brush..shader = null..color = world.ground;
    c.drawPath(corridor(1.2), brush);
    brush.color = const Color(0xfff8f0d7);
    c.drawPath(corridor(1.045), brush);
    brush..color = Colors.white..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xffa3b9b4), Color(0xff688f8c)],
    ).createShader(Rect.fromLTRB(0, hy, w, h));
    c.drawPath(corridor(1), brush); brush.shader = null;
    for (var i = 0; i < 18; i++) {
      final t = ((i / 18 + game.distance * .72) % 1.0);
      final end = (t + .026).clamp(0.0, 1.0);
      for (final x in [-.36, .36]) {
        final a = road.project(x, t), b = road.project(x, end);
        line(a, b, const Color(0xfff2f3d8), max(1, w * .011 * road.scale(t)));
      }
      for (final side in [-1.02, 1.02]) {
        line(
          road.edge(side, t),
          road.edge(side, end),
          i.isEven ? world.accent : const Color(0xffffc66f),
          max(1, w * .018 * road.scale(t)),
        );
      }
    }
    final scenery = <double>[
      for (var i = 0; i < 14; i++) (i / 14 + game.distance * .55) % 1,
    ];
    scenery.sort();
    for (var i = 0; i < scenery.length; i++) {
      final t = scenery[i], scale = road.scale(t);
      for (final side in [-1.0, 1.0]) {
        final p = road.edge(side * (1.35 + (i % 3) * .13), t);
        if (world == WorldTheme.all[2]) {
          candy(p, w * .07 * scale, i);
        } else if (world == WorldTheme.all[1] && i % 3 != 0) {
          beachUmbrella(p, w * .075 * scale, i);
        } else {
          tree(p.dx, p.dy, w * .075 * scale);
        }
      }
    }
    final objects = List<RoadItem>.of(game.items)
      ..sort((a, b) => a.y.compareTo(b.y));
    if (preview) {
      objects.addAll([
        RoadItem(0, .38, ItemKind.coin),
        RoadItem(0, .53, ItemKind.coin),
        RoadItem(.72, .45, ItemKind.magnet),
        RoadItem(-.72, .62, ItemKind.cone),
      ]);
    }
    // Split at the axle so objects close to the camera correctly occlude the rear bumper.
    for (final item in objects.where((a) => a.y <= .76)) {
      drawItem(item);
    }
    final p = road.project(game.x, .76);
    final carWidth = w * (preview ? .22 : .245);
    final bob = game.moving && game.rocking
        ? sin(game.rideTime * 3.8) * h * .0025
        : 0.0;
    if (game.rainbowTime > 0) {
      for (var i = 0; i < 5; i++) {
        line(
          p.translate((i - 2) * carWidth * .16, carWidth * .1),
          p.translate((i - 2) * carWidth * .23, carWidth * .65),
          [
            const Color(0x99ff9eae),
            const Color(0x99ffd66f),
            const Color(0x9992e4bb),
            const Color(0x997accdf),
            const Color(0x99b8a3e1),
          ][i],
          carWidth * .15,
        );
      }
    }
    oval(
      p.translate(0, carWidth * .07),
      carWidth * .58,
      carWidth * .19,
      const Color(0x35634e3f),
    );
    c.save();
    c.translate(p.dx, p.dy + bob);
    c.rotate(
      (game.target - game.x) * .06 +
          (game.moving && game.rocking ? sin(game.rideTime * 2.3) * .012 : 0),
    );
    if (game.transformed) {
      drawForm(
        game.form,
        Offset(
          0,
          game.form == VehicleForm.plane
              ? -carWidth * .2 + sin(game.rideTime * 4) * 3
              : 0,
        ),
        carWidth,
      );
    } else {
      car(Offset.zero, carWidth);
    }
    c.restore();
    if (game.shield > 0) {
      final bubble = Rect.fromCenter(
        center: p.translate(0, -carWidth * .36),
        width: carWidth * 1.45,
        height: carWidth * 1.58,
      );
      brush
        ..shader = RadialGradient(
          colors: const [
            Color(0x0576ddff),
            Color(0x4576ddff),
            Color(0x99ddffff),
          ],
        ).createShader(bubble)
        ..color = Colors.white;
      c.drawOval(bubble, brush);
      brush.shader = null;
      brush
        ..color = const Color(0xffe3ffff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      c.drawArc(bubble.deflate(4), 3.7, 1.2, false, brush);
      brush.style = PaintingStyle.fill;
    }
    if (game.magnetTime > 0) {
      for (var i = 0; i < 3; i++) {
        final pulse = (game.rideTime * .7 + i / 3) % 1;
        brush
          ..color = const Color(0xffed8da9).withValues(alpha: (1 - pulse) * .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        c.drawOval(
          Rect.fromCenter(
            center: p,
            width: carWidth * (1.2 + pulse * 2.8),
            height: carWidth * (.5 + pulse * .9),
          ),
          brush,
        );
      }
      brush.style = PaintingStyle.fill;
    }
    for (final item in objects.where((a) => a.y > .76)) {
      drawItem(item);
    }
    for (final particle in game.sparks) {
      final point = road.project(particle.x, particle.y);
      final color = Color(particle.color)
          .withValues(alpha: particle.life.clamp(0, 1));
      if (particle.shard) {
        c.save();
        c.translate(point.dx, point.dy);
        c.rotate(particle.vx * game.rideTime * 6);
        final r = (4 + particle.life * 5) * road.scale(particle.y);
        poly([
          Offset(-r, -r * .5),
          Offset(r * .8, -r),
          Offset(r, r * .5),
          Offset(-r * .5, r),
        ], color);
        c.restore();
      } else {
        oval(point, 3.2 * particle.life, 4.8 * particle.life, color);
      }
    }
    if (!preview) dashboard();
    c.restore();
  }

  void drawItem(RoadItem item) {
    if (item.y < 0 || item.y > 1.17) return;
    final p = road.project(item.x, item.y), scale = road.scale(item.y);
    if (item.kind == ItemKind.coin) {
      coin(
        p.translate(0, -s.width * .027 * scale),
        s.width * .036 * scale,
        game.rideTime * 3,
      );
    } else if (item.kind == ItemKind.cone) {
      cone(p, s.width * .105 * scale);
    } else {
      power(p, s.width * .12 * scale, item.kind);
    }
  }

  void cloud(double x, double y, double r) {
    oval(Offset(x, y), r * 1.9, r * .53, const Color(0xeeffffff));
    oval(
      Offset(x - r * .7, y - r * .25),
      r * .7,
      r * .7,
      const Color(0xeeffffff),
    );
    oval(Offset(x + r * .3, y - r * .4), r, r * .8, const Color(0xeeffffff));
  }

  void tree(double x, double y, double r) {
    oval(Offset(x + 4, y + 3), r * .95, r * .26, const Color(0x24604f32));
    gradientBox(
      Rect.fromLTWH(x - r * .12, y - r * 1.1, r * .24, r * 1.2),
      const [Color(0xffc39458), Color(0xff8e6545)],
      r * .1,
    );
    oval(Offset(x, y - r * 1.65), r * .83, r, world.accent);
    oval(Offset(x - r * .22, y - r * 1.95), r * .72, r * .82, world.dark);
    oval(
      Offset(x - r * .4, y - r * 2.1),
      r * .33,
      r * .39,
      const Color(0x55f1ffd3),
    );
  }

  void candy(Offset p, double r, int i) {
    oval(p, r * .8, r * .23, const Color(0x227e556c));
    line(p, p.translate(0, -r * 1.5), const Color(0xfffff8de), max(1, r * .15));
    oval(
      p.translate(0, -r * 1.7),
      r * .8,
      r * .85,
      i.isEven ? const Color(0xfff69db3) : const Color(0xff9fcde8),
    );
    brush
      ..color = const Color(0xfffff0d4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, r * .13);
    c.drawArc(
      Rect.fromCircle(center: p.translate(0, -r * 1.7), radius: r * .48),
      0,
      pi * 1.6,
      false,
      brush,
    );
    brush.style = PaintingStyle.fill;
  }

  void beachUmbrella(Offset p, double r, int i) {
    oval(p, r, r * .24, const Color(0x247e7854));
    line(p, p.translate(0, -r * 1.5), const Color(0xffb58c5a), max(1, r * .1));
    final path = Path()
      ..moveTo(p.dx - r, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy - r * 2.7, p.dx + r, p.dy - r)
      ..close();
    brush
      ..shader = null
      ..color = i.isEven ? const Color(0xfff3b16e) : const Color(0xfffff0c8);
    c.drawPath(path, brush);
    poly([
      p.translate(-r * .27, -r),
      p.translate(0, -r * 1.85),
      p.translate(r * .27, -r),
    ], const Color(0xffec8f7e));
  }

  void coin(Offset p, double r, double phase) {
    oval(p.translate(0, r * 1.3), r * .9, r * .25, const Color(0x207a643e));
    final rx = r * (.72 + .28 * cos(phase).abs());
    oval(p.translate(2, 2), rx, r, const Color(0xffc68d24));
    oval(p, rx, r, const Color(0xffffcf54));
    brush
      ..color = const Color(0xffffefa1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, r * .12);
    c.drawOval(
      Rect.fromCenter(center: p, width: rx * 1.45, height: r * 1.5),
      brush,
    );
    brush.style = PaintingStyle.fill;
    line(
      p.translate(0, -r * .4),
      p.translate(0, r * .35),
      const Color(0xffdf9d25),
      max(1, r * .15),
    );
    oval(p.translate(-rx * .45, -r * .45), r * .12, r * .2, Colors.white);
  }

  void cone(Offset p, double width) {
    oval(p.translate(0, 3), width * .65, width * .2, const Color(0x30664d32));
    gradientBox(
      Rect.fromCenter(center: p, width: width * 1.2, height: width * .28),
      const [Color(0xffffc278), Color(0xffd67d44)],
      width * .09,
    );
    final path = Path()
      ..moveTo(p.dx - width * .45, p.dy - width * .06)
      ..lineTo(p.dx - width * .13, p.dy - width * 1.04)
      ..quadraticBezierTo(
        p.dx,
        p.dy - width * 1.18,
        p.dx + width * .13,
        p.dy - width * 1.04,
      )
      ..lineTo(p.dx + width * .45, p.dy - width * .06)
      ..close();
    brush
      ..color = Colors.white
      ..shader =
          const LinearGradient(
            colors: [Color(0xffffce80), Color(0xfff79750), Color(0xffdf7c3d)],
          ).createShader(
            Rect.fromCenter(center: p, width: width, height: width * 2),
          );
    c.drawPath(path, brush);
    brush.shader = null;
    line(
      p.translate(-width * .23, -width * .64),
      p.translate(width * .23, -width * .64),
      const Color(0xfffff3d7),
      width * .17,
    );
  }

  void power(Offset p, double width, ItemKind kind) {
    final color = switch (kind) {
      ItemKind.bubble => const Color(0xff7fdcf5),
      ItemKind.magnet => const Color(0xfff195b1),
      ItemKind.plane => const Color(0xff83cbea),
      ItemKind.tank => const Color(0xff9ed18e),
      ItemKind.dinosaur => const Color(0xff91d7b2),
      ItemKind.peppa => const Color(0xfff4a7c8),
      _ => const Color(0xffffd45f),
    };
    final bob = sin(game.rideTime * 3 + kind.index) * width * .06;
    oval(p, width * .6, width * .16, const Color(0x286d5970));
    final rect = Rect.fromCenter(
      center: p.translate(0, -width * .65 + bob),
      width: width,
      height: width,
    );
    gradientBox(rect.shift(const Offset(0, 4)), [
      color,
      Color.lerp(color, Colors.black, .18)!,
    ], width * .25);
    gradientBox(rect, [
      Color.lerp(color, Colors.white, .55)!,
      color,
    ], width * .25);
    line(
      rect.topLeft + Offset(width * .2, width * .13),
      rect.topRight + Offset(-width * .27, width * .13),
      const Color(0xcaffffff),
      max(1, width * .05),
    );
    if (isTransform(kind)) {
      drawForm(
        VehicleForm.values[kind.index - 4],
        rect.center.translate(0, width * .31),
        width * .52,
      );
      return;
    }
    if (kind == ItemKind.magnet) {
      final center = rect.center.translate(0, -width * .1);
      brush
        ..color = const Color(0xffc85177)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .16;
      c.drawArc(
        Rect.fromCenter(center: center, width: width * .48, height: width * .5),
        0,
        pi,
        false,
        brush,
      );
      brush.style = PaintingStyle.fill;
      box(
        Rect.fromLTWH(
          center.dx - width * .32,
          center.dy - width * .16,
          width * .16,
          width * .2,
        ),
        Colors.white,
        width * .03,
      );
      box(
        Rect.fromLTWH(
          center.dx + width * .16,
          center.dy - width * .16,
          width * .16,
          width * .2,
        ),
        Colors.white,
        width * .03,
      );
      return;
    }
    final icon = switch (kind) {
      ItemKind.bubble => Icons.shield_rounded,
      ItemKind.magnet => Icons.attractions_rounded,
      _ => Icons.star_rounded,
    };
    final text = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: width * .64,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(c, rect.center - Offset(text.width / 2, text.height / 2));
  }

  void car(Offset p, double width) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(width / 100);
    // Glossy ride-on toy car seen from behind: wheels, chassis, raised cabin and bumper.
    for (final x in [-50.0, 31.0]) {
      gradientBox(Rect.fromLTWH(x, -53, 19, 55), const [
        Color(0xff42666e),
        Color(0xff243d50),
      ], 7);
      line(Offset(x + 4, -43), Offset(x + 4, -9), const Color(0xff69818a), 3);
    }
    gradientBox(const Rect.fromLTWH(-47, -59, 94, 65), const [
      Color(0xffeb8d46),
      Color(0xffbb5c38),
    ], 20);
    gradientBox(const Rect.fromLTWH(-45, -79, 90, 72), const [
      Color(0xffffd08b),
      Color(0xffff9c5b),
      Color(0xffe87d43),
    ], 22);
    gradientBox(const Rect.fromLTWH(-36, -102, 72, 66), const [
      Color(0xffffdb9a),
      Color(0xffffad68),
    ], 22);
    gradientBox(const Rect.fromLTWH(-29, -94, 58, 42), const [
      Color(0xff416f80),
      Color(0xff7ec0c6),
    ], 14);
    // Rounded seat/headrests reinforce the plastic kiddie-ride silhouette.
    box(const Rect.fromLTWH(-22, -72, 17, 22), const Color(0xfffed37a), 7);
    box(const Rect.fromLTWH(5, -72, 17, 22), const Color(0xfffed37a), 7);
    line(
      const Offset(-20, -88),
      const Offset(-5, -88),
      const Color(0xffd7f7f5),
      4,
    );
    gradientBox(const Rect.fromLTWH(-40, -44, 80, 42), const [
      Color(0xffffc981),
      Color(0xfff6a05a),
    ], 14);
    line(
      const Offset(-28, -35),
      const Offset(24, -35),
      const Color(0xffffdfa2),
      3,
    );
    gradientBox(const Rect.fromLTWH(-43, -14, 86, 18), const [
      Color(0xffffe2ac),
      Color(0xffe4a46b),
    ], 8);
    box(const Rect.fromLTWH(-35, -27, 17, 9), const Color(0xffef7271), 4);
    box(const Rect.fromLTWH(18, -27, 17, 9), const Color(0xffef7271), 4);
    box(const Rect.fromLTWH(-12, -28, 24, 12), const Color(0xfffff7db), 4);
    oval(const Offset(0, -22), 3.5, 3.5, const Color(0xff70b9a2));
    oval(const Offset(-39, -58), 4, 7, const Color(0x77ffffff));
    c.restore();
  }

  void drawForm(VehicleForm form, Offset p, double width) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(width / 100);
    switch (form) {
      case VehicleForm.car:
        car(Offset.zero, 100);
      case VehicleForm.plane:
        plane();
      case VehicleForm.tank:
        tank();
      case VehicleForm.dinosaur:
        dinosaur();
      case VehicleForm.peppa:
        peppa();
    }
    c.restore();
  }

  void plane() {
    oval(const Offset(0, 4), 48, 13, const Color(0x255f6578));
    // Raised wings cast a second shadow onto the shiny toy fuselage.
    poly(const [
      Offset(-9, -76),
      Offset(-78, -25),
      Offset(-75, -10),
      Offset(-8, -39),
      Offset(8, -39),
      Offset(75, -10),
      Offset(78, -25),
      Offset(9, -76),
    ], const Color(0xff3b83af));
    poly(const [
      Offset(-9, -80),
      Offset(-78, -30),
      Offset(-75, -16),
      Offset(-8, -44),
      Offset(8, -44),
      Offset(75, -16),
      Offset(78, -30),
      Offset(9, -80),
    ], const Color(0xff8dd9ec));
    line(
      const Offset(-64, -30),
      const Offset(-44, -41),
      const Color(0xffffdc79),
      7,
    );
    line(
      const Offset(64, -30),
      const Offset(44, -41),
      const Color(0xffffdc79),
      7,
    );
    gradientBox(const Rect.fromLTWH(-17, -109, 34, 116), const [
      Color(0xffffedb9),
      Color(0xffffbd62),
      Color(0xffeb944f),
    ], 18);
    gradientBox(const Rect.fromLTWH(-12, -84, 24, 39), const [
      Color(0xff285e85),
      Color(0xff93d9e7),
    ], 10);
    line(
      const Offset(-6, -76),
      const Offset(-2, -65),
      const Color(0xffe1ffff),
      3,
    );
    poly(const [
      Offset(-7, -15),
      Offset(-37, 9),
      Offset(-34, 19),
      Offset(0, 6),
      Offset(34, 19),
      Offset(37, 9),
      Offset(7, -15),
    ], const Color(0xff58b8d8));
    gradientBox(const Rect.fromLTWH(-5, -13, 10, 30), const [
      Color(0xff8ad7ec),
      Color(0xff387ca7),
    ], 5);
    oval(const Offset(-77, -22), 3, 4, const Color(0xffffa7a0));
    oval(const Offset(77, -22), 3, 4, const Color(0xffa1e1b9));
  }

  void tank() {
    for (final x in [-53.0, 31.0]) {
      gradientBox(Rect.fromLTWH(x, -78, 22, 89), const [
        Color(0xff3f5a59),
        Color(0xff254249),
      ], 10);
      for (var i = 0; i < 7; i++) {
        final y = -68 + ((i * 12 + game.distance * 90) % 78);
        line(Offset(x + 4, y), Offset(x + 18, y), const Color(0xff718581), 4);
      }
    }
    gradientBox(const Rect.fromLTWH(-43, -88, 86, 90), const [
      Color(0xffbce59f),
      Color(0xff78b58b),
      Color(0xff4d8e72),
    ], 18);
    poly(const [
      Offset(-35, -79),
      Offset(35, -79),
      Offset(28, -96),
      Offset(-28, -96),
    ], const Color(0xffd0edae));
    gradientBox(const Rect.fromLTWH(-27, -76, 54, 53), const [
      Color(0xffd2ecac),
      Color(0xff78ad7c),
    ], 18);
    gradientBox(const Rect.fromLTWH(-7, -122, 14, 61), const [
      Color(0xffa4cb8f),
      Color(0xff56876b),
    ], 6);
    box(const Rect.fromLTWH(-9, -126, 18, 12), const Color(0xff5f9274), 4);
    oval(const Offset(5, -50), 12, 9, const Color(0xffbfe1a8));
    line(
      const Offset(-27, -13),
      const Offset(27, -13),
      const Color(0xffe0edb2),
      5,
    );
    box(const Rect.fromLTWH(-34, -7, 13, 6), const Color(0xffffbd84), 3);
    box(const Rect.fromLTWH(21, -7, 13, 6), const Color(0xffffbd84), 3);
  }

  void dinosaur() {
    // A round, smiling ride-on dinosaur with a chunky tail and tiny arms.
    final tail = Path()
      ..moveTo(-24, -44)
      ..quadraticBezierTo(-73, -44, -77, -13)
      ..quadraticBezierTo(-44, -29, -15, -19)
      ..close();
    brush
      ..color = const Color(0xff60ad8a)
      ..shader = null;
    c.drawPath(tail, brush);
    for (var i = 0; i < 4; i++) {
      poly([
        Offset(-48 + i * 15.0, -42 - i * 11.0),
        Offset(-40 + i * 15.0, -62 - i * 11.0),
        Offset(-32 + i * 15.0, -44 - i * 11.0),
      ], const Color(0xffffc576));
    }
    gradientBox(const Rect.fromLTWH(-35, -72, 70, 70), const [
      Color(0xffa5e1a7),
      Color(0xff5cb691),
      Color(0xff3f9c82),
    ], 30);
    oval(const Offset(3, -31), 23, 24, const Color(0xffd6edb5));
    gradientBox(const Rect.fromLTWH(-1, -111, 57, 57), const [
      Color(0xffbce7a7),
      Color(0xff67bd91),
    ], 22);
    oval(const Offset(41, -77), 29, 19, const Color(0xff97d9a0));
    oval(const Offset(23, -94), 8, 10, Colors.white);
    oval(const Offset(26, -93), 3.5, 5, const Color(0xff315e5c));
    oval(const Offset(56, -81), 2.4, 2.4, const Color(0xff4b987c));
    brush
      ..color = const Color(0xff3e8d73)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    c.drawArc(const Rect.fromLTWH(37, -80, 23, 16), .3, 1.8, false, brush);
    brush.style = PaintingStyle.fill;
    gradientBox(const Rect.fromLTWH(-32, -12, 27, 23), const [
      Color(0xff91d69f),
      Color(0xff4a9b7d),
    ], 9);
    gradientBox(const Rect.fromLTWH(13, -10, 28, 23), const [
      Color(0xff91d69f),
      Color(0xff4a9b7d),
    ], 9);
    oval(const Offset(-29, -46), 10, 18, const Color(0xff78c998));
    oval(const Offset(33, -40), 8, 15, const Color(0xff78c998));
  }

  void peppa() {
    // Original Canvas drawing of the requested pink pig character and red dress.
    line(
      const Offset(-19, -3),
      const Offset(-22, 13),
      const Color(0xffefa5c2),
      7,
    );
    line(
      const Offset(14, -3),
      const Offset(17, 13),
      const Color(0xffefa5c2),
      7,
    );
    box(const Rect.fromLTWH(-34, 9, 24, 12), const Color(0xffffd16b), 5);
    box(const Rect.fromLTWH(8, 9, 24, 12), const Color(0xffffd16b), 5);
    final dress = Path()
      ..moveTo(-16, -60)
      ..quadraticBezierTo(-37, -36, -40, -2)
      ..quadraticBezierTo(0, 10, 40, -2)
      ..quadraticBezierTo(32, -40, 12, -60)
      ..close();
    brush
      ..color = Colors.white
      ..shader = const LinearGradient(
        colors: [Color(0xfff8898e), Color(0xffe45268)],
      ).createShader(const Rect.fromLTWH(-40, -60, 80, 65));
    c.drawPath(dress, brush);
    brush.shader = null;
    line(
      const Offset(-27, -41),
      const Offset(-49, -29),
      const Color(0xfff5b0ca),
      6,
    );
    line(
      const Offset(28, -40),
      const Offset(51, -53),
      const Color(0xfff5b0ca),
      6,
    );
    for (var i = 0; i < 3; i++) {
      line(
        Offset(49, -52),
        Offset(57 + i * 2.0, -58 + i * 5.0),
        const Color(0xfff5b0ca),
        3,
      );
    }
    oval(const Offset(-12, -110), 7, 18, const Color(0xffef98ba));
    oval(const Offset(9, -113), 7, 17, const Color(0xfff8bad3));
    oval(const Offset(0, -80), 34, 32, const Color(0xfff7b3cf));
    oval(const Offset(27, -91), 27, 19, const Color(0xfff7b3cf));
    oval(const Offset(45, -93), 13, 16, const Color(0xfff0a0c2));
    oval(const Offset(43, -97), 2.2, 3, const Color(0xffd4779f));
    oval(const Offset(50, -93), 2.2, 3, const Color(0xffd4779f));
    oval(const Offset(4, -99), 6, 7, Colors.white);
    oval(const Offset(20, -102), 6, 7, Colors.white);
    oval(const Offset(6, -99), 2.4, 3, const Color(0xff4c5262));
    oval(const Offset(22, -102), 2.4, 3, const Color(0xff4c5262));
    oval(const Offset(-17, -79), 9, 8, const Color(0xffee90b6));
    brush
      ..color = const Color(0xffd279a0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    c.drawArc(const Rect.fromLTWH(-8, -86, 27, 23), .2, 2.5, false, brush);
    brush.style = PaintingStyle.fill;
    brush
      ..color = const Color(0xffeda3c1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawArc(const Rect.fromLTWH(-49, -22, 17, 15), 1, 5, false, brush);
    brush.style = PaintingStyle.fill;
  }

  void dashboard() {
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(0, h * .855)
      ..quadraticBezierTo(w * .5, h * .765, w, h * .855)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    brush
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff6eaaa3), Color(0xff326c6b), Color(0xff244f5c)],
      ).createShader(Rect.fromLTWH(0, h * .8, w, h * .2))
      ..color = Colors.white;
    c.drawPath(path, brush);
    brush.shader = null;
    final rim = Path()
      ..moveTo(0, h * .855)
      ..quadraticBezierTo(w * .5, h * .765, w, h * .855);
    brush
      ..color = const Color(0xffb5e0cb)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    c.drawPath(rim, brush);
    brush.style = PaintingStyle.fill;
    // Two inset toy gauges; the center is reserved for the interactive wheel.
    for (final x in [.12, .88]) {
      oval(Offset(w * x, h * .91), w * .077, w * .077, const Color(0xff214e59));
      oval(
        Offset(w * x, h * .905),
        w * .067,
        w * .067,
        const Color(0xffffedbd),
      );
      for (var i = 0; i < 5; i++) {
        final a = pi + i * pi / 4;
        line(
          Offset(w * x + cos(a) * w * .047, h * .905 + sin(a) * w * .047),
          Offset(w * x + cos(a) * w * .054, h * .905 + sin(a) * w * .054),
          const Color(0xff72a49d),
          2,
        );
      }
      final a = pi * 1.25 + sin(game.rideTime * 2) * .16;
      line(
        Offset(w * x, h * .905),
        Offset(w * x + cos(a) * w * .04, h * .905 + sin(a) * w * .04),
        const Color(0xffee9b68),
        3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) => true;
}

class WheelPainter extends CustomPainter {
  WheelPainter(this.angle, {this.color = const Color(0xff38685e)});
  final double angle;
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.translate(s.width / 2, s.height / 2);
    c.rotate(angle);
    final r = s.width * .38;
    var p = Paint()
      ..isAntiAlias = true
      ..color = const Color(0x33234349)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * .12;
    c.drawCircle(const Offset(0, 3), r, p);
    p
      ..shader = LinearGradient(
        colors: [
          Color.lerp(color, Colors.white, .23)!,
          color,
          const Color(0xff244c55),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r))
      ..strokeWidth = s.width * .105;
    c.drawCircle(Offset.zero, r, p);
    p.shader = null;
    p
      ..color = color
      ..strokeWidth = s.width * .08
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(-r * .85, -r * .3), Offset.zero, p);
    c.drawLine(Offset(r * .85, -r * .3), Offset.zero, p);
    c.drawLine(Offset(0, r), Offset.zero, p);
    p
      ..style = PaintingStyle.fill
      ..color = const Color(0xffffd58a);
    c.drawCircle(Offset.zero, s.width * .145, p);
    p.color = const Color(0xffe3a852);
    c.drawCircle(const Offset(0, 2), s.width * .075, p);
    p.color = const Color(0xffffe9ae);
    c.drawCircle(Offset.zero, s.width * .07, p);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) =>
      angle != oldDelegate.angle || color != oldDelegate.color;
}
