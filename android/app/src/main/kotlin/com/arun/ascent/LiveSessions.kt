package com.arun.ascent

import android.app.*
import android.content.*
import android.graphics.Color
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

internal object LiveSessions {
    const val CHANNEL = "ascent_live_players_v2"
    var bridge: MethodChannel? = null
    val states = linkedMapOf<String, JSONObject>()
    private val sessions = mutableMapOf<String, MediaSession>()
    private fun dispatch(route: String, action: String) { android.util.Log.i("AscentLive", "control $route $action bridge=${bridge != null}"); Handler(Looper.getMainLooper()).post { bridge?.invokeMethod("action", mapOf("route" to route, "action" to action)) } }
    fun id(route: String) = if (route == "/learning") 888800 else 888803
    fun clock(seconds: Int): String {
        val n = maxOf(0, seconds)
        return if (n >= 3600) "%d:%02d:%02d".format(n / 3600, (n % 3600) / 60, n % 60) else "%02d:%02d".format(n / 60, n % 60)
    }
    fun currentElapsed(row: JSONObject): Int = row.optInt("elapsed") + if (row.optBoolean("paused")) 0 else maxOf(0L, (SystemClock.elapsedRealtime() - row.optLong("anchor", SystemClock.elapsedRealtime())) / 1000).toInt()
    fun refreshFocusClock() {
        val row = states["/focus"] ?: return
        val session = sessions["/focus"] ?: return
        val paused = row.optBoolean("paused")
        val elapsed = currentElapsed(row)
        session.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, row.getString("title")).putString(MediaMetadata.METADATA_KEY_ARTIST, "${if (paused) "Paused · " else ""}${clock(elapsed)} elapsed · ${row.optString("body")}").build())
        session.setPlaybackState(PlaybackState.Builder().setState(if (paused) PlaybackState.STATE_PAUSED else PlaybackState.STATE_PLAYING, elapsed * 1000L, if (paused) 0f else 1f).setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE).build())
    }
    fun notification(c: Context, row: JSONObject): Notification {
        if (Build.VERSION.SDK_INT >= 26) c.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL, "Live Learning and Focus", NotificationManager.IMPORTANCE_LOW).apply { setSound(null, null); enableVibration(false) })
        val route = row.getString("route"); val nid = id(route)
        val paused = row.getBoolean("paused"); val elapsed = row.optInt("elapsed"); val total = row.optInt("total")
        val open = PendingIntent.getActivity(c, nid, Intent(c, MainActivity::class.java).putExtra("ascent_route", route).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val action = if (paused) "action_resume" else "action_pause"
        val control = if (paused) PendingIntent.getActivity(c, nid + 20, Intent(c, MainActivity::class.java).putExtra("ascent_route", route).putExtra("ascent_action", action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
          else PendingIntent.getBroadcast(c, nid, Intent(c, LiveSessionActionReceiver::class.java).putExtra("route", route).putExtra("action", action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val session = sessions.getOrPut(route) {
            MediaSession(c.applicationContext, "Ascent $route").apply {
                setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
                setCallback(object : MediaSession.Callback() {
                    override fun onPlay() { dispatch(route, "action_resume") }
                    override fun onPause() { dispatch(route, "action_pause") }
                    override fun onSeekTo(pos: Long) { if (route == "/learning") Handler(Looper.getMainLooper()).post { bridge?.invokeMethod("seek", mapOf("route" to route, "seconds" to (pos / 1000).toInt())) } }
                }, Handler(Looper.getMainLooper()))
            }
        }
        session.setSessionActivity(open)
        session.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, row.getString("title")).putString(MediaMetadata.METADATA_KEY_ARTIST, row.optString("body")).putLong(MediaMetadata.METADATA_KEY_DURATION, total * 1000L).build())
        session.setPlaybackState(PlaybackState.Builder().setState(if (paused) PlaybackState.STATE_PAUSED else PlaybackState.STATE_PLAYING, elapsed * 1000L, if (paused) 0f else 1f).setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or (if (route == "/learning") PlaybackState.ACTION_SEEK_TO else 0L)).build())
        session.isActive = true
        if (route == "/focus") refreshFocusClock()
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        val status = if (paused) "Paused · ${clock(elapsed)} elapsed" else if (total > 0) "${clock(elapsed)} / ${clock(total)} · remaining timer" else "${clock(elapsed)} elapsed"
        builder.setSmallIcon(R.drawable.ic_notification_ascent).setContentTitle(row.getString("title")).setContentText("$status · ${row.optString("body")}")
            .setSubText(if (route == "/learning") "Learning" else "Focus")
            .setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0))
            .setCategory(Notification.CATEGORY_TRANSPORT).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setColor(Color.rgb(169, 82, 53)).setOngoing(!paused).setAutoCancel(false).setOnlyAlertOnce(true)
            .setContentIntent(open).setUsesChronometer(!paused).setShowWhen(!paused)
            .setWhen(if (total > 0 && !paused) System.currentTimeMillis() + maxOf(0, total - elapsed) * 1000L else System.currentTimeMillis() - elapsed * 1000L)
            .addAction(Notification.Action.Builder(android.graphics.drawable.Icon.createWithResource(c, if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause), if (paused) "Resume" else "Pause", control).build())
        if (Build.VERSION.SDK_INT >= 24) builder.setChronometerCountDown(total > 0 && !paused)
        return builder.build()
    }
    fun update(c: Context, row: JSONObject) {
        val route = row.getString("route")
        require(route == "/focus" || route == "/learning")
        row.put("anchor", SystemClock.elapsedRealtime())
        states[route] = row
        val active = states.values.any { !it.optBoolean("paused") }
        if (active) {
            val intent = Intent(c, LiveSessionService::class.java)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
        } else {
            c.getSystemService(NotificationManager::class.java).notify(id(route), notification(c, row))
            if (LiveSessionService.running) c.startService(Intent(c, LiveSessionService::class.java))
        }
    }
    fun cancel(c: Context, route: String) {
        states.remove(route)
        sessions.remove(route)?.release()
        c.getSystemService(NotificationManager::class.java).cancel(id(route))
        if (LiveSessionService.running) c.startService(Intent(c, LiveSessionService::class.java))
    }
}
class LiveSessionActionReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        val route = i.getStringExtra("route") ?: return
        val action = i.getStringExtra("action") ?: return
        Handler(Looper.getMainLooper()).post {
            LiveSessions.bridge?.invokeMethod("action", mapOf("route" to route, "action" to action))
        }
    }
}
class LiveSessionService : Service() {
    companion object { var running = false }
    override fun onBind(intent: Intent?) = null
    private val clockHandler = Handler(Looper.getMainLooper())
    private val clockTick = object : Runnable {
        override fun run() { LiveSessions.refreshFocusClock(); clockHandler.postDelayed(this, 1000) }
    }
    override fun onCreate() { super.onCreate(); running = true; clockHandler.post(clockTick) }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val active = LiveSessions.states.values.firstOrNull { !it.optBoolean("paused") }
        if (active == null) {
            stopForeground(STOP_FOREGROUND_DETACH)
            for ((route, row) in LiveSessions.states) getSystemService(NotificationManager::class.java).notify(LiveSessions.id(route), LiveSessions.notification(this, row))
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(LiveSessions.id(active.getString("route")), LiveSessions.notification(this, active))
        for ((route, row) in LiveSessions.states) getSystemService(NotificationManager::class.java).notify(LiveSessions.id(route), LiveSessions.notification(this, row))
        return START_NOT_STICKY
    }
    override fun onDestroy() { clockHandler.removeCallbacks(clockTick); running = false; super.onDestroy() }
}
