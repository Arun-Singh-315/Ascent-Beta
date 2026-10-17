package com.arun.ascent

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.provider.Settings
import android.service.notification.NotificationListenerService

// Required only to authorize media-session access. Never reads notification contents.
class MusicNotificationListener : NotificationListenerService()

object MusicCompanion {
    private fun allowed(context: Context): Boolean {
        val component = ComponentName(context, MusicNotificationListener::class.java)
        return Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            ?.split(":")?.any { ComponentName.unflattenFromString(it) == component } == true
    }
    private fun sessions(context: Context): List<MediaController> {
        if (!allowed(context)) return emptyList()
        return (context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager)
            .getActiveSessions(ComponentName(context, MusicNotificationListener::class.java))
            .filter { it.packageName != context.packageName }
    }
    fun status(context: Context): Map<String, Any?> {
        if (!allowed(context)) return mapOf("access" to false)
        val controller = sessions(context).sortedByDescending {
            it.playbackState?.state == PlaybackState.STATE_PLAYING
        }.firstOrNull { it.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) != null }
            ?: return mapOf("access" to true)
        val metadata = controller.metadata
        val state = controller.playbackState
        val actions = state?.actions ?: 0L
        val playing = state?.state == PlaybackState.STATE_PLAYING
        val label = try { context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(controller.packageName, 0)).toString() } catch (_: Exception) { "Media player" }
        return mapOf("access" to true, "package" to controller.packageName,
            "source" to label, "title" to metadata?.getString(MediaMetadata.METADATA_KEY_TITLE),
            "artist" to metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST),
            "playing" to playing,
            "toggle" to (actions and (PlaybackState.ACTION_PLAY_PAUSE or if (playing) PlaybackState.ACTION_PAUSE else PlaybackState.ACTION_PLAY) != 0L),
            "next" to (actions and PlaybackState.ACTION_SKIP_TO_NEXT != 0L))
    }
    fun control(context: Context, packageName: String?, action: String?): Boolean {
        val controller = sessions(context).firstOrNull { it.packageName == packageName } ?: return false
        val state = controller.playbackState ?: return false
        val playing = state.state == PlaybackState.STATE_PLAYING
        val required = when(action) {
            "toggle" -> PlaybackState.ACTION_PLAY_PAUSE or if (playing) PlaybackState.ACTION_PAUSE else PlaybackState.ACTION_PLAY
            "next" -> PlaybackState.ACTION_SKIP_TO_NEXT
            else -> return false
        }
        if (state.actions and required == 0L) return false
        when(action) {
            "toggle" -> if (playing) controller.transportControls.pause() else controller.transportControls.play()
            "next" -> controller.transportControls.skipToNext()
        }
        return true
    }
}
