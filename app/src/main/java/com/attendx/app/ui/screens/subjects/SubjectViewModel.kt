package com.attendx.app.ui.screens.subjects

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.repository.AttendanceRepository
import com.attendx.app.data.repository.SubjectRepository
import com.attendx.app.ui.util.calculateAttendancePercentage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SubjectWithAttendance(
    val subject: Subject,
    val presentCount: Int = 0,
    val totalCount: Int = 0,
    val percentage: Float = 0f
)

data class SubjectUiState(
    val subjects: List<SubjectWithAttendance> = emptyList(),
    val isLoading: Boolean = true,
    val editingSubject: Subject? = null,
    val showAddSheet: Boolean = false
)

@HiltViewModel
class SubjectViewModel @Inject constructor(
    private val subjectRepository: SubjectRepository,
    private val attendanceRepository: AttendanceRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SubjectUiState())
    val uiState: StateFlow<SubjectUiState> = _uiState.asStateFlow()

    init { loadSubjects() }

    private fun loadSubjects() {
        viewModelScope.launch {
            subjectRepository.getAllSubjects().collect { subjects ->
                _uiState.value = _uiState.value.copy(
                    subjects = subjects.map { SubjectWithAttendance(it) },
                    isLoading = false
                )
                // Load attendance data separately
                loadAttendanceData(subjects)
            }
        }
    }

    private fun loadAttendanceData(subjects: List<Subject>) {
        viewModelScope.launch {
            val withAttendance = subjects.map { sub ->
                val p = attendanceRepository.getPresentCountForSubject(sub.id).first()
                val t = attendanceRepository.getTotalCountForSubject(sub.id).first()
                SubjectWithAttendance(sub, p, t, calculateAttendancePercentage(p, t))
            }
            _uiState.value = _uiState.value.copy(subjects = withAttendance)
        }
    }

    fun addSubject(name: String, code: String, faculty: String, colorHex: String) {
        viewModelScope.launch {
            subjectRepository.insertSubject(
                Subject(name = name, code = code, facultyName = faculty, colorHex = colorHex)
            )
            _uiState.value = _uiState.value.copy(showAddSheet = false)
        }
    }

    fun updateSubject(subject: Subject) {
        viewModelScope.launch {
            subjectRepository.updateSubject(subject)
            _uiState.value = _uiState.value.copy(editingSubject = null, showAddSheet = false)
        }
    }

    fun deleteSubject(subject: Subject) {
        viewModelScope.launch { subjectRepository.deleteSubject(subject) }
    }

    fun showAddSheet() { _uiState.value = _uiState.value.copy(showAddSheet = true, editingSubject = null) }
    fun showEditSheet(subject: Subject) { _uiState.value = _uiState.value.copy(showAddSheet = true, editingSubject = subject) }
    fun hideSheet() { _uiState.value = _uiState.value.copy(showAddSheet = false, editingSubject = null) }
}
