package com.attendx.app.ui.screens.attendance

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.ui.screens.calendar.CalendarViewModel
import com.attendx.app.ui.theme.AbsentRed
import com.attendx.app.ui.theme.PresentGreen
import com.attendx.app.ui.util.DateUtils
import java.util.Calendar

val HolidayOrange = Color(0xFFF59E0B)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttendanceScreen(
    viewModel: CalendarViewModel = hiltViewModel(),
    onNavigateToEntry: (Long?) -> Unit,
    onNavigateToHistory: () -> Unit // Kept for signature, unused now
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Attendance", fontWeight = FontWeight.Bold) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background)
            )
        }
    ) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            item {
                // Month Navigation
                Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp)) {
                    Column(Modifier.padding(16.dp)) {
                        Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween,
                            Alignment.CenterVertically) {
                            IconButton(onClick = { viewModel.previousMonth() }) {
                                Icon(Icons.Default.ChevronLeft, "Previous")
                            }
                            Text(
                                DateUtils.formatMonthYear(
                                    DateUtils.getDateMillis(state.year, state.month, 1)),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                            IconButton(onClick = { viewModel.nextMonth() }) {
                                Icon(Icons.Default.ChevronRight, "Next")
                            }
                        }
                        Spacer(Modifier.height(8.dp))

                        // Day headers
                        Row(Modifier.fillMaxWidth()) {
                            listOf("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su").forEach {
                                Text(it, Modifier.weight(1f),
                                    textAlign = TextAlign.Center,
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        Spacer(Modifier.height(8.dp))

                        // Calendar grid
                        val daysInMonth = DateUtils.getDaysInMonth(state.year, state.month)
                        val firstDayOffset = DateUtils.getFirstDayOfMonth(state.year, state.month)
                        val totalCells = firstDayOffset + daysInMonth
                        val rows = (totalCells + 6) / 7

                        for (row in 0 until rows) {
                            Row(Modifier.fillMaxWidth()) {
                                for (col in 0 until 7) {
                                    val idx = row * 7 + col
                                    val day = idx - firstDayOffset + 1
                                    if (day in 1..daysInMonth) {
                                        val dateMillis = DateUtils.getDateMillis(state.year, state.month, day)
                                        val isPresent = state.presentDates.any { d ->
                                            val c = Calendar.getInstance().apply { timeInMillis = d }
                                            c.get(Calendar.YEAR) == state.year &&
                                                c.get(Calendar.MONTH) == state.month &&
                                                c.get(Calendar.DAY_OF_MONTH) == day
                                        }
                                        val isAbsent = state.absentDates.any { d ->
                                            val c = Calendar.getInstance().apply { timeInMillis = d }
                                            c.get(Calendar.YEAR) == state.year &&
                                                c.get(Calendar.MONTH) == state.month &&
                                                c.get(Calendar.DAY_OF_MONTH) == day
                                        }
                                        val isHoliday = state.holidayDates.any { d ->
                                            val c = Calendar.getInstance().apply { timeInMillis = d }
                                            c.get(Calendar.YEAR) == state.year &&
                                                c.get(Calendar.MONTH) == state.month &&
                                                c.get(Calendar.DAY_OF_MONTH) == day
                                        }

                                        val isSunday = Calendar.getInstance().apply { timeInMillis = dateMillis }.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY

                                        val bgColor = when {
                                            isHoliday || isSunday -> HolidayOrange.copy(0.2f)
                                            isPresent -> PresentGreen.copy(0.2f)
                                            isAbsent -> AbsentRed.copy(0.2f)
                                            else -> MaterialTheme.colorScheme.surface
                                        }
                                        val textColor = when {
                                            isHoliday || isSunday -> HolidayOrange
                                            isPresent -> PresentGreen
                                            isAbsent -> AbsentRed
                                            else -> MaterialTheme.colorScheme.onSurface
                                        }
                                        val isSelected = state.selectedDate == dateMillis

                                        Box(
                                            Modifier.weight(1f).aspectRatio(1f)
                                                .padding(2.dp)
                                                .clip(CircleShape)
                                                .background(if (isSelected) MaterialTheme.colorScheme.primary.copy(0.2f) else bgColor)
                                                .clickable { viewModel.selectDate(dateMillis) },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Text("$day", fontSize = 13.sp,
                                                fontWeight = if (isPresent || isAbsent || isHoliday || isSelected) FontWeight.Bold else FontWeight.Normal,
                                                color = if (isSelected) MaterialTheme.colorScheme.primary else textColor)
                                        }
                                    } else {
                                        Box(Modifier.weight(1f).aspectRatio(1f))
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(Modifier.height(16.dp))

                // Legend
                Row(Modifier.fillMaxWidth(), Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(12.dp).clip(CircleShape).background(PresentGreen))
                    Spacer(Modifier.width(6.dp))
                    Text("Present", style = MaterialTheme.typography.labelSmall)
                    Spacer(Modifier.width(16.dp))
                    Box(Modifier.size(12.dp).clip(CircleShape).background(AbsentRed))
                    Spacer(Modifier.width(6.dp))
                    Text("Absent", style = MaterialTheme.typography.labelSmall)
                    Spacer(Modifier.width(16.dp))
                    Box(Modifier.size(12.dp).clip(CircleShape).background(HolidayOrange))
                    Spacer(Modifier.width(6.dp))
                    Text("Holiday", style = MaterialTheme.typography.labelSmall)
                }
                
                Spacer(Modifier.height(24.dp))
            }

            if (state.selectedDate != null) {
                item {
                    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                        Text(DateUtils.formatDate(state.selectedDate!!),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold)
                            
                        // Pass selected date to AttendanceEntry for editing
                        Button(onClick = { onNavigateToEntry(state.selectedDate) }) {
                            Icon(Icons.Default.Edit, "Edit", Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Edit")
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                }

                if (state.selectedDateRecords.isEmpty()) {
                    item {
                        Text("No records for this date", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                } else if (state.selectedDateRecords.all { it.status == AttendanceRecord.STATUS_HOLIDAY }) {
                    item {
                        val note = state.selectedDateRecords.firstOrNull()?.note?.takeIf { it.isNotBlank() } ?: "No reason provided"
                        Card(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                        ) {
                            Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                Box(Modifier.size(12.dp).clip(CircleShape).background(HolidayOrange))
                                Spacer(Modifier.width(12.dp))
                                Column {
                                    Text("All Day Holiday", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                                    Text(note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Spacer(Modifier.weight(1f))
                                Text("HOLIDAY", style = MaterialTheme.typography.labelMedium, color = HolidayOrange)
                            }
                        }
                    }
                } else if (state.selectedDateRecords.all { it.status == AttendanceRecord.STATUS_ABSENT }) {
                    item {
                        val note = state.selectedDateRecords.firstOrNull()?.note?.takeIf { it.isNotBlank() } ?: "No reason provided"
                        Card(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                        ) {
                            Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                Box(Modifier.size(12.dp).clip(CircleShape).background(AbsentRed))
                                Spacer(Modifier.width(12.dp))
                                Column {
                                    Text("All Day Absent", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                                    Text(note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Spacer(Modifier.weight(1f))
                                Text("ABSENT", style = MaterialTheme.typography.labelMedium, color = AbsentRed)
                            }
                        }
                    }
                } else {
                    items(state.selectedDateRecords) { record ->
                        Card(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = androidx.compose.material3.CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surface
                            )
                        ) {
                            Row(Modifier.fillMaxWidth().padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically) {
                                
                                val isHoliday = record.status == AttendanceRecord.STATUS_HOLIDAY
                                Box(Modifier.size(12.dp).clip(CircleShape).background(
                                    when (record.status) {
                                        AttendanceRecord.STATUS_PRESENT -> PresentGreen
                                        AttendanceRecord.STATUS_ABSENT -> AbsentRed
                                        AttendanceRecord.STATUS_HOLIDAY -> HolidayOrange
                                        else -> MaterialTheme.colorScheme.surfaceVariant
                                    }
                                ))
                                Spacer(Modifier.width(12.dp))
                                
                                Column {
                                    val subName = state.subjects.find { it.id == record.actualSubjectId }?.name
                                        ?: (if (record.status == AttendanceRecord.STATUS_HOLIDAY) "Holiday" else "Unknown")
                                        
                                    Text(
                                        text = if (isHoliday) "All Day" else "Period ${record.periodNumber}",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Text(
                                        text = subName,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold
                                    )
                                    if (!record.note.isNullOrBlank()) {
                                        Text(record.note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                
                                Spacer(Modifier.weight(1f))
                                Text(
                                    text = record.status,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = when (record.status) {
                                        AttendanceRecord.STATUS_PRESENT -> PresentGreen
                                        AttendanceRecord.STATUS_ABSENT -> AbsentRed
                                        AttendanceRecord.STATUS_HOLIDAY -> HolidayOrange
                                        else -> MaterialTheme.colorScheme.onSurfaceVariant
                                    }
                                )
                            }
                        }
                    }
                }
                
                item {
                    Spacer(Modifier.height(80.dp))
                }
            }
        }
    }
}
