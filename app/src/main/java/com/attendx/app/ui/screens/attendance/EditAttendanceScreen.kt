package com.attendx.app.ui.screens.attendance

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.EventBusy
import androidx.compose.material.icons.filled.Restore
import androidx.compose.material.icons.filled.BeachAccess
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.ui.components.EmptyState
import com.attendx.app.ui.theme.AbsentRed
import com.attendx.app.ui.theme.PresentGreen
import com.attendx.app.ui.util.DateUtils
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditAttendanceScreen(
    viewModel: AttendanceViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Edit Attendance", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background)
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        val markedEntries = state.todayEntries.filter { entry ->
            state.existingRecords.any { it.periodNumber == entry.slot.periodNumber }
        }

        if (markedEntries.isEmpty() && !state.isLoading) {
            EmptyState(
                icon = Icons.Default.EventBusy,
                title = "No Saved Records",
                message = "There are no saved periods to edit for this date.",
                modifier = Modifier.padding(padding)
            )
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(DateUtils.formatDate(viewModel.targetDateMillis),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                            
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = { 
                                    viewModel.undoFullDayHoliday()
                                    scope.launch { snackbarHostState.showSnackbar("Holiday reverted") }
                                    onNavigateBack()
                                },
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Default.Restore, null, Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Not Holiday")
                            }
                            OutlinedButton(
                                onClick = { 
                                    viewModel.undoFullDayAbsent()
                                    scope.launch { snackbarHostState.showSnackbar("Absent reverted to Present") }
                                    onNavigateBack()
                                },
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Default.Restore, null, Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Present")
                            }
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                }

                itemsIndexed(state.todayEntries) { index, entry ->
                    val isMarked = state.existingRecords.any { it.periodNumber == entry.slot.periodNumber }
                    
                    if (isMarked) {
                        EditAttendanceCard(
                            entry = entry,
                            subjects = state.subjects,
                            onStatusChange = { viewModel.updateEntryStatus(index, it) },
                            onActualSubjectChange = { subId, special ->
                                viewModel.updateEntryActualSubject(index, subId, special)
                            },
                            onSave = { 
                                viewModel.saveSinglePeriod(index)
                                scope.launch { snackbarHostState.showSnackbar("Period ${entry.slot.periodNumber} updated") }
                            }
                        )
                    }
                }

                item {
                    Spacer(Modifier.height(80.dp))
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditAttendanceCard(
    entry: AttendanceEntryItem,
    subjects: List<com.attendx.app.data.local.entity.Subject>,
    onStatusChange: (String) -> Unit,
    onActualSubjectChange: (Long?, String?) -> Unit,
    onSave: () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    
    val isPresent = entry.status == AttendanceRecord.STATUS_PRESENT
    val isAbsent = entry.status == AttendanceRecord.STATUS_ABSENT
    val isSpecial = entry.status in listOf(
        AttendanceRecord.STATUS_FREE, AttendanceRecord.STATUS_CANCELLED, AttendanceRecord.STATUS_SEMINAR)
        
    var isClassTaken by remember { mutableStateOf<Boolean>(
        entry.actualSubjectId == entry.slot.subjectId && !isSpecial
    ) }

    val actualSubjectName = when {
        entry.specialType == "FREE" || entry.status == AttendanceRecord.STATUS_FREE -> "Free Period"
        entry.specialType == "CANCELLED" || entry.status == AttendanceRecord.STATUS_CANCELLED -> "Cancelled"
        entry.specialType == "SEMINAR" || entry.status == AttendanceRecord.STATUS_SEMINAR -> "Seminar"
        else -> subjects.find { it.id == entry.actualSubjectId }?.name ?: "Select subject"
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(2.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                Text("Period ${entry.slot.periodNumber}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary)
                Text("${DateUtils.formatTime(entry.slot.startTime)} - ${DateUtils.formatTime(entry.slot.endTime)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Spacer(Modifier.height(4.dp))

            Text("Scheduled: ${entry.scheduledSubject?.name ?: "Free Period"}",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(16.dp))

            Text("Was the scheduled class taken?", style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = { 
                        isClassTaken = true
                        onActualSubjectChange(entry.slot.subjectId, null)
                        if (isSpecial) onStatusChange(AttendanceRecord.STATUS_PRESENT)
                    },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = if (isClassTaken) MaterialTheme.colorScheme.primaryContainer else Color.Transparent
                    )
                ) { Text("Yes") }

                OutlinedButton(
                    onClick = { isClassTaken = false },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = if (!isClassTaken) MaterialTheme.colorScheme.errorContainer else Color.Transparent
                    )
                ) { Text("No") }
            }
            Spacer(Modifier.height(16.dp))

            AnimatedVisibility(visible = !isClassTaken) {
                Column {
                    Text("Actually taken:", style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(4.dp))

                    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                        OutlinedTextField(
                            value = actualSubjectName, onValueChange = {},
                            readOnly = true, modifier = Modifier.menuAnchor().fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                            textStyle = MaterialTheme.typography.bodyMedium
                        )
                        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                            subjects.forEach { sub ->
                                DropdownMenuItem(text = { Text(sub.name) },
                                    onClick = { 
                                        onActualSubjectChange(sub.id, null)
                                        if (isSpecial) onStatusChange(AttendanceRecord.STATUS_PRESENT)
                                        expanded = false 
                                    })
                            }
                            DropdownMenuItem(text = { Text("Free Period") },
                                onClick = { onActualSubjectChange(null, "FREE"); expanded = false })
                            DropdownMenuItem(text = { Text("Cancelled") },
                                onClick = { onActualSubjectChange(null, "CANCELLED"); expanded = false })
                            DropdownMenuItem(text = { Text("Seminar") },
                                onClick = { onActualSubjectChange(null, "SEMINAR"); expanded = false })
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                }
            }

            if (!isSpecial) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    val presentBgColor by animateColorAsState(
                        if (isPresent) PresentGreen else MaterialTheme.colorScheme.surface, label = "p")
                    val absentBgColor by animateColorAsState(
                        if (isAbsent) AbsentRed else MaterialTheme.colorScheme.surface, label = "a")

                    Button(
                        onClick = { onStatusChange(AttendanceRecord.STATUS_PRESENT) },
                        modifier = Modifier.weight(1f).height(44.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = presentBgColor,
                            contentColor = if (isPresent) MaterialTheme.colorScheme.onPrimary
                            else MaterialTheme.colorScheme.onSurface),
                        shape = RoundedCornerShape(12.dp)
                    ) { Text("Present", fontWeight = FontWeight.SemiBold) }

                    OutlinedButton(
                        onClick = { onStatusChange(AttendanceRecord.STATUS_ABSENT) },
                        modifier = Modifier.weight(1f).height(44.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = absentBgColor,
                            contentColor = if (isAbsent) MaterialTheme.colorScheme.onError
                            else MaterialTheme.colorScheme.onSurface),
                        shape = RoundedCornerShape(12.dp)
                    ) { Text("Absent", fontWeight = FontWeight.SemiBold) }
                    
                    IconButton(
                        onClick = onSave,
                        colors = IconButtonDefaults.iconButtonColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                            contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                        ),
                        modifier = Modifier.size(44.dp)
                    ) {
                        Icon(Icons.Default.Check, contentDescription = "Update Period")
                    }
                }
            } else {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    Button(
                        onClick = onSave,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                            contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    ) {
                        Icon(Icons.Default.Check, contentDescription = "Update Period")
                        Spacer(Modifier.width(8.dp))
                        Text("Update Period")
                    }
                }
            }
        }
    }
}
