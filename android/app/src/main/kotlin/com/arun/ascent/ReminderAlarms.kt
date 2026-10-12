package com.arun.ascent

import android.app.*
import android.content.*
import android.graphics.Color
import android.media.*
import android.os.*
import android.provider.Settings
import android.view.Gravity
import android.widget.*
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

internal object AlarmStore {
    const val CHANNEL = "ascent_ringing_alarms_v1"
    const val CHANGED = "com.arun.ascent.ALARM_CHANGED"
    var bridge: MethodChannel? = null
    private var queueInitialized = false
    fun prefs(c: Context) = c.getSharedPreferences("ascent_native_alarms", Context.MODE_PRIVATE)
    fun alarm(c: Context, id: Int): JSONObject? = prefs(c).getString("alarm_$id", null)?.let { JSONObject(it) }
    fun all(c: Context): List<JSONObject> = prefs(c).all.filterKeys { it.startsWith("alarm_") }.values.mapNotNull { runCatching { JSONObject(it as String) }.getOrNull() }
    fun notificationId(id: Int) = 1000000 + id
    fun intent(c: Context, id: Int, action: String = "fire") = Intent(c, ReminderAlarmReceiver::class.java).setAction(action).putExtra("id", id)
    fun pending(c: Context, id: Int, action: String = "fire") = PendingIntent.getBroadcast(c, id, intent(c, id, action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun open(c: Context, id: Int): PendingIntent {
        val options = ActivityOptions.makeBasic()
        if (Build.VERSION.SDK_INT >= 36) options.setPendingIntentCreatorBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOW_ALWAYS)
        else if (Build.VERSION.SDK_INT >= 35) options.setPendingIntentCreatorBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
        return PendingIntent.getActivity(c, id, Intent(c, ReminderAlarmActivity::class.java).putExtra("id", id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE, options.toBundle())
    }
    fun canExact(c: Context) = Build.VERSION.SDK_INT < 31 || c.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun canFull(c: Context) = Build.VERSION.SDK_INT < 34 || c.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
    fun allowed(c: Context) = c.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    @Synchronized fun schedule(c: Context, id: Int, title: String, at: Long): Boolean {
        if (id <= 0 || title.isBlank() || at <= System.currentTimeMillis() || !canExact(c) || !allowed(c)) return false
        val record = JSONObject().put("id", id).put("title", title).put("at", at)
        if (!prefs(c).edit().putString("alarm_$id", record.toString()).commit()) return false
        return try {
            c.getSystemService(AlarmManager::class.java).setAlarmClock(AlarmManager.AlarmClockInfo(at, open(c, id)), pending(c, id))
            true
        } catch (_: Exception) { prefs(c).edit().remove("alarm_$id").commit(); false }
    }
    @Synchronized fun ringing(c: Context): List<Int> {
        // A stopped process cannot keep a live ringing UI. Saved rows remain overdue.
        if (!queueInitialized) {
            if (!AlarmRingingService.running) prefs(c).edit().putString("ringing", "[]").commit()
            queueInitialized = true
        }
        val a = JSONArray(prefs(c).getString("ringing", "[]"))
        return (0 until a.length()).map { a.getInt(it) }.filter { alarm(c, it) != null }
    }
    @Synchronized fun enqueue(c: Context, id: Int) {
        if (alarm(c, id) == null) return
        val ids = ringing(c).toMutableList()
        if (!ids.contains(id)) ids.add(id)
        prefs(c).edit().putString("ringing", JSONArray(ids).toString()).commit()
    }
    fun events(c: Context) = JSONArray(prefs(c).getString("events", "[]"))
    @Synchronized fun ack(c: Context, tokens: List<String>) {
        val old = events(c); val next = JSONArray()
        for (i in 0 until old.length()) if (!tokens.contains(old.getJSONObject(i).optString("token"))) next.put(old.getJSONObject(i))
        prefs(c).edit().putString("events", next.toString()).commit()
    }
    @Synchronized fun cancel(c: Context, id: Int) {
        c.getSystemService(AlarmManager::class.java).cancel(pending(c, id))
        val events = events(c); val keep = JSONArray()
        for (i in 0 until events.length()) if (events.getJSONObject(i).optInt("id") != id) keep.put(events.getJSONObject(i))
        prefs(c).edit().remove("alarm_$id").putString("ringing", JSONArray(ringing(c).filter { it != id }).toString()).putString("events", keep.toString()).commit()
        c.getSystemService(NotificationManager::class.java).cancel(notificationId(id))
        refresh(c)
    }
    @Synchronized fun act(c: Context, id: Int, action: String): Boolean {
        val row = alarm(c, id) ?: return true
        if (action != "done" && action != "snooze") return false
        val at = System.currentTimeMillis() + 600000L
        if (action == "snooze" && !schedule(c, id, row.getString("title"), at)) return false
        val next = events(c).put(JSONObject().put("id", id).put("action", action).put("at", at).put("token", UUID.randomUUID().toString()))
        val edit = prefs(c).edit().putString("events", next.toString()).putString("ringing", JSONArray(ringing(c).filter { it != id }).toString())
        if (action == "done") edit.remove("alarm_$id")
        if (!edit.commit()) return false
        if (action == "done") c.getSystemService(AlarmManager::class.java).cancel(pending(c, id))
        c.getSystemService(NotificationManager::class.java).cancel(notificationId(id))
        refresh(c)
        Handler(Looper.getMainLooper()).post { bridge?.invokeMethod("eventsChanged", null) }
        return true
    }
    fun refresh(c: Context) {
        c.sendBroadcast(Intent(CHANGED).setPackage(c.packageName))
        if (AlarmRingingService.running) c.startService(Intent(c, AlarmRingingService::class.java).setAction("refresh"))
    }
    fun createChannel(c: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "Ringing reminder alarms", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Opt-in alarms with Snooze and Done"
            channel.setSound(null, null) // The alarm service owns the looping sound.
            c.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            for (row in AlarmStore.all(context)) {
                val at = maxOf(row.getLong("at"), System.currentTimeMillis() + 5000)
                AlarmStore.schedule(context, row.getInt("id"), row.getString("title"), at)
            }
            return
        }
        val id = intent.getIntExtra("id", -1)
        if (intent.action == "done" || intent.action == "snooze") {
            AlarmStore.act(context, id, intent.action!!)
            return
        }
        if (AlarmStore.alarm(context, id) == null) return
        android.util.Log.i("AscentAlarm", "alarm receiver fired id=$id")
        AlarmStore.enqueue(context, id)
        val service = Intent(context, AlarmRingingService::class.java)
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service) else context.startService(service)
    }
}

class AlarmRingingService : Service() {
    companion object {
        var running = false
        private var instance: AlarmRingingService? = null
        fun soundPlaying() = runCatching { instance?.player?.isPlaying == true }.getOrDefault(false)
    }
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var current = -1
    override fun onBind(intent: Intent?) = null
    override fun onCreate() { super.onCreate(); running = true; instance = this; AlarmStore.createChannel(this) }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val ids = AlarmStore.ringing(this)
        if (ids.isEmpty()) { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return START_NOT_STICKY }
        val id = ids.first(); val row = AlarmStore.alarm(this, id)!!
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, AlarmStore.CHANNEL) else Notification.Builder(this)
        builder.setSmallIcon(R.drawable.ic_notification_ascent).setContentTitle(row.getString("title").take(80)).setContentText("Alarm · Snooze or Done to stop")
            .setStyle(Notification.BigTextStyle().bigText(row.getString("title")).setSummaryText("Snooze 10 min or Done to stop"))
            .setCategory(Notification.CATEGORY_ALARM).setPriority(Notification.PRIORITY_MAX).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true).setAutoCancel(false).setColor(Color.rgb(169, 82, 53))
            .setContentIntent(AlarmStore.open(this, id))
            .addAction(Notification.Action.Builder(null, "Snooze 10 min", AlarmStore.pending(this, id, "snooze")).build())
            .addAction(Notification.Action.Builder(null, "Done", AlarmStore.pending(this, id, "done")).build())
        if (AlarmStore.canFull(this)) builder.setFullScreenIntent(AlarmStore.open(this, id), true)
        startForeground(AlarmStore.notificationId(id), builder.build())
        android.util.Log.i("AscentAlarm", "foreground alarm id=$id")
        if (current != id) {
            if (current > 0) getSystemService(NotificationManager::class.java).cancel(AlarmStore.notificationId(current))
            current = id
            stopAudio()
            try {
                player = MediaPlayer().apply {
                    setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                    setDataSource(this@AlarmRingingService, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                    isLooping = true
                    setWakeMode(this@AlarmRingingService, PowerManager.PARTIAL_WAKE_LOCK)
                    prepare(); start(); android.util.Log.i("AscentAlarm", "looping sound started")
                }
            } catch (_: Exception) { player?.release(); player = null }
            vibrator = getSystemService(Vibrator::class.java)
            val pattern = longArrayOf(0, 700, 500)
            if (Build.VERSION.SDK_INT >= 26) vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0)) else @Suppress("DEPRECATION") vibrator?.vibrate(pattern, 0)
            Handler(Looper.getMainLooper()).post { AlarmStore.bridge?.invokeMethod("alarmRinging", mapOf("id" to id, "title" to row.getString("title"))) }
        }
        return START_NOT_STICKY
    }
    private fun stopAudio() { player?.stop(); player?.release(); player = null; vibrator?.cancel() }
    override fun onDestroy() { stopAudio(); running = false; instance = null; android.util.Log.i("AscentAlarm", "ringing service stopped"); super.onDestroy() }
}

class ReminderAlarmActivity : Activity() {
    private var alarmId = -1
    private val receiver = object : BroadcastReceiver() { override fun onReceive(c: Context, i: Intent) { if (!AlarmStore.ringing(c).contains(alarmId)) finish() } }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(true); setTurnScreenOn(true) }
        else @Suppress("DEPRECATION") window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        alarmId = intent.getIntExtra("id", -1)
        render()
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); alarmId = intent.getIntExtra("id", -1); render() }
    override fun onStart() { super.onStart(); if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, IntentFilter(AlarmStore.CHANGED), Context.RECEIVER_NOT_EXPORTED) else registerReceiver(receiver, IntentFilter(AlarmStore.CHANGED)) }
    override fun onStop() { unregisterReceiver(receiver); super.onStop() }
    private fun render() {
        val row = AlarmStore.alarm(this, alarmId) ?: run { finish(); return }
        val scale = resources.displayMetrics.density
        val pad = (28 * scale).toInt()
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER; setPadding(pad,pad,pad,pad); setBackgroundColor(Color.rgb(249, 246, 239)) }
        fun label(value: String, size: Float) { layout.addView(TextView(this).apply { text = value; textSize = size; setTextColor(Color.rgb(48, 39, 32)); gravity = Gravity.CENTER; setPadding(0,pad/2,0,pad/2) }) }
        label("REMINDER ALARM", 16f); label(row.getString("title"), 26f); label("Snooze or Done stops the ringing", 15f)
        fun button(value: String, action: String) { layout.addView(Button(this).apply { text = value; isAllCaps = false; backgroundTintList = android.content.res.ColorStateList.valueOf(Color.rgb(169,82,53)); setTextColor(Color.WHITE); setOnClickListener { if (AlarmStore.act(this@ReminderAlarmActivity, alarmId, action)) finish() else Toast.makeText(this@ReminderAlarmActivity, "Could not finish. Check alarm access and retry.", Toast.LENGTH_LONG).show() } }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = pad/2 }) }
        button("Snooze 10 minutes", "snooze"); button("Done", "done")
        layout.addView(Button(this).apply { text = "Open Reminders"; isAllCaps = false; backgroundTintList = android.content.res.ColorStateList.valueOf(Color.rgb(169,82,53)); setTextColor(Color.WHITE); setOnClickListener { startActivity(Intent(this@ReminderAlarmActivity, MainActivity::class.java).putExtra("ascent_route", "/reminders").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)); finish() } })
        setContentView(ScrollView(this).apply { isFillViewport = true; addView(layout) })
    }
}
