package com.attendx.app.ui.screens.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimetableSetupSheet(
    initialStartMins: Int,
    initialEndMins: Int,
    initialPeriodMins: Int,
    initialLunchMins: Int,
    initialLunchIndex: Int,
    onSave: (start: Int, end: Int, period: Int, lunch: Int, lunchIdx: Int) -> Unit,
    onDismiss: () -> Unit
) {
    var startText by remember { mutableStateOf(formatMinsToTime(initialStartMins)) }
    var endText by remember { mutableStateOf(formatMinsToTime(initialEndMins)) }
    var periodMins by remember { mutableStateOf(initialPeriodMins.toString()) }
    var lunchMins by remember { mutableStateOf(initialLunchMins.toString()) }
    var lunchIdx by remember { mutableStateOf(initialLunchIndex.toString()) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().padding(24.dp)) {
            Text("Timetable Global Settings", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(16.dp))

            Text("Enter time as HH:MM (24-hour)", style = MaterialTheme.typography.bodySmall)
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedTextField(
                    value = startText, onValueChange = { startText = it },
                    label = { Text("Start Time") }, modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = endText, onValueChange = { endText = it },
                    label = { Text("End Time") }, modifier = Modifier.weight(1f)
                )
            }
            Spacer(Modifier.height(12.dp))
            
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedTextField(
                    value = periodMins, onValueChange = { periodMins = it },
                    label = { Text("Period (mins)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = lunchMins, onValueChange = { lunchMins = it },
                    label = { Text("Lunch (mins)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.weight(1f)
                )
            }
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = lunchIdx, onValueChange = { lunchIdx = it },
                label = { Text("Lunch is after Period #") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth()
            )
            
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = {
                    val sMins = parseTimeToMins(startText)
                    val eMins = parseTimeToMins(endText)
                    val pMins = periodMins.toIntOrNull() ?: 50
                    val lMins = lunchMins.toIntOrNull() ?: 45
                    val lIdx = lunchIdx.toIntOrNull() ?: 4
                    onSave(sMins, eMins, pMins, lMins, lIdx)
                },
                modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(14.dp)
            ) { Text("Save Timetable", fontWeight = FontWeight.SemiBold) }
            Spacer(Modifier.height(32.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PerDayPeriodsSheet(
    initialPeriodsString: String,
    onSave: (String) -> Unit,
    onDismiss: () -> Unit
) {
    // "7,7,7,7,7,4" mapping to Monday..Saturday
    val days = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
    val defaultVals = initialPeriodsString.split(",").map { it.toIntOrNull() ?: 7 }
    val counts = remember { mutableStateListOf(*defaultVals.toTypedArray()) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().padding(24.dp)) {
            Text("Periods Per Day", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(16.dp))
            
            LazyColumn(Modifier.weight(1f, fill = false)) {
                itemsIndexed(days) { index, day ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                    ) {
                        Text(day, style = MaterialTheme.typography.bodyLarge)
                        OutlinedTextField(
                            value = counts.getOrNull(index)?.toString() ?: "7",
                            onValueChange = { v ->
                                val intVal = v.toIntOrNull()
                                if (intVal != null && index < counts.size) counts[index] = intVal
                            },
                            modifier = Modifier.width(100.dp),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                        )
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
            Button(
                onClick = { onSave(counts.joinToString(",")) },
                modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(14.dp)
            ) { Text("Save Periods", fontWeight = FontWeight.SemiBold) }
            Spacer(Modifier.height(32.dp))
        }
    }
}

fun formatMinsToTime(minutes: Int): String {
    val h = (minutes / 60) % 24
    val m = minutes % 60
    return String.format("%02d:%02d", h, m)
}

fun parseTimeToMins(time: String): Int {
    val parts = time.split(":")
    if (parts.size != 2) return 540
    val h = parts[0].toIntOrNull() ?: 9
    val m = parts[1].toIntOrNull() ?: 0
    return h * 60 + m
}
