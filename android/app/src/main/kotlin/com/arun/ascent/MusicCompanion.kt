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
    private var lastPackage: String? = null
    private var lastTitle: String? = null
    private var lastArtist: String? = null
    private var lastSource: String? = null

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

    private fun extractTitle(metadata: MediaMetadata?): String? {
        if (metadata == null) return null
        return metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: metadata.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            ?: metadata.description?.title?.toString()
    }

    private fun extractArtist(metadata: MediaMetadata?): String? {
        if (metadata == null) return null
        return metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
            ?: metadata.getString(MediaMetadata.METADATA_KEY_AUTHOR)
            ?: metadata.description?.subtitle?.toString()
    }

    fun status(context: Context): Map<String, Any?> {
        if (!allowed(context)) {
            lastPackage = null
            lastTitle = null
            lastArtist = null
            lastSource = null
            return mapOf("access" to false)
        }
        val allSessions = sessions(context)

        // 1. Prioritize playing sessions with real title metadata
        var controller = allSessions.firstOrNull {
            it.playbackState?.state == PlaybackState.STATE_PLAYING && extractTitle(it.metadata) != null
        }

        // 2. If no playing session, prioritize our last known active package session
        if (controller == null && lastPackage != null) {
            controller = allSessions.firstOrNull { it.packageName == lastPackage }
        }

        // 3. Fallback to any session that has title metadata
        if (controller == null) {
            controller = allSessions.firstOrNull { extractTitle(it.metadata) != null }
        }

        if (controller != null) {
            val metadata = controller.metadata
            val state = controller.playbackState
            val actions = state?.actions ?: 0L
            val playing = state?.state == PlaybackState.STATE_PLAYING
            val title = extractTitle(metadata) ?: (if (controller.packageName == lastPackage) lastTitle else null)
            val artist = extractArtist(metadata) ?: (if (controller.packageName == lastPackage) lastArtist else null)
            val label = try {
                context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(controller.packageName, 0)).toString()
            } catch (_: Exception) { "Media player" }

            if (title != null) {
                lastPackage = controller.packageName
                lastTitle = title
                lastArtist = artist
                lastSource = label

                return mapOf(
                    "access" to true,
                    "package" to controller.packageName,
                    "source" to label,
                    "title" to title,
                    "artist" to artist,
                    "playing" to playing,
                    "toggle" to true,
                    "next" to (actions and PlaybackState.ACTION_SKIP_TO_NEXT != 0L || actions == 0L)
                )
            }
        }

        // 4. If momentarily unlisted when paused, keep the cached track active in paused state
        if (lastTitle != null && lastPackage != null) {
            return mapOf(
                "access" to true,
                "package" to lastPackage,
                "source" to (lastSource ?: "Media player"),
                "title" to lastTitle,
                "artist" to lastArtist,
                "playing" to false,
                "toggle" to true,
                "next" to true
            )
        }

        return mapOf("access" to true)
    }

    fun control(context: Context, packageName: String?, action: String?): Boolean {
        val targetPkg = packageName ?: lastPackage
        val controller = sessions(context).firstOrNull { it.packageName == targetPkg }
            ?: sessions(context).firstOrNull() ?: return false
        val state = controller.playbackState
        val playing = state?.state == PlaybackState.STATE_PLAYING
        when(action) {
            "toggle" -> if (playing) controller.transportControls.pause() else controller.transportControls.play()
            "next" -> controller.transportControls.skipToNext()
            "play" -> controller.transportControls.play()
            "pause" -> controller.transportControls.pause()
            else -> return false
        }
        return true
    }
}
