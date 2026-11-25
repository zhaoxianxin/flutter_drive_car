package com.littlewheel.little_driver

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), SensorEventListener {
    private var sink: EventChannel.EventSink? = null
    private lateinit var sensors: SensorManager
    private var pool: SoundPool? = null
    private val sounds = mutableMapOf<String, Int>()
    private val loaded = mutableSetOf<Int>()
    private var music: MediaPlayer? = null
    private var selectedTrack = -1
    private var engineStream = 0
    private var ambientStream = 0
    private var engineName = ""
    private var ambientName = ""
    private var latestDrive: Map<*, *>? = null
    private val effects = listOf("coin", "bump", "start", "go", "finish", "pickup", "power", "guard", "horn", "transform", "smash", "combo", "near", "warning", "revert", "dino_voice", "pig_voice")
    private val engines = listOf("car", "plane", "tank", "dinosaur", "peppa")
    private val ambiences = listOf("grass", "sea", "candy")

    private fun stopDrive() {
        pool?.stop(engineStream); pool?.stop(ambientStream)
        engineStream = 0; ambientStream = 0; engineName = ""; ambientName = ""
    }
    private fun drive(args: Map<*, *>?) {
        if (args?.get("playing") != true) { stopDrive(); return }
        val form = (args["form"] as? String).takeIf { engines.contains(it) } ?: "car"
        val scene = ((args["scene"] as? Number)?.toInt() ?: 0).coerceIn(0, 2)
        val speed = ((args["speed"] as? Number)?.toFloat() ?: 0f).coerceIn(0f, 1f)
        val engine = "engine_$form"
        val ambience = "ambient_${ambiences[scene]}"
        if (engineName != engine || engineStream == 0) {
            pool?.stop(engineStream); engineStream = 0
            val id = sounds[engine]
            if (id != null && loaded.contains(id)) {
                engineStream = pool?.play(id, .18f, .18f, 1, -1, 1f) ?: 0
                engineName = engine
            }
        }
        if (ambientName != ambience || ambientStream == 0) {
            pool?.stop(ambientStream); ambientStream = 0
            val id = sounds[ambience]
            if (id != null && loaded.contains(id)) {
                ambientStream = pool?.play(id, .14f, .14f, 0, -1, 1f) ?: 0
                ambientName = ambience
            }
        }
        pool?.setRate(engineStream, .84f + speed * .22f)
        val volume = .11f + speed * .08f
        pool?.setVolume(engineStream, volume, volume)
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        pool = SoundPool.Builder().setMaxStreams(12).setAudioAttributes(attributes).build()
        pool?.setOnLoadCompleteListener { _, id, status ->
            if (status == 0) { loaded.add(id); latestDrive?.let { drive(it) } }
        }
        for (name in effects + engines.map { "engine_$it" } + ambiences.map { "ambient_$it" }) {
            assets.openFd("flutter_assets/assets/audio/$name.wav").use { sounds[name] = pool!!.load(it, 1) }
        }
        EventChannel(engine.dartExecutor.binaryMessenger, "little_driver/tilt")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val sensor = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                    if (sensor == null) { events.error("NO_SENSOR", "Motion sensor unavailable", null); return }
                    sink = events
                    sensors.registerListener(this@MainActivity, sensor, SensorManager.SENSOR_DELAY_GAME)
                }
                override fun onCancel(arguments: Any?) { sensors.unregisterListener(this@MainActivity); sink = null }
            })
        MethodChannel(engine.dartExecutor.binaryMessenger, "little_driver/platform")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "sound" -> {
                            val args = call.arguments as? Map<*, *>
                            val name = args?.get("name") as? String ?: call.arguments as? String
                            val id = sounds[name]
                            val pan = ((args?.get("pan") as? Number)?.toFloat() ?: 0f).coerceIn(-1f, 1f)
                            val rate = ((args?.get("pitch") as? Number)?.toFloat() ?: 1f).coerceIn(.7f, 1.5f)
                            if (id != null && loaded.contains(id)) {
                                pool?.play(id, .55f * sqrt(1f-pan), .55f * sqrt(1f+pan), 2, 0, rate)
                            }
                            result.success(null)
                        }
                        "drive" -> { latestDrive = call.arguments as? Map<*, *>; drive(latestDrive); result.success(null) }
                        "music" -> {
                            val args = call.arguments as? Map<*, *>
                            val track = ((args?.get("track") as? Number)?.toInt() ?: 0).coerceIn(0, 2)
                            if (args?.get("play") == true) {
                                if (selectedTrack != track) { music?.release(); music = null; selectedTrack = track }
                                if (music == null) {
                                    music = MediaPlayer().apply {
                                        setAudioAttributes(attributes)
                                        val file = listOf("twinkle", "frere", "music")[track]
                                        assets.openFd("flutter_assets/assets/audio/$file.wav").use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
                                        isLooping = true; setVolume(.22f, .22f); prepare()
                                    }
                                }
                                music?.start()
                            } else { music?.pause() }
                            result.success(null)
                        }
                        "load" -> result.success(getSharedPreferences("driver", MODE_PRIVATE).all)
                        "save" -> {
                            val editor = getSharedPreferences("driver", MODE_PRIVATE).edit()
                            (call.arguments as? Map<*, *>)?.forEach { (key, value) ->
                                when (value) {
                                    is Boolean -> editor.putBoolean(key.toString(), value)
                                    is Int -> editor.putInt(key.toString(), value)
                                    is String -> editor.putString(key.toString(), value)
                                }
                            }
                            editor.apply(); result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("PLATFORM", e.message, null) }
            }
    }
    override fun onSensorChanged(event: SensorEvent) { sink?.success(event.values.take(3).map { it.toDouble() }) }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onPause() {
        if (::sensors.isInitialized) sensors.unregisterListener(this)
        latestDrive = null; stopDrive(); music?.pause(); super.onPause()
    }
    override fun onResume() {
        super.onResume()
        if (::sensors.isInitialized && sink != null) {
            sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
        }
    }
    override fun onDestroy() {
        if (::sensors.isInitialized) sensors.unregisterListener(this)
        stopDrive(); music?.release(); pool?.release(); super.onDestroy()
    }
}
