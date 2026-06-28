package com.attendx.app.ui.screens.settings

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.local.AttendXDatabase
import com.attendx.app.data.local.entity.Semester
import com.attendx.app.data.repository.AttendanceRepository
import com.attendx.app.data.repository.SemesterRepository
import com.attendx.app.data.repository.SettingsRepository
import com.attendx.app.data.repository.SubjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import javax.inject.Inject

data class SettingsUiState(
    val semester: Semester? = null,
    val showSemesterDialog: Boolean = false,
    val exportMessage: String? = null,
    val targetPercentage: Float = 75f,
    val showTargetDialog: Boolean = false
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val semesterRepository: SemesterRepository,
    private val subjectRepository: SubjectRepository,
    private val attendanceRepository: AttendanceRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    val collegeStartTimeMinutes = settingsRepository.collegeStartTimeMinutes
    val collegeEndTimeMinutes = settingsRepository.collegeEndTimeMinutes
    val periodDurationMinutes = settingsRepository.periodDurationMinutes
    val lunchBreakDurationMinutes = settingsRepository.lunchBreakDurationMinutes
    val lunchPeriodIndex = settingsRepository.lunchPeriodIndex
    val periodsPerDayString = settingsRepository.periodsPerDayString

    init {
        viewModelScope.launch {
            semesterRepository.getActiveSemester().collect {
                _uiState.value = _uiState.value.copy(semester = it)
            }
        }
        viewModelScope.launch {
            settingsRepository.targetPercentage.collect {
                _uiState.value = _uiState.value.copy(targetPercentage = it)
            }
        }
    }

    fun saveSemester(name: String, startDate: Long, endDate: Long) {
        viewModelScope.launch {
            semesterRepository.setActiveSemester(
                Semester(name = name, startDate = startDate, endDate = endDate)
            )
            _uiState.value = _uiState.value.copy(showSemesterDialog = false)
        }
    }

    fun showSemesterDialog() { _uiState.value = _uiState.value.copy(showSemesterDialog = true) }
    fun hideSemesterDialog() { _uiState.value = _uiState.value.copy(showSemesterDialog = false) }

    fun setTargetPercentage(target: Float) {
        settingsRepository.setTargetPercentage(target)
        _uiState.value = _uiState.value.copy(showTargetDialog = false)
    }

    fun showTargetDialog() { _uiState.value = _uiState.value.copy(showTargetDialog = true) }
    fun hideTargetDialog() { _uiState.value = _uiState.value.copy(showTargetDialog = false) }

    fun backupDatabase() {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val dbFile = context.getDatabasePath(AttendXDatabase.DATABASE_NAME)
                val backupDir = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    "AttendX"
                )
                backupDir.mkdirs()
                val backupFile = File(backupDir, "attendx_backup_${System.currentTimeMillis()}.db")
                dbFile.copyTo(backupFile, overwrite = true)
                withContext(Dispatchers.Main) {
                    Toast.makeText(context, "Backup saved to Downloads/AttendX", Toast.LENGTH_LONG).show()
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(context, "Backup failed: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    fun exportCsv() {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                attendanceRepository.getAllRecords().collect { records ->
                    val csv = buildString {
                        appendLine("Date,Period,ScheduledSubjectId,ActualSubjectId,Status,Note")
                        records.forEach { r ->
                            appendLine("${com.attendx.app.ui.util.DateUtils.formatDate(r.date)},${r.periodNumber},${r.scheduledSubjectId},${r.actualSubjectId},${r.status},${r.note ?: ""}")
                        }
                    }
                    val dir = File(
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                        "AttendX"
                    )
                    dir.mkdirs()
                    val file = File(dir, "attendance_${System.currentTimeMillis()}.csv")
                    file.writeText(csv)
                    withContext(Dispatchers.Main) {
                        Toast.makeText(context, "CSV exported to Downloads/AttendX", Toast.LENGTH_LONG).show()
                    }
                    return@collect
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(context, "Export failed: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
    fun setCollegeStartTimeMinutes(minutes: Int) = settingsRepository.setCollegeStartTimeMinutes(minutes)
    fun setCollegeEndTimeMinutes(minutes: Int) = settingsRepository.setCollegeEndTimeMinutes(minutes)
    fun setPeriodDurationMinutes(minutes: Int) = settingsRepository.setPeriodDurationMinutes(minutes)
    fun setLunchBreakDurationMinutes(minutes: Int) = settingsRepository.setLunchBreakDurationMinutes(minutes)
    fun setLunchPeriodIndex(index: Int) = settingsRepository.setLunchPeriodIndex(index)
    fun setPeriodsPerDayString(daysString: String) = settingsRepository.setPeriodsPerDayString(daysString)
}
