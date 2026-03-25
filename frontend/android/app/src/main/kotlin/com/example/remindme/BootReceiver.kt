package com.example.remindme

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receives BOOT_COMPLETED (and the HTC/ASUS/Xiaomi quick-boot variants) and
 * brings the main Flutter activity back into the foreground.
 *
 * Why this is needed:
 *   Android's AlarmManager clears all pending alarms on device reboot.
 *   The flutter_local_notifications plugin already ships its own
 *   ScheduledNotificationBootReceiver that re-registers the alarms it stored
 *   internally, but that only covers alarms that were *still in the plugin's
 *   internal store*.  This companion receiver starts MainActivity so that
 *   Flutter's rescheduleAllPendingReminders() can re-sync everything from the
 *   local SQLite DB, handling reminders that may have been added/changed after
 *   the last plugin persist cycle.
 *
 * On Android 10+ apps cannot silently launch activities after reboot without
 * a visible foreground service or notification.  We post a high-priority
 * silent notification that, when the user taps it (or if the device permits
 * background launches), opens the app so alarms are restored.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+: cannot start an activity from background.
            // The flutter_local_notifications ScheduledNotificationBootReceiver
            // (auto-merged from the plugin manifest) will restore the plugin-
            // scheduled alarms.  When the user next opens the app the full
            // Dart-side reschedule will run.
            return
        }

        // Android 9 and below: launch the app so rescheduleAllPendingReminders
        // runs in Dart and restores all alarms from the local DB.
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("source", "boot_receiver")
        }
        try {
            context.startActivity(launchIntent)
        } catch (_: Exception) {
            // Ignore — the plugin-level receiver is still active.
        }
    }
}
