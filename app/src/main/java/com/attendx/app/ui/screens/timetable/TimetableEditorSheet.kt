package com.attendx.app.ui.screens.timetable

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.local.entity.TimetableSlot

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimetableEditorSheet(
    subjects: List<Subject>,
    selectedDay: Int,
    editingSlot: TimetableSlot?,
    onAdd: (Int, Long?, String, String) -> Unit,
    onUpdate: (TimetableSlot) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selectedSubjectId by remember { mutableStateOf(editingSlot?.subjectId) }
    var startTime by remember { mutableStateOf(editingSlot?.startTime ?: "09:00") }
    var endTime by remember { mutableStateOf(editingSlot?.endTime ?: "10:00") }
    var expanded by remember { mutableStateOf(false) }
    
    var showStartPicker by remember { mutableStateOf(false) }
    var showEndPicker by remember { mutableStateOf(false) }

    val subjectName = subjects.find { it.id == selectedSubjectId }?.name ?: "Free Period"
    
    fun formatTime(hour: Int, minute: Int): String {
        return String.format("%02d:%02d", hour, minute)
    }

    if (showStartPicker) {
        val initialHour = startTime.substringBefore(":").toIntOrNull() ?: 9
        val initialMinute = startTime.substringAfter(":").toIntOrNull() ?: 0
        val timePickerState = rememberTimePickerState(initialHour = initialHour, initialMinute = initialMinute, is24Hour = false)
        
        AlertDialog(
            onDismissRequest = { showStartPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    startTime = formatTime(timePickerState.hour, timePickerState.minute)
                    showStartPicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showStartPicker = false }) { Text("Cancel") }
            },
            text = {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    TimePicker(state = timePickerState)
                }
            }
        )
    }

    if (showEndPicker) {
        val initialHour = endTime.substringBefore(":").toIntOrNull() ?: 10
        val initialMinute = endTime.substringAfter(":").toIntOrNull() ?: 0
        val timePickerState = rememberTimePickerState(initialHour = initialHour, initialMinute = initialMinute, is24Hour = false)
        
        AlertDialog(
            onDismissRequest = { showEndPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    endTime = formatTime(timePickerState.hour, timePickerState.minute)
                    showEndPicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showEndPicker = false }) { Text("Cancel") }
            },
            text = {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    TimePicker(state = timePickerState)
                }
            }
        )
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 16.dp)) {
            Text(
                if (editingSlot != null) "Edit Period" else "Add Period",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(20.dp))

            ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                OutlinedTextField(
                    value = subjectName,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Subject") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                    modifier = Modifier.menuAnchor().fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp)
                )
                ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    DropdownMenuItem(
                        text = { Text("Free Period") },
                        onClick = { selectedSubjectId = null; expanded = false }
                    )
                    subjects.forEach { sub ->
                        DropdownMenuItem(
                            text = { Text(sub.name) },
                            onClick = { selectedSubjectId = sub.id; expanded = false }
                        )
                    }
                }
            }
            Spacer(Modifier.height(12.dp))

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = startTime, onValueChange = { },
                    label = { Text("Start") },
                    readOnly = true,
                    enabled = false,
                    modifier = Modifier.weight(1f).clickable { showStartPicker = true },
                    shape = RoundedCornerShape(12.dp), singleLine = true,
                    colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                        disabledTextColor = MaterialTheme.colorScheme.onSurface,
                        disabledBorderColor = MaterialTheme.colorScheme.outline,
                        disabledLabelColor = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                )
                OutlinedTextField(
                    value = endTime, onValueChange = { },
                    label = { Text("End") },
                    readOnly = true,
                    enabled = false,
                    modifier = Modifier.weight(1f).clickable { showEndPicker = true },
                    shape = RoundedCornerShape(12.dp), singleLine = true,
                    colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                        disabledTextColor = MaterialTheme.colorScheme.onSurface,
                        disabledBorderColor = MaterialTheme.colorScheme.outline,
                        disabledLabelColor = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                )
            }
            Spacer(Modifier.height(24.dp))

            Button(
                onClick = {
                    if (editingSlot != null) {
                        onUpdate(editingSlot.copy(
                            subjectId = selectedSubjectId,
                            startTime = startTime, endTime = endTime))
                    } else {
                        onAdd(selectedDay, selectedSubjectId, startTime, endTime)
                    }
                },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(14.dp)
            ) {
                Text(if (editingSlot != null) "Update" else "Add Period",
                    fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}
