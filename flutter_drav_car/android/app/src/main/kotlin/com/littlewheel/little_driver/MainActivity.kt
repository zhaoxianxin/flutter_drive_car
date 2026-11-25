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

class MainActivity : FlutterActivity(), SensorEventListener {
    private var sink: EventChannel.EventSink? = null
    private lateinit var sensors: SensorManager
    private var pool: SoundPool? = null
    private val sounds = mutableMapOf<String, Int>()
    private val loaded = mutableSetOf<Int>()
    private var music: MediaPlayer? = null
    private var selectedTrack = -1
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        pool = SoundPool.Builder().setMaxStreams(5).setAudioAttributes(attributes).build()
        pool?.setOnLoadCompleteListener { _, id, status -> if (status == 0) loaded.add(id) }
        for (name in listOf("coin", "bump", "start", "go", "finish", "pickup", "power", "guard", "horn", "transform", "smash")) {
            assets.openFd("flutter_assets/assets/audio/$name.wav").use {
                sounds[name] = pool!!.load(it, 1)
            }
        }
        EventChannel(engine.dartExecutor.binaryMessenger, "little_driver/tilt")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val sensor = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                    if (sensor == null) { events.error("NO_SENSOR", "Touch controls available", null); return }
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
                            val id = sounds[call.arguments as? String]
                            if (id != null && loaded.contains(id)) pool?.play(id, .65f, .65f, 1, 0, 1f)
                            result.success(null)
                        }
                        "music" -> {
                            val args = call.arguments as? Map<*, *>
                            val track = ((args?.get("track") as? Number)?.toInt() ?: 0).coerceIn(0, 2)
                            if (args?.get("play") == true) {
                                if (selectedTrack != track) { music?.release(); music = null; selectedTrack = track }
                                if (music == null) {
                                    music = MediaPlayer().apply {
                                        setAudioAttributes(attributes)
                                        val file = listOf("twinkle", "frere", "music")[track]
                                        assets.openFd("flutter_assets/assets/audio/$file.wav").use {
                                            setDataSource(it.fileDescriptor, it.startOffset, it.length)
                                        }
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
    override fun onSensorChanged(event: SensorEvent) {
        sink?.success(event.values.take(3).map { it.toDouble() })
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onPause() { sensors.unregisterListener(this); music?.pause(); super.onPause() }
    override fun onResume() {
        super.onResume()
        if (::sensors.isInitialized && sink != null) {
            sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
                sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
        }
    }
    override fun onDestroy() {
        sensors.unregisterListener(this); music?.release(); pool?.release(); super.onDestroy()
    }
}
