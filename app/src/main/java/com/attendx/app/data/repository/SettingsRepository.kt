package com.attendx.app.data.repository

import android.content.Context
import android.content.SharedPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val prefs: SharedPreferences = context.getSharedPreferences("attendx_settings", Context.MODE_PRIVATE)
    
    private val _targetPercentage = MutableStateFlow(prefs.getFloat("target_percentage", 75f))
    val targetPercentage: StateFlow<Float> = _targetPercentage.asStateFlow()

    // Timetable Settings
    private val _collegeStartTimeMinutes = MutableStateFlow(prefs.getInt("college_start_time", 540)) // 9:00 AM
    val collegeStartTimeMinutes: StateFlow<Int> = _collegeStartTimeMinutes.asStateFlow()

    private val _collegeEndTimeMinutes = MutableStateFlow(prefs.getInt("college_end_time", 960)) // 4:00 PM
    val collegeEndTimeMinutes: StateFlow<Int> = _collegeEndTimeMinutes.asStateFlow()

    private val _periodDurationMinutes = MutableStateFlow(prefs.getInt("period_duration", 50))
    val periodDurationMinutes: StateFlow<Int> = _periodDurationMinutes.asStateFlow()

    private val _lunchBreakDurationMinutes = MutableStateFlow(prefs.getInt("lunch_duration", 45))
    val lunchBreakDurationMinutes: StateFlow<Int> = _lunchBreakDurationMinutes.asStateFlow()

    private val _lunchPeriodIndex = MutableStateFlow(prefs.getInt("lunch_period_index", 4))
    val lunchPeriodIndex: StateFlow<Int> = _lunchPeriodIndex.asStateFlow()

    // Comma separated list of periods per day (Monday to Saturday) e.g., "7,7,7,7,7,4"
    private val _periodsPerDayString = MutableStateFlow(prefs.getString("periods_per_day", "7,7,7,7,7,4") ?: "7,7,7,7,7,4")
    val periodsPerDayString: StateFlow<String> = _periodsPerDayString.asStateFlow()

    private val _lastPromptedDate = MutableStateFlow(prefs.getString("last_prompt_date", "") ?: "")
    val lastPromptedDate: StateFlow<String> = _lastPromptedDate.asStateFlow()

    fun setTargetPercentage(target: Float) {
        prefs.edit().putFloat("target_percentage", target).apply()
        _targetPercentage.value = target
    }

    fun setCollegeStartTimeMinutes(minutes: Int) {
        prefs.edit().putInt("college_start_time", minutes).apply()
        _collegeStartTimeMinutes.value = minutes
    }

    fun setCollegeEndTimeMinutes(minutes: Int) {
        prefs.edit().putInt("college_end_time", minutes).apply()
        _collegeEndTimeMinutes.value = minutes
    }

    fun setPeriodDurationMinutes(minutes: Int) {
        prefs.edit().putInt("period_duration", minutes).apply()
        _periodDurationMinutes.value = minutes
    }

    fun setLunchBreakDurationMinutes(minutes: Int) {
        prefs.edit().putInt("lunch_duration", minutes).apply()
        _lunchBreakDurationMinutes.value = minutes
    }

    fun setLunchPeriodIndex(index: Int) {
        prefs.edit().putInt("lunch_period_index", index).apply()
        _lunchPeriodIndex.value = index
    }

    fun setPeriodsPerDayString(daysString: String) {
        prefs.edit().putString("periods_per_day", daysString).apply()
        _periodsPerDayString.value = daysString
    }

    fun setLastPromptedDate(date: String) {
        prefs.edit().putString("last_prompt_date", date).apply()
        _lastPromptedDate.value = date
    }
}
