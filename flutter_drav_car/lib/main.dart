import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game/game_model.dart';
import 'game/platform_bridge.dart';
import 'game/road_painter.dart';

const ink = Color(0xff294e47);
const cream = Color(0xfffaf7ee);
const orange = Color(0xffed9567);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: cream,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LittleDriverApp());
}

class LittleDriverApp extends StatelessWidget {
  const LittleDriverApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '小小司机',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: cream),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink),
        titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w800),
      ),
    ),
    home: const DriverHome(),
  );
}

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});
  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  GameModel game = GameModel();
  final tilt = TiltController();
  late final Ticker ticker;
  StreamSubscription<dynamic>? sensor;
  Duration? previous;
  bool inGame = false,
      music = true,
      effects = true,
      fast = false,
      sensorFailed = false;
  int scene = 0, best = 0, musicTrack = 0;
  bool gentleRock = true;
  static const songNames = ['小星星', '两只老虎', '欢乐兜风'];
  bool savedResult = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker(tick)..start();
    load();
  }

  Future<void> load() async {
    final values = await GamePlatform.call<Map<dynamic, dynamic>>('load');
    if (!mounted || values == null) return;
    setState(() {
      music = values['music'] as bool? ?? true;
      effects = values['effects'] as bool? ?? true;
      fast = values['fast'] as bool? ?? false;
      scene = (values['scene'] as int? ?? 0).clamp(0, 2);
      best = values['best'] as int? ?? 0;
      musicTrack = (values['musicTrack'] as int? ?? 0).clamp(0, 2);
      gentleRock = values['gentleRock'] as bool? ?? true;
      game.rocking = gentleRock;
    });
  }

  void save() {
    unawaited(
      GamePlatform.call('save', {
        'music': music,
        'effects': effects,
        'fast': fast,
        'scene': scene,
        'best': best,
        'musicTrack': musicTrack,
        'gentleRock': gentleRock,
      }),
    );
  }

  void tick(Duration elapsed) {
    final dt = previous == null
        ? 0.0
        : (elapsed - previous!).inMicroseconds / 1000000;
    previous = elapsed;
    if (!inGame) return;
    game.update(dt);
    for (final event in game.events) {
      if (effects) unawaited(GamePlatform.sound(event));
      if (event == 'go') syncMusic();
      if (event == 'pickup' || event == 'power' || event == 'transform') {
        unawaited(HapticFeedback.lightImpact());
      }
      if (event == 'finish') {
        unawaited(GamePlatform.music(false));
        stopSensor();
        if (!savedResult) {
          best = max(best, game.coins);
          save();
          savedResult = true;
        }
      }
    }
    game.events.clear();
    setState(() {});
  }

  void syncMusic() {
    unawaited(
      GamePlatform.music(
        music && inGame && game.state == PlayState.driving,
        track: musicTrack,
      ),
    );
  }

  void startSensor() {
    if (sensor != null) return;
    sensorFailed = false;
    sensor = GamePlatform.sensor.receiveBroadcastStream().listen(
      (dynamic event) {
        final a = (event as List).cast<num>();
        final value = tilt.sample(
          a[0].toDouble(),
          a[1].toDouble(),
          a[2].toDouble(),
        );
        if (game.state == PlayState.driving) {
          game.steer(value);
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        stopSensor();
        game.pause();
        game.steer(0);
        syncMusic();
        setState(() => sensorFailed = true);
      },
    );
  }

  void stopSensor() {
    unawaited(sensor?.cancel());
    sensor = null;
  }

  void begin() {
    setState(() {
      inGame = true;
      game = GameModel()
        ..fast = fast
        ..rocking = gentleRock;
      savedResult = false;
    });
    startSensor();
  }

  void retrySensor() {
    stopSensor();
    setState(() => sensorFailed = false);
    startSensor();
  }

  void depart() {
    if (sensorFailed) {
      retrySensor();
      return;
    }
    tilt.calibrate();
    game.steer(0);
    setState(game.start);
  }

  void pause() {
    game.pause();
    stopSensor();
    syncMusic();
    setState(() {});
  }

  void resume() {
    if (sensorFailed) {
      retrySensor();
      return;
    }
    game.resume();
    startSensor();
    syncMusic();
    setState(() {});
  }

  void goHome() {
    stopSensor();
    unawaited(GamePlatform.music(false));
    setState(() {
      inGame = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && inGame) {
      pause();
    } else if (state == AppLifecycleState.resumed &&
        inGame &&
        game.state == PlayState.ready) {
      startSensor();
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    stopSensor();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(GamePlatform.music(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !inGame,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        if (game.state == PlayState.ready || game.state == PlayState.finished) {
          goHome();
        } else {
          pause();
        }
      }
    },
    child: Scaffold(body: inGame ? playScreen() : homeScreen()),
  );
  Widget label(
    String text, {
    double size = 16,
    Color color = ink,
    FontWeight weight = FontWeight.w700,
  }) => Text(
    text,
    style: TextStyle(fontSize: size, color: color, fontWeight: weight),
  );
  Widget roundIcon(
    IconData icon,
    String tooltip,
    VoidCallback action, {
    Color color = ink,
  }) => IconButton.filledTonal(
    onPressed: action,
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .9),
      foregroundColor: color,
      minimumSize: const Size(54, 54),
    ),
    icon: Icon(icon, size: 25),
  );
  Widget primary(String title, IconData icon, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    height: 64,
    child: FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: orange,
        foregroundColor: const Color(0xff432f29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
      ),
      icon: Icon(icon, size: 28),
      label: Text(
        title,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
      ),
    ),
  );
  Widget homeScreen() => SafeArea(
    child: LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xffe2eddb),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.toys_rounded, color: ink),
                    ),
                    const SizedBox(width: 10),
                    label('LITTLE DRIVER', size: 12),
                    const Spacer(),
                    roundIcon(Icons.tune_rounded, '家长设置', settings),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    label('小小司机', size: 38, weight: FontWeight.w900),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: label(
                        '出发去冒险',
                        size: 13,
                        color: const Color(0xff87968a),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                label(
                  '转转小方向盘，收集一路的小快乐。',
                  size: 14,
                  color: const Color(0xff7b9084),
                  weight: FontWeight.w500,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: (bounds.maxHeight * .34).clamp(170, 290),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: RoadPainter(
                              game: GameModel(),
                              world: WorldTheme.all[scene],
                              preview: true,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: cream,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: label('摇摇车奇妙之旅', size: 12),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: const BoxDecoration(
                              color: cream,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: orange,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    label('今天去哪里？', size: 17),
                    const Spacer(),
                    label('3 个小世界', size: 12, color: const Color(0xff93a193)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                        child: Semantics(
                          selected: scene == i,
                          button: true,
                          label: WorldTheme.all[i].name,
                          child: InkWell(
                            onTap: () {
                              setState(() => scene = i);
                              save();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: scene == i
                                    ? const Color(0xffe1eddc)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: scene == i
                                      ? ink
                                      : const Color(0xffeeeade),
                                  width: scene == i ? 1.6 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    WorldTheme.all[i].icon,
                                    color: WorldTheme.all[i].accent,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 7),
                                  label(WorldTheme.all[i].name, size: 12),
                                  const SizedBox(height: 4),
                                  Icon(
                                    scene == i
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 16,
                                    color: scene == i
                                        ? ink
                                        : const Color(0xffd7ddd0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                primary('开车出发', Icons.play_arrow_rounded, begin),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.screen_rotation_rounded,
                      size: 16,
                      color: Color(0xff87968a),
                    ),
                    const SizedBox(width: 7),
                    label(
                      '左右转动手机 · 每次 90 秒',
                      size: 12,
                      color: const Color(0xff87968a),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: label(
                    best > 0
                        ? '最佳旅程  $best 枚金币  ·  和家长一起玩'
                        : '为小小探索家准备  ·  和家长一起玩',
                    size: 11,
                    color: const Color(0xff9da799),
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget playScreen() => LayoutBuilder(
    builder: (context, bounds) => Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: RoadPainter(game: game, world: WorldTheme.all[scene]),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: cream,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: Color(0xffe3ac37),
                            size: 27,
                          ),
                          const SizedBox(width: 7),
                          label('${game.coins}', size: 24),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cream,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: label('${game.time.ceil()} 秒', size: 16),
                    ),
                    const SizedBox(width: 10),
                    roundIcon(Icons.pause_rounded, '暂停', pause),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: game.time / 90,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: .5),
                    color: WorldTheme.all[scene].accent,
                  ),
                ),
                const SizedBox(height: 10),
                powerBar(),
                const Spacer(),
                if (game.transformed)
                  chip(
                    '${game.form.title}变身 ${game.formTime.ceil()}秒 · 撞开路障',
                    Icons.bolt_rounded,
                  )
                else if (game.noticeTime > 0)
                  chip(game.notice, Icons.auto_awesome_rounded),
                if (game.slow > 0) chip('没关系，继续出发！', Icons.favorite_rounded),
                if (game.state == PlayState.driving && game.time > 82)
                  chip('像方向盘一样，轻轻左右转', Icons.screen_rotation_rounded),
                const SizedBox(height: 10),
                drivingConsole(),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        if (game.state == PlayState.ready) overlay(readyCard()),
        if (game.state == PlayState.countdown)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 138,
                  height: 138,
                  decoration: const BoxDecoration(
                    color: cream,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: label('${game.countdown.ceil()}', size: 72),
                  ),
                ),
              ),
            ),
          ),
        if (game.state == PlayState.paused) overlay(pauseCard()),
        if (game.state == PlayState.finished) overlay(resultCard()),
      ],
    ),
  );
  Widget powerBar() => Row(
    children: PowerUp.values.map((p) {
      final count = game.inventory[p]!;
      final active = game.active(p);
      final color = [
        const Color(0xff74cae4),
        const Color(0xffe59aba),
        const Color(0xffe5bb56),
      ][p.index];
      final available = game.moving && count > 0 && !active;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Semantics(
            label: '${p.title}，$count 个，${active ? '使用中' : '点击使用'}',
            child: FilledButton.tonal(
              onPressed: available
                  ? () {
                      setState(() {
                        game.usePower(p);
                      });
                    }
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                backgroundColor: Color.lerp(color, Colors.white, .7),
                disabledBackgroundColor: active
                    ? color
                    : cream.withValues(alpha: .85),
                foregroundColor: ink,
                disabledForegroundColor: active ? ink : const Color(0xff6c8687),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: active ? Colors.white : color,
                    width: active ? 2 : 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        [
                          Icons.shield_rounded,
                          Icons.attractions_rounded,
                          Icons.star_rounded,
                        ][p.index],
                        size: 23,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        active ? '${game.remaining(p).ceil()}秒' : '×$count',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    active
                        ? '正在生效'
                        : count > 0
                        ? '点我使用'
                        : '路上拾取',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
  Widget drivingConsole() => SizedBox(
    height: 106,
    child: Center(
      child: Semantics(
        button: true,
        label: '按喇叭',
        child: GestureDetector(
          onTap: () {
            if (game.moving && effects) unawaited(GamePlatform.sound('horn'));
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 94,
                height: 84,
                child: CustomPaint(
                  painter: WheelPainter(
                    game.x * .9,
                    color: const Color(0xff355c67),
                  ),
                ),
              ),
              const Text(
                '按方向盘 · 嘟嘟',
                style: TextStyle(
                  color: Color(0xffffedc3),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget chip(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: cream,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: ink),
        const SizedBox(width: 6),
        label(text, size: 12),
      ],
    ),
  );
  Widget overlay(Widget child) => Positioned.fill(
    child: Container(
      color: const Color(0x66345245),
      alignment: Alignment.center,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 410),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: cream,
              borderRadius: BorderRadius.circular(32),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
  Widget readyCard() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      label('准备好小手了吗？', size: 25),
      const SizedBox(height: 8),
      label(
        WorldTheme.all[scene].caption,
        size: 14,
        color: const Color(0xff849184),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: 115,
        height: 115,
        child: CustomPaint(
          painter: WheelPainter(
            sin(DateTime.now().millisecondsSinceEpoch / 600) * .35,
          ),
        ),
      ),
      const SizedBox(height: 18),
      label('竖握手机，轻轻左右转', size: 18),
      const SizedBox(height: 9),
      Text(
        sensorFailed
            ? '暂时无法读取手机方向。\n请重试，或换一台支持重力感应的手机。'
            : '先用舒服的姿势握好手机，\n点击出发，记住现在的方向。',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xff7f9284),
          height: 1.7,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 24),
      primary(
        sensorFailed ? '重试方向传感器' : '准备好啦，出发！',
        Icons.flag_rounded,
        depart,
      ),
      const SizedBox(height: 9),
      TextButton(onPressed: goHome, child: const Text('返回小车库')),
    ],
  );
  Widget pauseCard() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.local_cafe_rounded, size: 48, color: orange),
      const SizedBox(height: 14),
      label('停一停，歇一歇', size: 26),
      const SizedBox(height: 10),
      label('小车在这里等你', size: 14, color: const Color(0xff849184)),
      const SizedBox(height: 28),
      if (sensorFailed)
        const Text('暂时无法读取手机方向，请重试传感器。', textAlign: TextAlign.center),
      primary(
        sensorFailed ? '重试方向传感器' : '继续兜风',
        Icons.play_arrow_rounded,
        resume,
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () {
          tilt.calibrate();
          game.steer(0);
          resume();
        },
        icon: const Icon(Icons.screen_rotation_rounded),
        label: const Text('握好手机，重新校准'),
      ),
      TextButton.icon(
        onPressed: () {
          setState(() => music = !music);
          save();
        },
        icon: Icon(music ? Icons.music_note_rounded : Icons.music_off_rounded),
        label: Text(music ? '背景音乐 已开启' : '背景音乐 已关闭'),
      ),
      TextButton.icon(
        onPressed: () {
          setState(() => musicTrack = (musicTrack + 1) % songNames.length);
          save();
        },
        icon: const Icon(Icons.queue_music_rounded),
        label: Text('儿歌：${songNames[musicTrack]} · 换一首'),
      ),
      TextButton(onPressed: goHome, child: const Text('返回小车库')),
    ],
  );
  Widget resultCard() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      label('兜风完成！', size: 30),
      const SizedBox(height: 10),
      label('你是很棒的小司机', size: 15, color: const Color(0xff849184)),
      const SizedBox(height: 22),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.star_rounded,
              size: i == 1 ? 62 : 48,
              color: i < game.stars
                  ? const Color(0xffefbd4b)
                  : const Color(0xffe0e5d6),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      label('${game.coins}', size: 58),
      label('枚闪闪的金币', size: 14, color: const Color(0xff849184)),
      const SizedBox(height: 15),
      chip('最佳记录  $best', Icons.emoji_events_rounded),
      const SizedBox(height: 22),
      label('看看远处，和眼睛一起休息一下吧', size: 12, color: const Color(0xff849184)),
      const SizedBox(height: 22),
      primary('再去兜一圈', Icons.replay_rounded, begin),
      const SizedBox(height: 10),
      TextButton(onPressed: goHome, child: const Text('返回小车库')),
    ],
  );
  Future<void> settings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label('小车库设置', size: 25),
                  const SizedBox(height: 6),
                  label(
                    '选一个舒服的方式，慢慢探索。',
                    size: 13,
                    color: const Color(0xff849184),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('儿歌背景音乐'),
                    secondary: const Icon(Icons.music_note_rounded),
                    value: music,
                    onChanged: (v) {
                      setState(() => music = v);
                      refresh(() {});
                      save();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<int>(
                      initialValue: musicTrack,
                      decoration: const InputDecoration(
                        labelText: '选一首儿歌 · 轻柔器乐版',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        songNames.length,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(songNames[i]),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => musicTrack = value);
                        refresh(() {});
                        save();
                      },
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('轻轻摇摆'),
                    subtitle: const Text('车身柔和起伏，不晃动整个画面'),
                    secondary: const Icon(Icons.toys_rounded),
                    value: gentleRock,
                    onChanged: (value) {
                      setState(() {
                        gentleRock = value;
                        game.rocking = value;
                      });
                      refresh(() {});
                      save();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('金币和碰撞音效'),
                    secondary: const Icon(Icons.volume_up_rounded),
                    value: effects,
                    onChanged: (v) {
                      setState(() => effects = v);
                      refresh(() {});
                      save();
                    },
                  ),
                  const SizedBox(height: 14),
                  label('驾驶速度', size: 16),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('舒缓兜风'),
                          icon: Icon(Icons.spa_rounded),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('轻快出游'),
                          icon: Icon(Icons.air_rounded),
                        ),
                      ],
                      selected: {fast},
                      onSelectionChanged: (v) {
                        setState(() => fast = v.first);
                        refresh(() {});
                        save();
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '离线游玩 · 无广告 · 无内购\n建议家长陪同，坐稳后双手握住手机。',
                    style: TextStyle(
                      color: Color(0xff849184),
                      fontSize: 12,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 20),
                  primary(
                    '设置好啦',
                    Icons.check_rounded,
                    () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
