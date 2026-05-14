package com.attendx.app.ui.screens.timetable

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.local.entity.TimetableSlot
import com.attendx.app.data.repository.SubjectRepository
import com.attendx.app.data.repository.TimetableRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject

data class TimetableUiState(
    val selectedDay: Int = 1,
    val slots: Map<Int, List<TimetableSlot>> = emptyMap(),
    val subjects: List<Subject> = emptyList(),
    val showEditorSheet: Boolean = false,
    val editingSlot: TimetableSlot? = null,
    val isLoading: Boolean = true
)

@HiltViewModel
class TimetableViewModel @Inject constructor(
    private val timetableRepository: TimetableRepository,
    private val subjectRepository: SubjectRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(TimetableUiState())
    val uiState: StateFlow<TimetableUiState> = _uiState.asStateFlow()

    init { loadData() }

    private fun loadData() {
        viewModelScope.launch {
            combine(
                timetableRepository.getAllSlots(),
                subjectRepository.getAllSubjects()
            ) { slots, subjects ->
                val grouped = slots.groupBy { it.dayOfWeek }
                _uiState.value.copy(
                    slots = grouped, subjects = subjects, isLoading = false
                )
            }.collect { _uiState.value = it }
        }
    }

    fun selectDay(day: Int) {
        _uiState.value = _uiState.value.copy(selectedDay = day)
    }

    fun addSlot(dayOfWeek: Int, subjectId: Long?, startTime: String, endTime: String) {
        viewModelScope.launch {
            val maxPeriod = timetableRepository.getMaxPeriodForDay(dayOfWeek)
            timetableRepository.insertSlot(
                TimetableSlot(
                    dayOfWeek = dayOfWeek,
                    periodNumber = maxPeriod + 1,
                    startTime = startTime,
                    endTime = endTime,
                    subjectId = subjectId
                )
            )
            _uiState.value = _uiState.value.copy(showEditorSheet = false)
        }
    }

    fun updateSlot(slot: TimetableSlot) {
        viewModelScope.launch {
            timetableRepository.updateSlot(slot)
            _uiState.value = _uiState.value.copy(showEditorSheet = false, editingSlot = null)
        }
    }

    fun deleteSlot(slot: TimetableSlot) {
        viewModelScope.launch { timetableRepository.deleteSlot(slot) }
    }

    fun showAddSheet() { _uiState.value = _uiState.value.copy(showEditorSheet = true, editingSlot = null) }
    fun showEditSheet(slot: TimetableSlot) { _uiState.value = _uiState.value.copy(showEditorSheet = true, editingSlot = slot) }
    fun hideSheet() { _uiState.value = _uiState.value.copy(showEditorSheet = false, editingSlot = null) }
}
