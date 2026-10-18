package com.arun.ascent

import android.content.Intent
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var liveChannel: MethodChannel? = null
    private var reusedEngine = false
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        val existing = cache.get("ascent_main")
        if (existing != null) { reusedEngine = true; return existing }
        val engine = FlutterEngine(context.applicationContext)
        cache.put("ascent_main", engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return engine
    }
    // Live timers retain their single Dart authority when the Activity closes.
    override fun shouldDestroyEngineWithHost(): Boolean = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ascent/device-timezone").setMethodCallHandler { call, result ->
            if (call.method == "getTimeZone") result.success(TimeZone.getDefault().id) else result.notImplemented()
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ascent/music").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "status" -> result.success(MusicCompanion.status(this))
                    "settings" -> { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                    "control" -> result.success(MusicCompanion.control(this, call.argument<String>("package"), call.argument<String>("action")))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("music_unavailable", "Music access unavailable", null) }
        }
        liveChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ascent/live-sessions")
        LiveSessions.bridge = liveChannel
        liveChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "update" -> { LiveSessions.update(this, JSONObject(call.arguments as Map<*,*>)); result.success(true) }
                    "cancel" -> { LiveSessions.cancel(this, call.argument<String>("route")!!); result.success(true) }
                    "consumeIntent" -> { result.success(mapOf("route" to intent.getStringExtra("ascent_route"), "action" to intent.getStringExtra("ascent_action"))); intent.removeExtra("ascent_route"); intent.removeExtra("ascent_action") }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("session_unavailable", e.message, null) }
        }
        val alarms = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ascent/reminder-alarms")
        AlarmStore.bridge = alarms
        alarms.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "schedule" -> result.success(AlarmStore.schedule(this, call.argument<Int>("id")!!, call.argument<String>("title")!!, call.argument<Number>("at")!!.toLong()))
                    "cancel" -> { AlarmStore.cancel(this, call.argument<Int>("id")!!); result.success(null) }
                    "cancelAll" -> { for (row in AlarmStore.all(this)) AlarmStore.cancel(this, row.getInt("id")); AlarmStore.prefs(this).edit().putString("events", "[]").commit(); result.success(null) }
                    "act" -> result.success(AlarmStore.act(this, call.argument<Int>("id")!!, call.argument<String>("action")!!))
                    "events" -> { val events = AlarmStore.events(this); result.success((0 until events.length()).map { i -> val row = events.getJSONObject(i); row.keys().asSequence().associateWith { key -> row.get(key) } }) }
                    "ack" -> { AlarmStore.ack(this, call.argument<List<String>>("tokens")!!); result.success(null) }
                    "ringing" -> result.success(AlarmStore.ringing(this).mapNotNull { id -> AlarmStore.alarm(this, id)?.let { mapOf("id" to id, "title" to it.getString("title")) } })
                    "status" -> result.success(mapOf("serviceRunning" to AlarmRingingService.running, "soundPlaying" to AlarmRingingService.soundPlaying()))
                    "access" -> result.success(mapOf("exact" to AlarmStore.canExact(this), "fullScreen" to AlarmStore.canFull(this), "notifications" to AlarmStore.allowed(this)))
                    "requestAccess" -> {
                        if (Build.VERSION.SDK_INT >= 34 && !AlarmStore.canFull(this)) startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
                        else if (Build.VERSION.SDK_INT >= 31 && !AlarmStore.canExact(this)) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("alarm_unavailable", e.message, null) }
        }
        if (reusedEngine && intent.getStringExtra("ascent_route") != null) {
            liveChannel?.invokeMethod("open", mapOf("route" to intent.getStringExtra("ascent_route"), "action" to intent.getStringExtra("ascent_action")))
            intent.removeExtra("ascent_route"); intent.removeExtra("ascent_action")
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = intent.getStringExtra("ascent_route")
        if (route != null) {
            liveChannel?.invokeMethod("open", mapOf("route" to route, "action" to intent.getStringExtra("ascent_action")))
            intent.removeExtra("ascent_route"); intent.removeExtra("ascent_action")
        }
    }
}
