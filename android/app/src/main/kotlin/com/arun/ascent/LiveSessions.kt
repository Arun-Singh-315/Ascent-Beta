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

    private fun generateArtBitmap(c: Context, isLecture: Boolean): android.graphics.Bitmap {
        val size = 256
        val bmp = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bmp)

        // Gradient background matching Ascent palette
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        val shader = android.graphics.LinearGradient(
            0f, 0f, size.toFloat(), size.toFloat(),
            if (isLecture) intArrayOf(Color.rgb(18, 28, 48), Color.rgb(32, 78, 138), Color.rgb(46, 117, 182))
            else intArrayOf(Color.rgb(40, 22, 14), Color.rgb(120, 56, 34), Color.rgb(184, 86, 52)),
            null, android.graphics.Shader.TileMode.CLAMP
        )
        paint.shader = shader
        val rect = android.graphics.RectF(0f, 0f, size.toFloat(), size.toFloat())
        canvas.drawRoundRect(rect, 48f, 48f, paint)

        // Subtle glowing border
        paint.shader = null
        paint.style = android.graphics.Paint.Style.STROKE
        paint.strokeWidth = 3f
        paint.color = if (isLecture) Color.argb(100, 100, 175, 255) else Color.argb(110, 255, 145, 95)
        val insetRect = android.graphics.RectF(2f, 2f, (size - 2).toFloat(), (size - 2).toFloat())
        canvas.drawRoundRect(insetRect, 48f, 48f, paint)

        // Draw app emblem inside
        try {
            val icon = c.packageManager.getApplicationIcon(c.packageName)
            val iconSize = (size * 0.52f).toInt()
            val offset = (size - iconSize) / 2
            icon.setBounds(offset, offset, offset + iconSize, offset + iconSize)
            icon.draw(canvas)
        } catch (_: Exception) {
            val glyphPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = 64f
                textAlign = android.graphics.Paint.Align.CENTER
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
            canvas.drawText(if (isLecture) "LEARN" else "FOCUS", size / 2f, size * 0.58f, glyphPaint)
        }
        return bmp
    }

    fun refreshFocusClock() {
        val row = states["/focus"] ?: return
        val session = sessions["/focus"] ?: return
        val paused = row.optBoolean("paused")
        val elapsed = currentElapsed(row)
        val total = row.optInt("total")
        session.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, row.getString("title"))
                .putString(MediaMetadata.METADATA_KEY_ARTIST, "${if (paused) "Paused · " else ""}${clock(elapsed)} elapsed · ${row.optString("body")}")
                .putString(MediaMetadata.METADATA_KEY_ALBUM, "Deep Work")
                .putLong(MediaMetadata.METADATA_KEY_DURATION, total * 1000L)
                .build()
        )
        session.setPlaybackState(
            PlaybackState.Builder()
                .setState(if (paused) PlaybackState.STATE_PAUSED else PlaybackState.STATE_PLAYING, elapsed * 1000L, if (paused) 0f else 1f)
                .setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_REWIND or PlaybackState.ACTION_FAST_FORWARD or PlaybackState.ACTION_STOP)
                .build()
        )
    }

    fun notification(c: Context, row: JSONObject): Notification {
        if (Build.VERSION.SDK_INT >= 26) c.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Live Learning and Focus", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null)
                enableVibration(false)
            }
        )
        val route = row.getString("route"); val nid = id(route)
        val isLecture = route == "/learning"
        val paused = row.getBoolean("paused"); val elapsed = row.optInt("elapsed"); val total = row.optInt("total")
        val open = PendingIntent.getActivity(c, nid, Intent(c, MainActivity::class.java).putExtra("ascent_route", route).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val action = if (paused) "action_resume" else "action_pause"

        val art = generateArtBitmap(c, isLecture)

        val session = sessions.getOrPut(route) {
            MediaSession(c.applicationContext, "Ascent $route").apply {
                // DO NOT set FLAG_HANDLES_MEDIA_BUTTONS! Flags set to 0 ensures Android does NOT hijack
                // hardware media button priority from Spotify/YouTube Music, avoiding unwanted pause events.
                setFlags(0)
                setCallback(object : MediaSession.Callback() {
                    override fun onPlay() { dispatch(route, "action_resume") }
                    override fun onPause() { dispatch(route, "action_pause") }
                    override fun onRewind() { dispatch(route, "action_rewind") }
                    override fun onFastForward() { dispatch(route, "action_forward") }
                    override fun onStop() { dispatch(route, "action_done") }
                    override fun onSeekTo(pos: Long) {
                        if (route == "/learning") Handler(Looper.getMainLooper()).post {
                            bridge?.invokeMethod("seek", mapOf("route" to route, "seconds" to (pos / 1000).toInt()))
                        }
                    }
                }, Handler(Looper.getMainLooper()))
            }
        }
        session.setSessionActivity(open)
        session.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, row.getString("title"))
                .putString(
                    MediaMetadata.METADATA_KEY_ARTIST,
                    if (isLecture) "Ascent Lecture · ${row.optString("body")}" else "Ascent Focus · ${row.optString("body")}"
                )
                .putString(MediaMetadata.METADATA_KEY_ALBUM, if (isLecture) "Study Deck" else "Deep Work")
                .putString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE, row.optString("body"))
                .putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, art)
                .putBitmap(MediaMetadata.METADATA_KEY_ART, art)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, total * 1000L)
                .build()
        )
        session.setPlaybackState(
            PlaybackState.Builder()
                .setState(if (paused) PlaybackState.STATE_PAUSED else PlaybackState.STATE_PLAYING, elapsed * 1000L, if (paused) 0f else 1f)
                .setActions(
                    PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or
                    PlaybackState.ACTION_REWIND or PlaybackState.ACTION_FAST_FORWARD or PlaybackState.ACTION_STOP or
                    (if (isLecture) PlaybackState.ACTION_SEEK_TO else 0L)
                ).build()
        )
        session.isActive = true
        if (route == "/focus") refreshFocusClock()

        // Rich interactive player actions: Rewind -10s, Play/Pause, Forward +30s, and Done
        val rewindIntent = PendingIntent.getBroadcast(
            c, nid + 1,
            Intent(c, LiveSessionActionReceiver::class.java).putExtra("route", route).putExtra("action", "action_rewind"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val rewindAction = Notification.Action.Builder(
            android.graphics.drawable.Icon.createWithResource(c, android.R.drawable.ic_media_rew),
            "-10s", rewindIntent
        ).build()

        val playPauseIntent = if (paused) {
            PendingIntent.getActivity(
                c, nid + 2,
                Intent(c, MainActivity::class.java).putExtra("ascent_route", route).putExtra("ascent_action", action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getBroadcast(
                c, nid + 2,
                Intent(c, LiveSessionActionReceiver::class.java).putExtra("route", route).putExtra("action", action),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val playPauseAction = Notification.Action.Builder(
            android.graphics.drawable.Icon.createWithResource(c, if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause),
            if (paused) "Resume" else "Pause", playPauseIntent
        ).build()

        val forwardIntent = PendingIntent.getBroadcast(
            c, nid + 3,
            Intent(c, LiveSessionActionReceiver::class.java).putExtra("route", route).putExtra("action", "action_forward"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val forwardAction = Notification.Action.Builder(
            android.graphics.drawable.Icon.createWithResource(c, android.R.drawable.ic_media_ff),
            "+30s", forwardIntent
        ).build()

        val doneIntent = PendingIntent.getBroadcast(
            c, nid + 4,
            Intent(c, LiveSessionActionReceiver::class.java).putExtra("route", route).putExtra("action", "action_done"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val doneAction = Notification.Action.Builder(
            android.graphics.drawable.Icon.createWithResource(c, android.R.drawable.ic_menu_close_clear_cancel),
            "Done", doneIntent
        ).build()

        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        val status = if (paused) "Paused · ${clock(elapsed)} elapsed" else if (total > 0) "${clock(elapsed)} / ${clock(total)} remaining" else "${clock(elapsed)} elapsed"

        builder.setSmallIcon(R.drawable.ic_notification_ascent)
            .setLargeIcon(art)
            .setContentTitle(row.getString("title"))
            .setContentText("$status · ${row.optString("body")}")
            .setSubText(if (isLecture) "Ascent Lecture" else "Ascent Focus")
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(if (isLecture) Color.rgb(38, 92, 150) else Color.rgb(169, 82, 53))
            .setOngoing(!paused)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .setUsesChronometer(!paused)
            .setShowWhen(!paused)
            .addAction(rewindAction)
            .addAction(playPauseAction)
            .addAction(forwardAction)
            .addAction(doneAction)

        if (total > 0) {
            builder.setProgress(total, elapsed, false)
            if (!paused) {
                builder.setWhen(System.currentTimeMillis() + maxOf(0, total - elapsed) * 1000L)
                if (Build.VERSION.SDK_INT >= 24) builder.setChronometerCountDown(true)
            }
        } else if (!paused) {
            builder.setWhen(System.currentTimeMillis() - elapsed * 1000L)
            if (Build.VERSION.SDK_INT >= 24) builder.setChronometerCountDown(false)
        }
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
