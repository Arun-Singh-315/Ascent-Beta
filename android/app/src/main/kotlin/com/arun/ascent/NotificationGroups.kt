package com.arun.ascent

import android.app.*
import android.content.*
import android.net.Uri
import android.os.Build
import org.json.JSONObject

/** Summaries only: the notification plugin remains the authority for dose delivery. */
object NotificationGroups {
    private const val channel = "ascent_group_summaries"
    private val groups = linkedMapOf(
        "ascent.group.medicine" to Triple(-1900000001, "Medicine", "/medicine"),
        "ascent.group.reminders" to Triple(-1900000002, "Reminders", "/reminders"),
        "ascent.group.plans" to Triple(-1900000003, "Plans & check-ins", "/home")
    )
    private fun prefs(c: Context) = c.getSharedPreferences("ascent_notification_groups", Context.MODE_PRIVATE)
    private fun alarmIntent(c: Context, id: Int, attempt: Int = 0) = Intent(c, NotificationGroupReceiver::class.java)
        .setAction("ascent.group.refresh").setData(Uri.parse("ascent://notification-group/$id"))
        .putExtra("id", id).putExtra("attempt", attempt)
    private fun pending(c: Context, id: Int, attempt: Int = 0) = PendingIntent.getBroadcast(c, id, alarmIntent(c, id, attempt), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun schedule(c: Context, id: Int, at: Long, attempt: Int = 0) {
        val whenAt = maxOf(at, System.currentTimeMillis() + 1200)
        prefs(c).edit().putString(id.toString(), JSONObject().put("at", whenAt).put("attempt", attempt).toString()).apply()
        val manager = c.getSystemService(AlarmManager::class.java)
        val pi = pending(c, id, attempt)
        try {
            if (Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenAt, pi)
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenAt, pi)
        } catch (_: SecurityException) { manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenAt, pi) }
    }
    fun cancel(c: Context, id: Int) {
        c.getSystemService(AlarmManager::class.java).cancel(pending(c, id))
        prefs(c).edit().remove(id.toString()).apply()
        refresh(c)
    }
    fun clear(c: Context) {
        for (key in prefs(c).all.keys) key.toIntOrNull()?.let { c.getSystemService(AlarmManager::class.java).cancel(pending(c, it)) }
        prefs(c).edit().clear().apply()
        val manager = c.getSystemService(NotificationManager::class.java)
        groups.values.forEach { manager.cancel(it.first) }
    }
    fun restore(c: Context) {
        for ((key, value) in prefs(c).all) {
            val id = key.toIntOrNull() ?: continue
            val row = runCatching { JSONObject(value as String) }.getOrNull() ?: continue
            if (row.optLong("at") > System.currentTimeMillis() - 86400000L) schedule(c, id, row.optLong("at"), row.optInt("attempt"))
            else prefs(c).edit().remove(key).apply()
        }
        refresh(c)
    }
    fun delivered(c: Context, id: Int, attempt: Int) {
        prefs(c).edit().remove(id.toString()).apply()
        val active = c.getSystemService(NotificationManager::class.java).activeNotifications.any { it.id == id }
        refresh(c)
        // The child may be inexact or delivered after this receiver in the same batch.
        if (!active && attempt < 10) schedule(c, id, System.currentTimeMillis() + if (attempt < 2) 5000L else 60000L, attempt + 1)
    }
    fun refresh(c: Context, removedId: Int? = null) {
        val manager = c.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(channel, "Grouped reminder summaries", NotificationManager.IMPORTANCE_LOW).apply { setSound(null, null); enableVibration(false) })
        val children = manager.activeNotifications.filter { it.id != removedId && it.notification.flags and Notification.FLAG_GROUP_SUMMARY == 0 }
        for ((key, meta) in groups) {
            val rows = children.filter { it.notification.group == key || key == "ascent.group.medicine" && Build.VERSION.SDK_INT >= 26 && it.notification.channelId == "ascent_medicine_reminders" }
            if (rows.isEmpty()) { manager.cancel(meta.first); continue }
            for (row in rows) {
                val deletion = Intent(c, NotificationGroupReceiver::class.java).setAction("ascent.group.dismiss").setData(Uri.parse("ascent://notification-dismiss/${row.id}")).putExtra("id", row.id)
                val pi = PendingIntent.getBroadcast(c, row.id, deletion, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val child = Notification.Builder.recoverBuilder(c, row.notification).setGroup(key).setGroupAlertBehavior(Notification.GROUP_ALERT_CHILDREN).setOnlyAlertOnce(true).setDeleteIntent(pi).build()
                manager.notify(row.tag, row.id, child)
            }
            val open = Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP).putExtra("ascent_route", meta.third)
            val content = PendingIntent.getActivity(c, meta.first, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val inbox = Notification.InboxStyle().setBigContentTitle("${meta.second} · ${rows.size} reminders")
            rows.sortedByDescending { it.postTime }.take(6).forEach { row ->
                inbox.addLine("${row.notification.extras.getCharSequence(Notification.EXTRA_TITLE) ?: "Reminder"} · ${row.notification.extras.getCharSequence(Notification.EXTRA_TEXT) ?: ""}")
            }
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, channel) else Notification.Builder(c)
            manager.notify(meta.first, builder.setSmallIcon(com.arun.ascent.R.drawable.ic_notification_ascent)
                .setContentTitle("${meta.second} · ${rows.size} reminders").setContentText("Expand to see each reminder")
                .setContentIntent(content).setStyle(inbox).setGroup(key).setGroupSummary(true)
                .setGroupAlertBehavior(Notification.GROUP_ALERT_CHILDREN).setOnlyAlertOnce(true).setShowWhen(false).build())
        }
    }
}

class NotificationGroupReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> NotificationGroups.restore(context)
            "ascent.group.dismiss" -> NotificationGroups.refresh(context, intent.getIntExtra("id", 0))
            else -> NotificationGroups.delivered(context, intent.getIntExtra("id", 0), intent.getIntExtra("attempt", 0))
        }
    }
}
