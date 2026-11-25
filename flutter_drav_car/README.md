# 小小司机

为约4岁儿童设计的 Flutter 离线驾驶游戏。双手竖握手机，像方向盘一样左右转动，控制小车收集金币、躲避软路障。包含草地、海边、糖果三种场景，以及粒子、保护泡泡、原创背景音乐和音效。

## 开始体验

安卓安装 `dist/little-driver-android.apk`。iPhone版可通过Xcode自动签名安装，当前工程选择上海诚助团队 `D76FYB6A7W`；真机需包含在开发描述文件中。

1. 打开「小小司机」，选择场景，点「开车出发」。
2. 竖握手机，上端朝上，屏幕稍向自己倾斜；保持舒服的姿势，点「准备好啦，出发！」完成校准。
3. 倒数3秒后，向左或向右轻轻转动手机。小车自动向前，每局90秒。
4. 收集金币，不小心碰到路障只短暂减速，不会失败。暂停页可重新校准或关闭音乐。
5. 如果手机平放，倾斜方向不稳定，游戏保留上次有效方向；请竖握手机。仅支持手机倾斜控制方向；读取传感器失败时会暂停并提供重试。

设置可独立关闭音乐与音效，选择舒缓或轻快速度；设置和最佳记录保存在设备本机。iPhone采用环境音频，静音开关开启时可能听不到声音，请检查静音开关与媒体音量。

## 工程结构

- `docs/game-design.md`：先于实现完成的产品与技术设计。
- `lib/game/game_model.dart`：独立规则、生成、碰撞、保护、倒计时、倾斜滤波。
- `lib/game/road_painter.dart`：绘本赛道、小车、金币、路障、粒子与方向盘。
- `lib/main.dart`：首页、设置、准备、驾驶、暂停、结算及生命周期。
- `android/.../MainActivity.kt`：SensorManager、SoundPool、MediaPlayer及本机设置。
- `ios/Runner/AppDelegate.swift`：CoreMotion、AVAudioPlayer及本机设置。
- `tools/generate_audio.py`：标准库生成原创WAV声音。
- `tools/generate_icons.swift`：生成小车应用图标。
- `test/game_test.dart`：模型和页面流程验证。

## 开发与构建

使用 Flutter 3.47.5 所附 Dart 3.13，Android Gradle Plugin 8.11.1、Gradle 8.14.3、Kotlin 2.2.20、JDK 21、Android SDK 35。Android最低API以Flutter默认minSdk配置为准，iOS最低版本以 Xcode 工程配置为准。无第三方运行时插件。

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build ios --release
```

本机 `android/local.properties` 定位 Flutter 和 Android SDK（已忽略）；`android/gradle.properties` 当前设有本机JDK21路径，换机器请删除 `org.gradle.java.home` 或改为自己的JDK21路径。Flutter可能优先使用Android Studio内置JDK25，与本工程Gradle不兼容，可指定Flutter的JDK21配置，或用JDK21直接执行Gradle。

安卓体验包使用debug签名的release构建，便于本地安装，不是商店发布签名。iPhone使用用户指定团队的自动开发签名，未发布到App Store。网络依赖只在构建时下载；游戏运行不需要网络权限。

本工程没有C++目标，安卓配置清除了Flutter用于触发NDK下载的空CMake目标，并保留预编译运行库的符号，不需要额外下载NDK；如后续加入C/C++或FFI依赖，应移除此配置并安装对应NDK。

安卓交付包已生成：`dist/little-driver-android.apk`，版本1.1.1，支持Android 7.0及以上，包含arm32、arm64和x86_64架构。按要求跳过发布Lint与额外安卓试玩；此前Dart静态分析和8项自动测试已通过。

## 版本1点1新增体验

- 透视道路、远山和天空、近大远小的物体、带高光和阴影的玩具车，底部玩具仪表台与可按喇叭的方向盘。
- 轻轻摇摆只作用于车身；家长设置可关闭，不会晃动整个画面。
- 泡泡盾、小磁铁、彩虹星：拾取后进入顶部按钮，点击使用；分别保护8秒、吸金币8秒、双倍金币6秒，每类最多存3个。
- 飞机、坦克、恐龙、佩奇：碰到相应图案的盒子后自动变身10秒，期间撞碎路障，不会再生成或保留其他变身盒子；结束回到小车并短暂保护。
- 儿歌器乐版小星星、两只老虎，以及原创欢乐兜风；在家长设置选择，在暂停页也可换歌。录音由本项目重新编排合成，详见assets/audio/README.md。

本次17项测试通过，覆盖4种自动变身、变身期间禁刷、碎块、暂停冻结、道具库存、吸金币、双倍奖励、按钮使用及全部场景造型绘制。

新版交付：dist/little-driver-v1.1.0.apk（同时更新通用文件名little-driver-android.apk）。iOS 1.1已通过上海诚助团队自动签名构建，本次未重新安装到真机；手机上此前安装的是1.0版。造型预览：docs/qa/v11-forms.png。

## 版本1点1点1操作更新

移除左右按钮、道路拖动和触控模式开关。旧版保存的触控设置不再读取，统一使用倾斜控制方向；保留点击使用道具和按方向盘鸣笛。传感器失败时提示重试并暂停驾驶。新版安卓包为dist/little-driver-v1.1.1.apk。
