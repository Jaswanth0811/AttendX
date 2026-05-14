package com.attendx.app.ui.util

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object DateUtils {
    private val dateFormat = SimpleDateFormat("dd MMM yyyy", Locale.getDefault())
    private val shortDateFormat = SimpleDateFormat("dd MMM", Locale.getDefault())
    private val dayFormat = SimpleDateFormat("EEEE", Locale.getDefault())
    private val monthYearFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
    private val timeFormat = SimpleDateFormat("hh:mm a", Locale.getDefault())

    fun formatDate(millis: Long): String = dateFormat.format(Date(millis))

    fun formatShortDate(millis: Long): String = shortDateFormat.format(Date(millis))

    fun formatDay(millis: Long): String = dayFormat.format(Date(millis))

    fun formatMonthYear(millis: Long): String = monthYearFormat.format(Date(millis))

    fun formatTime(time: String): String {
        return try {
            val parts = time.split(":")
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, parts[0].toInt())
                set(Calendar.MINUTE, parts[1].toInt())
            }
            timeFormat.format(cal.time)
        } catch (e: Exception) {
            time
        }
    }

    fun getTodayStartMillis(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    fun getTodayDayOfWeek(): Int {
        val cal = Calendar.getInstance()
        // Convert: Calendar.MONDAY=2 -> 1, Calendar.TUESDAY=3 -> 2, etc.
        return when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7
            else -> 1
        }
    }

    fun dayOfWeekName(day: Int): String {
        return when (day) {
            1 -> "Monday"
            2 -> "Tuesday"
            3 -> "Wednesday"
            4 -> "Thursday"
            5 -> "Friday"
            6 -> "Saturday"
            7 -> "Sunday"
            else -> "Unknown"
        }
    }

    fun dayOfWeekShort(day: Int): String {
        return when (day) {
            1 -> "Mon"
            2 -> "Tue"
            3 -> "Wed"
            4 -> "Thu"
            5 -> "Fri"
            6 -> "Sat"
            7 -> "Sun"
            else -> "?"
        }
    }

    fun getDateMillis(year: Int, month: Int, dayOfMonth: Int): Long {
        return Calendar.getInstance().apply {
            set(year, month, dayOfMonth, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    fun getMonthStartEnd(year: Int, month: Int): Pair<Long, Long> {
        val start = Calendar.getInstance().apply {
            set(year, month, 1, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val end = Calendar.getInstance().apply {
            set(year, month, getActualMaximum(Calendar.DAY_OF_MONTH), 23, 59, 59)
            set(Calendar.MILLISECOND, 999)
        }.timeInMillis

        return start to end
    }

    fun getDaysInMonth(year: Int, month: Int): Int {
        return Calendar.getInstance().apply {
            set(year, month, 1)
        }.getActualMaximum(Calendar.DAY_OF_MONTH)
    }

    fun getFirstDayOfMonth(year: Int, month: Int): Int {
        val cal = Calendar.getInstance().apply {
            set(year, month, 1)
        }
        return when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 0
            Calendar.TUESDAY -> 1
            Calendar.WEDNESDAY -> 2
            Calendar.THURSDAY -> 3
            Calendar.FRIDAY -> 4
            Calendar.SATURDAY -> 5
            Calendar.SUNDAY -> 6
            else -> 0
        }
    }

    fun calculateStreak(presentDates: List<Long>): Int {
        if (presentDates.isEmpty()) return 0

        val sortedDates = presentDates.sorted()
        val today = getTodayStartMillis()
        var streak = 0
        var currentDate = today

        for (i in sortedDates.reversed()) {
            val cal = Calendar.getInstance().apply {
                timeInMillis = i
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            if (cal.timeInMillis == currentDate || cal.timeInMillis == currentDate - 86400000L) {
                streak++
                currentDate = cal.timeInMillis - 86400000L
            } else if (cal.timeInMillis < currentDate) {
                break
            }
        }
        return streak
    }
}
