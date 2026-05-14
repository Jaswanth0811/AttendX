package com.attendx.app.ui.screens.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.repository.AttendanceRepository
import com.attendx.app.data.repository.SubjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import java.util.Calendar
import javax.inject.Inject

data class CalendarUiState(
    val year: Int = Calendar.getInstance().get(Calendar.YEAR),
    val month: Int = Calendar.getInstance().get(Calendar.MONTH),
    val presentDates: Set<Long> = emptySet(),
    val absentDates: Set<Long> = emptySet(),
    val holidayDates: Set<Long> = emptySet(),
    val selectedDateRecords: List<AttendanceRecord> = emptyList(),
    val subjects: List<Subject> = emptyList(),
    val selectedDate: Long? = null
)

@HiltViewModel
class CalendarViewModel @Inject constructor(
    private val attendanceRepository: AttendanceRepository,
    private val subjectRepository: SubjectRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(CalendarUiState())
    val uiState: StateFlow<CalendarUiState> = _uiState.asStateFlow()

    init { loadDates() }

    private fun loadDates() {
        viewModelScope.launch {
            combine(
                attendanceRepository.getPresentDates(),
                attendanceRepository.getAbsentDates(),
                attendanceRepository.getHolidayDates(),
                subjectRepository.getAllSubjects()
            ) { present, absent, holidays, subjects ->
                _uiState.value.copy(
                    presentDates = present.toSet(),
                    absentDates = absent.toSet(),
                    holidayDates = holidays.toSet(),
                    subjects = subjects
                )
            }.collect { _uiState.value = it }
        }
    }

    fun selectDate(date: Long) {
        viewModelScope.launch {
            attendanceRepository.getRecordsForDate(date).collect { records ->
                _uiState.value = _uiState.value.copy(selectedDate = date, selectedDateRecords = records)
            }
        }
    }

    fun previousMonth() {
        val s = _uiState.value
        if (s.month == 0) _uiState.value = s.copy(year = s.year - 1, month = 11)
        else _uiState.value = s.copy(month = s.month - 1)
    }

    fun nextMonth() {
        val s = _uiState.value
        if (s.month == 11) _uiState.value = s.copy(year = s.year + 1, month = 0)
        else _uiState.value = s.copy(month = s.month + 1)
    }

    fun clearSelection() {
        _uiState.value = _uiState.value.copy(selectedDate = null, selectedDateRecords = emptyList())
    }
}
