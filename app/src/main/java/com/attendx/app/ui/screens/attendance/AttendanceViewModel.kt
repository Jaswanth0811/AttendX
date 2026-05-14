package com.attendx.app.ui.screens.attendance

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.local.entity.TimetableSlot
import com.attendx.app.data.repository.AttendanceRepository
import com.attendx.app.data.repository.SubjectRepository
import com.attendx.app.data.repository.TimetableRepository
import com.attendx.app.ui.util.DateUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject
import androidx.lifecycle.SavedStateHandle
import java.util.Calendar

data class AttendanceEntryItem(
    val slot: TimetableSlot,
    val scheduledSubject: Subject?,
    var actualSubjectId: Long? = null,
    var status: String = AttendanceRecord.STATUS_PRESENT,
    var specialType: String? = null // "FREE", "CANCELLED", "SEMINAR"
)

data class AttendanceUiState(
    val todayEntries: List<AttendanceEntryItem> = emptyList(),
    val subjects: List<Subject> = emptyList(),
    val allRecords: List<AttendanceRecord> = emptyList(),
    val existingRecords: List<AttendanceRecord> = emptyList(),
    val isSaved: Boolean = false,
    val isLoading: Boolean = true
)

@HiltViewModel
class AttendanceViewModel @Inject constructor(
    private val attendanceRepository: AttendanceRepository,
    private val timetableRepository: TimetableRepository,
    private val subjectRepository: SubjectRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    val targetDateMillis: Long = savedStateHandle.get<String>("date")?.toLongOrNull() ?: DateUtils.getTodayStartMillis()


    private val _uiState = MutableStateFlow(AttendanceUiState())
    val uiState: StateFlow<AttendanceUiState> = _uiState.asStateFlow()

    init { loadData() }

    private fun loadData() {
        val calendar = Calendar.getInstance().apply { timeInMillis = targetDateMillis }
        var dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1
        if (dayOfWeek == 0) dayOfWeek = 7 // Adjust Sunday from 0 to 7 if your DateUtils uses 1=Mon, 7=Sun

        viewModelScope.launch {
            combine(
                timetableRepository.getSlotsForDay(dayOfWeek),
                subjectRepository.getAllSubjects(),
                attendanceRepository.getRecordsForDate(targetDateMillis),
                attendanceRepository.getAllRecords() // kept for compatibility if used
            ) { slots, subjects, existing, allRecords ->
                val entries = slots.map { slot ->
                    val sub = subjects.find { it.id == slot.subjectId }
                    val existingRecord = existing.find { it.periodNumber == slot.periodNumber }
                    AttendanceEntryItem(
                        slot = slot,
                        scheduledSubject = sub,
                        actualSubjectId = existingRecord?.actualSubjectId ?: slot.subjectId,
                        status = existingRecord?.status ?: AttendanceRecord.STATUS_PRESENT
                    )
                }
                AttendanceUiState(
                    todayEntries = entries,
                    subjects = subjects,
                    allRecords = allRecords,
                    existingRecords = existing,
                    isSaved = existing.isNotEmpty(),
                    isLoading = false
                )
            }.collect { _uiState.value = it }
        }
    }

    fun updateEntryStatus(index: Int, status: String) {
        val entries = _uiState.value.todayEntries.toMutableList()
        if (index in entries.indices) {
            entries[index] = entries[index].copy(status = status)
            _uiState.value = _uiState.value.copy(todayEntries = entries)
        }
    }

    fun updateEntryActualSubject(index: Int, subjectId: Long?, specialType: String?) {
        val entries = _uiState.value.todayEntries.toMutableList()
        if (index in entries.indices) {
            val newStatus = when (specialType) {
                "FREE" -> AttendanceRecord.STATUS_FREE
                "CANCELLED" -> AttendanceRecord.STATUS_CANCELLED
                "SEMINAR" -> AttendanceRecord.STATUS_SEMINAR
                else -> entries[index].status
            }
            entries[index] = entries[index].copy(
                actualSubjectId = subjectId,
                specialType = specialType,
                status = newStatus
            )
            _uiState.value = _uiState.value.copy(todayEntries = entries)
        }
    }

    fun saveAttendance() {
        // Keep this for backward compatibility or if needed
        viewModelScope.launch {
            val calendar = Calendar.getInstance().apply { timeInMillis = targetDateMillis }
            var dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1
            if (dayOfWeek == 0) dayOfWeek = 7

            val records = _uiState.value.todayEntries.map { entry ->
                AttendanceRecord(
                    date = targetDateMillis,
                    dayOfWeek = dayOfWeek,
                    periodNumber = entry.slot.periodNumber,
                    scheduledSubjectId = entry.slot.subjectId,
                    actualSubjectId = entry.actualSubjectId,
                    status = entry.status
                )
            }
            attendanceRepository.insertRecords(records)
            _uiState.value = _uiState.value.copy(isSaved = true)
        }
    }

    fun saveSinglePeriod(index: Int) {
        viewModelScope.launch {
            val entries = _uiState.value.todayEntries
            if (index in entries.indices) {
                val entry = entries[index]
                val calendar = Calendar.getInstance().apply { timeInMillis = targetDateMillis }
                var dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1
                if (dayOfWeek == 0) dayOfWeek = 7

                val record = AttendanceRecord(
                    date = targetDateMillis,
                    dayOfWeek = dayOfWeek,
                    periodNumber = entry.slot.periodNumber,
                    scheduledSubjectId = entry.slot.subjectId,
                    actualSubjectId = entry.actualSubjectId,
                    status = entry.status
                )
                attendanceRepository.insertRecord(record)
            }
        }
    }

    fun markAllAsHoliday(reason: String) {
        viewModelScope.launch {
            val calendar = Calendar.getInstance().apply { timeInMillis = targetDateMillis }
            var dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1
            if (dayOfWeek == 0) dayOfWeek = 7

            val records = _uiState.value.todayEntries.map { entry ->
                AttendanceRecord(
                    date = targetDateMillis,
                    dayOfWeek = dayOfWeek,
                    periodNumber = entry.slot.periodNumber,
                    scheduledSubjectId = entry.slot.subjectId,
                    actualSubjectId = entry.actualSubjectId,
                    status = AttendanceRecord.STATUS_HOLIDAY,
                    note = reason
                )
            }
            if (records.isNotEmpty()) {
                attendanceRepository.insertRecords(records)
            } else {
                val dummyRecord = AttendanceRecord(
                    date = targetDateMillis,
                    dayOfWeek = dayOfWeek,
                    periodNumber = 0,
                    status = AttendanceRecord.STATUS_HOLIDAY,
                    note = reason
                )
                attendanceRepository.insertRecord(dummyRecord)
            }
        }
    }

    fun markAllAsAbsent(reason: String) {
        viewModelScope.launch {
            val calendar = Calendar.getInstance().apply { timeInMillis = targetDateMillis }
            var dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1
            if (dayOfWeek == 0) dayOfWeek = 7

            val records = _uiState.value.todayEntries.map { entry ->
                AttendanceRecord(
                    date = targetDateMillis,
                    dayOfWeek = dayOfWeek,
                    periodNumber = entry.slot.periodNumber,
                    scheduledSubjectId = entry.slot.subjectId,
                    actualSubjectId = entry.actualSubjectId,
                    status = AttendanceRecord.STATUS_ABSENT,
                    note = reason
                )
            }
            if (records.isNotEmpty()) {
                attendanceRepository.insertRecords(records)
            }
        }
    }

    fun undoFullDayAbsent() {
        viewModelScope.launch {
            attendanceRepository.deleteAbsentRecordsForDate(targetDateMillis)
        }
    }

    fun undoFullDayHoliday() {
        viewModelScope.launch {
            attendanceRepository.deleteHolidayRecordsForDate(targetDateMillis)
        }
    }
}
