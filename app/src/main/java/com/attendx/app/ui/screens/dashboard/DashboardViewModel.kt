package com.attendx.app.ui.screens.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.local.entity.TimetableSlot
import com.attendx.app.data.repository.AttendanceRepository
import com.attendx.app.data.repository.SubjectRepository
import com.attendx.app.data.repository.TimetableRepository
import com.attendx.app.ui.util.DateUtils
import com.attendx.app.ui.util.calculateAttendancePercentage
import com.attendx.app.ui.util.calculateSafeBunks
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject
import com.attendx.app.data.repository.SettingsRepository

data class SubjectAttendanceInfo(
    val subject: Subject,
    val presentCount: Int,
    val totalCount: Int,
    val percentage: Float,
    val safeBunks: Int
)

data class DashboardUiState(
    val overallPercentage: Float = 0f,
    val totalPresent: Int = 0,
    val totalClasses: Int = 0,
    val totalAbsent: Int = 0,
    val presentDays: Int = 0,
    val absentDays: Int = 0,
    val totalDays: Int = 0,
    val targetPercentage: Float = 75f,
    val todaySlots: List<TimetableSlot> = emptyList(),
    val subjects: List<Subject> = emptyList(),
    val subjectAttendance: List<SubjectAttendanceInfo> = emptyList(),
    val streak: Int = 0,
    val lowAttendanceSubjects: List<SubjectAttendanceInfo> = emptyList(),
    val isLoading: Boolean = true
)

@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val subjectRepository: SubjectRepository,
    private val timetableRepository: TimetableRepository,
    private val attendanceRepository: AttendanceRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    init { loadDashboard() }

    private fun loadDashboard() {
        viewModelScope.launch {
            val todayDow = DateUtils.getTodayDayOfWeek()

            val flow1 = combine(
                subjectRepository.getAllSubjects(),
                timetableRepository.getSlotsForDay(todayDow),
                attendanceRepository.getTotalPresentCount(),
                attendanceRepository.getTotalClassCount(),
                attendanceRepository.getTotalAbsentCount()
            ) { subjects, slots, present, total, absent ->
                Triple(subjects, slots, Triple(present, total, absent))
            }

            val flow2 = combine(
                attendanceRepository.getPresentDates(),
                attendanceRepository.getAbsentDates(),
                attendanceRepository.getAllDatesWithRecords(),
                settingsRepository.targetPercentage
            ) { presentDates, absentDates, allDates, target ->
                listOf(presentDates, absentDates, allDates) to target
            }

            combine(flow1, flow2) { data1, data2 ->
                val (subjects, slots, counts) = data1
                val (present, total, absent) = counts
                val (datesLists, target) = data2
                val presentDates = datesLists[0] as List<*>
                val absentDates = datesLists[1] as List<*>
                val allDates = datesLists[2] as List<*>

                DashboardUiState(
                    overallPercentage = calculateAttendancePercentage(present, total),
                    totalPresent = present,
                    totalClasses = total,
                    totalAbsent = absent,
                    presentDays = presentDates.size,
                    absentDays = absentDates.size,
                    totalDays = allDates.size,
                    targetPercentage = target,
                    todaySlots = slots,
                    subjects = subjects,
                    subjectAttendance = _uiState.value.subjectAttendance,
                    streak = DateUtils.calculateStreak(presentDates as List<Long>),
                    lowAttendanceSubjects = _uiState.value.lowAttendanceSubjects,
                    isLoading = false
                )
            }.collect { state ->
                _uiState.value = state
                // Load per-subject attendance separately
                loadSubjectAttendance(state.subjects, state.targetPercentage)
            }
        }
    }

    private fun loadSubjectAttendance(subjects: List<Subject>, targetPercent: Float) {
        viewModelScope.launch {
            val subjectAttList = subjects.map { subject ->
                var pCount = 0
                var tCount = 0
                val j1 = launch {
                    attendanceRepository.getPresentCountForSubject(subject.id)
                        .collect { pCount = it; return@collect }
                }
                val j2 = launch {
                    attendanceRepository.getTotalCountForSubject(subject.id)
                        .collect { tCount = it; return@collect }
                }
                j1.join(); j2.join()
                val pct = calculateAttendancePercentage(pCount, tCount)
                SubjectAttendanceInfo(subject, pCount, tCount, pct,
                    calculateSafeBunks(pCount, tCount, targetPercent))
            }
            _uiState.value = _uiState.value.copy(
                subjectAttendance = subjectAttList,
                lowAttendanceSubjects = subjectAttList.filter { it.percentage < targetPercent }
            )
        }
    }
}
