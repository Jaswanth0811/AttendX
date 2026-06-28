package com.attendx.app.ui.screens.setup

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import javax.inject.Inject

@HiltViewModel
class DailySetupViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    val lastPromptedDate: StateFlow<String> = settingsRepository.lastPromptedDate
        .stateIn(viewModelScope, SharingStarted.Eagerly, "")

    val collegeStartTimeMinutes = settingsRepository.collegeStartTimeMinutes
    val collegeEndTimeMinutes = settingsRepository.collegeEndTimeMinutes
    val periodDurationMinutes = settingsRepository.periodDurationMinutes
    val lunchBreakDurationMinutes = settingsRepository.lunchBreakDurationMinutes
    val lunchPeriodIndex = settingsRepository.lunchPeriodIndex
    val periodsPerDayString = settingsRepository.periodsPerDayString

    fun getCurrentDateString(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    fun markPromptAsShown() {
        settingsRepository.setLastPromptedDate(getCurrentDateString())
    }
}
