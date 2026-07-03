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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.EventBusy
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.runtime.mutableStateOf
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.ui.components.EmptyState
import com.attendx.app.ui.theme.AbsentRed
import com.attendx.app.ui.theme.PresentGreen
import com.attendx.app.ui.util.DateUtils
import java.util.Calendar
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttendanceEntryScreen(
    viewModel: AttendanceViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    var showHolidayDialog by remember { mutableStateOf(false) }
    var showAbsentDialog by remember { mutableStateOf(false) }
    var reasonText by remember { mutableStateOf("") }

    if (showHolidayDialog) {
        AlertDialog(
            onDismissRequest = { showHolidayDialog = false },
            title = { Text("Mark Holiday") },
            text = {
                OutlinedTextField(
                    value = reasonText,
                    onValueChange = { reasonText = it },
                    label = { Text("Reason for Holiday") },
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.markAllAsHoliday(reasonText)
                    showHolidayDialog = false
                    reasonText = ""
                    scope.launch { snackbarHostState.showSnackbar("Marked as Holiday") }
                }) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { showHolidayDialog = false }) { Text("Cancel") }
            }
        )
    }

    if (showAbsentDialog) {
        AlertDialog(
            onDismissRequest = { showAbsentDialog = false },
            title = { Text("Mark Absent") },
            text = {
                OutlinedTextField(
                    value = reasonText,
                    onValueChange = { reasonText = it },
                    label = { Text("Reason for Absence") },
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.markAllAsAbsent(reasonText)
                    showAbsentDialog = false
                    reasonText = ""
                    scope.launch { snackbarHostState.showSnackbar("Marked as Absent") }
                }) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { showAbsentDialog = false }) { Text("Cancel") }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Mark Attendance", fontWeight = FontWeight.Bold) },
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
        val isSunday = Calendar.getInstance().apply { timeInMillis = viewModel.targetDateMillis }.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY

        if (isSunday) {
            EmptyState(
                icon = Icons.Default.BeachAccess,
                title = "Wow... Sunday?",
                message = "Trying to mark attendance on a Sunday? Take a break, you overachiever! It's a Holiday!",
                modifier = Modifier.padding(padding)
            )
        } else if (state.todayEntries.isEmpty() && !state.isLoading) {
            EmptyState(
                icon = Icons.Default.EventBusy,
                title = "No Classes",
                message = "There are no periods to mark for this date.",
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
                                    reasonText = ""
                                    showHolidayDialog = true
                                },
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Default.BeachAccess, null, Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Mark Holiday")
                            }
                            OutlinedButton(
                                onClick = { 
                                    reasonText = ""
                                    showAbsentDialog = true
                                },
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Default.EventBusy, null, Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Absent")
                            }
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                }

                val unmarkedEntries = state.todayEntries.filter { entry ->
                    !state.existingRecords.any { it.periodNumber == entry.slot.periodNumber }
                }

                if (unmarkedEntries.isEmpty() && state.todayEntries.isNotEmpty()) {
                    item {
                        Spacer(Modifier.height(32.dp))
                        EmptyState(
                            icon = Icons.Default.CheckCircle,
                            title = "All Caught Up!",
                            message = "You have marked all periods for this date."
                        )
                    }
                } else {
                    itemsIndexed(state.todayEntries) { index, entry ->
                        val isLocked = state.existingRecords.any { it.periodNumber == entry.slot.periodNumber }
                        
                        if (!isLocked) {
                            AttendanceEntryCard(
                                entry = entry,
                                subjects = state.subjects,
                                isLocked = false, // Always false now since we hide locked ones
                                onStatusChange = { viewModel.updateEntryStatus(index, it) },
                                onActualSubjectChange = { subId, special ->
                                    viewModel.updateEntryActualSubject(index, subId, special)
                                },
                                onSave = { 
                                    viewModel.saveSinglePeriod(index)
                                    scope.launch { snackbarHostState.showSnackbar("Period ${entry.slot.periodNumber} saved") }
                                }
                            )
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AttendanceEntryCard(
    entry: AttendanceEntryItem,
    subjects: List<com.attendx.app.data.local.entity.Subject>,
    isLocked: Boolean,
    onStatusChange: (String) -> Unit,
    onActualSubjectChange: (Long?, String?) -> Unit,
    onSave: () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    
    // UI state for the step-by-step logic
    var isClassTaken by remember { mutableStateOf<Boolean?>(null) }
    
    val isPresent = entry.status == AttendanceRecord.STATUS_PRESENT
    val isAbsent = entry.status == AttendanceRecord.STATUS_ABSENT
    val isSpecial = entry.status in listOf(
        AttendanceRecord.STATUS_FREE, AttendanceRecord.STATUS_CANCELLED, AttendanceRecord.STATUS_SEMINAR)
        
    // If it's already locked from db, try to deduce the state
    LaunchedEffect(isLocked) {
        if (isLocked) {
            if (entry.actualSubjectId == entry.slot.subjectId && !isSpecial) {
                isClassTaken = true
            } else if (entry.actualSubjectId != entry.slot.subjectId || isSpecial) {
                isClassTaken = false
            }
        }
    }

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

            if (!isLocked) {
                // Step 1: Was scheduled class taken?
                Text("Was the scheduled class taken?", style = MaterialTheme.typography.labelMedium)
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = { 
                            isClassTaken = true
                            onActualSubjectChange(entry.slot.subjectId, null) // Reset to scheduled
                            if (isSpecial) onStatusChange(AttendanceRecord.STATUS_PRESENT)
                        },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = if (isClassTaken == true) MaterialTheme.colorScheme.primaryContainer else Color.Transparent
                        )
                    ) { Text("Yes") }

                    OutlinedButton(
                        onClick = { isClassTaken = false },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = if (isClassTaken == false) MaterialTheme.colorScheme.errorContainer else Color.Transparent
                        )
                    ) { Text("No") }
                }
                
                Spacer(Modifier.height(16.dp))
            } else {
                Text(
                    text = "✓ Saved", 
                    color = PresentGreen,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(8.dp))
            }

            // Step 2 logic based on Step 1
            AnimatedVisibility(visible = isClassTaken == false || (isLocked && entry.actualSubjectId != entry.slot.subjectId)) {
                Column {
                    Text("Actually taken:", style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(4.dp))

                    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { if (!isLocked) expanded = it }) {
                        OutlinedTextField(
                            value = actualSubjectName, onValueChange = {},
                            readOnly = true, modifier = Modifier.menuAnchor().fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                            textStyle = MaterialTheme.typography.bodyMedium,
                            enabled = !isLocked
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

            AnimatedVisibility(visible = isClassTaken != null) {
                if (!isSpecial) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        val presentBgColor by animateColorAsState(
                            if (isPresent) PresentGreen else MaterialTheme.colorScheme.surface, label = "p")
                        val absentBgColor by animateColorAsState(
                            if (isAbsent) AbsentRed else MaterialTheme.colorScheme.surface, label = "a")

                        Button(
                            onClick = { if (!isLocked) onStatusChange(AttendanceRecord.STATUS_PRESENT) },
                            modifier = Modifier.weight(1f).height(44.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = presentBgColor,
                                contentColor = if (isPresent) MaterialTheme.colorScheme.onPrimary
                                else MaterialTheme.colorScheme.onSurface),
                            shape = RoundedCornerShape(12.dp)
                        ) { Text("Present", fontWeight = FontWeight.SemiBold) }

                        OutlinedButton(
                            onClick = { if (!isLocked) onStatusChange(AttendanceRecord.STATUS_ABSENT) },
                            modifier = Modifier.weight(1f).height(44.dp),
                            colors = ButtonDefaults.outlinedButtonColors(
                                containerColor = absentBgColor,
                                contentColor = if (isAbsent) MaterialTheme.colorScheme.onError
                                else MaterialTheme.colorScheme.onSurface),
                            shape = RoundedCornerShape(12.dp)
                        ) { Text("Absent", fontWeight = FontWeight.SemiBold) }
                        
                        if (!isLocked) {
                            // Tick / Save button
                            IconButton(
                                onClick = onSave,
                                colors = IconButtonDefaults.iconButtonColors(
                                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                                ),
                                modifier = Modifier.size(44.dp)
                            ) {
                                Icon(Icons.Default.Check, contentDescription = "Save Period")
                            }
                        }
                    }
                } else if (!isLocked) {
                    // For special types (free, cancelled), just show the tick button since there's no present/absent
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        Button(
                            onClick = onSave,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primaryContainer,
                                contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        ) {
                            Icon(Icons.Default.Check, contentDescription = "Save Period")
                            Spacer(Modifier.width(8.dp))
                            Text("Save Period")
                        }
                    }
                }
            }
        }
    }
}
