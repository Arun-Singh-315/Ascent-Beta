package com.arun.ascent

import android.app.*
import android.content.*
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.content.res.ColorStateList
import android.content.res.Configuration
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
        fun dp(value: Int) = (value * scale).toInt()
        val mode = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .getString("flutter.ascent_theme_mode", "system")
        val dark = mode == "dark" || (mode != "light" &&
            resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES)
        val ink = Color.parseColor(if (dark) "#ECEAF2" else "#2B221B")
        val muted = Color.parseColor(if (dark) "#B4B7C6" else "#74695F")
        val clay = Color.parseColor(if (dark) "#E6A088" else "#A4523A")
        val edge = Color.parseColor(if (dark) "#26FFFFFF" else "#182B221B")
        val font = runCatching { Typeface.createFromAsset(assets,
            "flutter_assets/assets/fonts/PlusJakartaSans-Regular.ttf") }.getOrDefault(Typeface.DEFAULT)
        fun surface(fill: Int, radius: Int = 24) = GradientDrawable().apply {
            setColor(fill); cornerRadius = dp(radius).toFloat(); setStroke(dp(1), edge)
        }
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            setPadding(dp(24), dp(48), dp(24), dp(48))
            background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(
                Color.parseColor(if (dark) "#16110D" else "#F4F3F8"),
                Color.parseColor(if (dark) "#32231D" else "#F0DFD5"),
                Color.parseColor(if (dark) "#16110D" else "#F4F3F8")))
        }
        // Own atmospheric background allows translucent surfaces without exposing lock-screen content.
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(24), dp(24), dp(24), dp(24))
            background = surface(Color.parseColor(if (dark) "#14FFFFFF" else "#AAFFFFFF"))
        }
        layout.addView(card, LinearLayout.LayoutParams(-1, -2))
        fun label(value: String, size: Float, color: Int = ink) {
            card.addView(TextView(this).apply {
                text = value; textSize = size; setTextColor(color); typeface = font
                gravity = Gravity.CENTER; setPadding(0, dp(8), 0, dp(8))
            })
        }
        label("REMINDER ALARM", 12f, clay)
        label(java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault()).format(java.util.Date()), 38f)
        label(row.getString("title"), 24f)
        label("Snooze or Done stops the ringing", 14f, muted)
        fun button(value: String, primary: Boolean, action: () -> Unit) {
            card.addView(Button(this).apply {
                text = value; textSize = 15f; typeface = font; isAllCaps = false
                minHeight = dp(54); minimumHeight = dp(54)
                setPadding(dp(16), dp(12), dp(16), dp(12))
                setTextColor(if (primary) (if (dark) Color.parseColor("#16110D") else Color.WHITE) else ink)
                background = RippleDrawable(ColorStateList.valueOf(edge),
                    surface(if (primary) clay else Color.parseColor(if (dark) "#12FFFFFF" else "#80FFFFFF"), 16), null)
                setOnClickListener { performHapticFeedback(android.view.HapticFeedbackConstants.KEYBOARD_TAP); action() }
            }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(12) })
        }
        fun act(action: String) {
            if (AlarmStore.act(this@ReminderAlarmActivity, alarmId, action)) finish()
            else Toast.makeText(this@ReminderAlarmActivity, "Could not finish. Check alarm access and retry.", Toast.LENGTH_LONG).show()
        }
        button("Done", true) { act("done") }
        button("Snooze 10 minutes", false) { act("snooze") }
        card.addView(TextView(this).apply {
            text = "Open Reminders"; textSize = 14f; typeface = font; setTextColor(clay)
            gravity = Gravity.CENTER; minHeight = dp(48); setPadding(dp(8), dp(16), dp(8), 0)
            isFocusable = true; isClickable = true
            setOnClickListener {
                startActivity(Intent(this@ReminderAlarmActivity, MainActivity::class.java)
                    .putExtra("ascent_route", "/reminders")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                finish()
            }
        })
        setContentView(ScrollView(this).apply { isFillViewport = true; addView(layout) })
        layout.setOnApplyWindowInsetsListener { view, insets ->
            @Suppress("DEPRECATION")
            view.setPadding(dp(24) + insets.systemWindowInsetLeft, dp(32) + insets.systemWindowInsetTop,
                dp(24) + insets.systemWindowInsetRight, dp(32) + insets.systemWindowInsetBottom)
            insets
        }
        layout.requestApplyInsets()
        if (Build.VERSION.SDK_INT >= 30) {
            val mask = android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(if (dark) 0 else mask, mask)
        } else {
            @Suppress("DEPRECATION")
            val mask = android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or
                (if (Build.VERSION.SDK_INT >= 26) android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR else 0)
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = if (dark) window.decorView.systemUiVisibility and mask.inv()
                else window.decorView.systemUiVisibility or mask
        }
    }
}
