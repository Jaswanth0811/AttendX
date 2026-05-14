package com.attendx.app.ui.screens.analytics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.repository.AttendanceRepository
import com.attendx.app.data.repository.SettingsRepository
import com.attendx.app.ui.util.calculateSafeBunks
import com.attendx.app.ui.util.calculateClassesNeeded
import com.attendx.app.data.repository.SubjectRepository
import com.attendx.app.ui.util.calculateAttendancePercentage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SubjectStat(
    val subject: Subject, val present: Int, val total: Int, val percentage: Float,
    val safeBunks: Int, val neededClasses: Int
)

data class AnalyticsUiState(
    val overallPresent: Int = 0,
    val overallTotal: Int = 0,
    val overallAbsent: Int = 0,
    val presentDays: Int = 0,
    val absentDays: Int = 0,
    val totalDays: Int = 0,
    val targetPercentage: Float = 75f,
    val overallPercentage: Float = 0f,
    val subjectStats: List<SubjectStat> = emptyList(),
    val isLoading: Boolean = true
)

@HiltViewModel
class AnalyticsViewModel @Inject constructor(
    private val attendanceRepository: AttendanceRepository,
    private val subjectRepository: SubjectRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(AnalyticsUiState())
    val uiState: StateFlow<AnalyticsUiState> = _uiState.asStateFlow()

    init { loadAnalytics() }

    private fun loadAnalytics() {
        viewModelScope.launch {
            combine(
                subjectRepository.getAllSubjects(),
                attendanceRepository.getTotalPresentCount(),
                attendanceRepository.getTotalClassCount(),
                attendanceRepository.getTotalAbsentCount(),
                settingsRepository.targetPercentage
            ) { subjects, present, total, absent, target ->
                Triple(subjects, Triple(present, total, absent), target)
            }.combine(
                combine(
                    attendanceRepository.getPresentDates(),
                    attendanceRepository.getAbsentDates(),
                    attendanceRepository.getAllDatesWithRecords()
                ) { p, a, t -> Triple(p, a, t) }
            ) { (subjects, counts, target), (pDates, aDates, tDates) ->
                val (present, total, absent) = counts
                AnalyticsUiState(
                    overallPresent = present,
                    overallTotal = total,
                    overallAbsent = absent,
                    presentDays = pDates.size,
                    absentDays = aDates.size,
                    totalDays = tDates.size,
                    targetPercentage = target,
                    overallPercentage = calculateAttendancePercentage(present, total),
                    subjectStats = _uiState.value.subjectStats,
                    isLoading = false
                ) to Pair(subjects, target)
            }.collect { (state, data) ->
                _uiState.value = state
                loadSubjectStats(data.first, data.second)
            }
        }
    }

    private fun loadSubjectStats(subjects: List<Subject>, targetPercent: Float) {
        viewModelScope.launch {
            val stats = subjects.map { sub ->
                var p = 0; var t = 0
                val j1 = launch {
                    attendanceRepository.getPresentCountForSubject(sub.id)
                        .collect { p = it; return@collect }
                }
                val j2 = launch {
                    attendanceRepository.getTotalCountForSubject(sub.id)
                        .collect { t = it; return@collect }
                }
                j1.join(); j2.join()
                SubjectStat(sub, p, t, calculateAttendancePercentage(p, t),
                    calculateSafeBunks(p, t, targetPercent),
                    calculateClassesNeeded(p, t, targetPercent))
            }
            _uiState.value = _uiState.value.copy(subjectStats = stats)
        }
    }
}
