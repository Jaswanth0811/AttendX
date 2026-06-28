package com.attendx.app.util

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.attendx.app.R
import java.util.Calendar

object PeriodNotificationManager {
    const val CHANNEL_ID = "period_notifications"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Period Notifications"
            val descriptionText = "Notifications for when a college period ends"
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun scheduleDailyAlarms(
        context: Context,
        startTimeMins: Int,
        periodDurationMins: Int,
        lunchDurationMins: Int,
        lunchPeriodIdx: Int,
        totalPeriodsToday: Int
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Cancel existing alarms if we have a robust way, but for now we just overwrite with the exact same request codes
        // Request codes will be 1 to totalPeriodsToday

        var currentMins = startTimeMins

        for (i in 1..totalPeriodsToday) {
            if (i == lunchPeriodIdx) {
                currentMins += lunchDurationMins
            } else {
                currentMins += periodDurationMins
                // Schedule alarm at currentMins for the end of period 'i' (excluding lunch which is not a class)
                val cal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, currentMins / 60)
                    set(Calendar.MINUTE, currentMins % 60)
                    set(Calendar.SECOND, 0)
                }

                // If time is already past today, we don't schedule it. 
                // Or we can schedule it for the next day, but the daily prompt handles tomorrow.
                if (cal.timeInMillis > System.currentTimeMillis()) {
                    val intent = Intent(context, PeriodNotificationReceiver::class.java).apply {
                        putExtra("PERIOD_NUM", i)
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        i,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    
                    try {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            cal.timeInMillis,
                            pendingIntent
                        )
                    } catch (e: SecurityException) {
                        // Permission not granted for exact alarm
                    }
                }
            }
        }
    }
}

class PeriodNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val periodNum = intent.getIntExtra("PERIOD_NUM", 1)

        val builder = NotificationCompat.Builder(context, PeriodNotificationManager.CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Period $periodNum Ended")
            .setContentText("Your period $periodNum has just ended.")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(periodNum, builder.build())
    }
}
