package com.attendx.app.ui.screens.setup

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.ui.screens.settings.TimetableSetupSheet
import com.attendx.app.util.PeriodNotificationManager
import java.util.Calendar

@Composable
fun DailySetupPrompt(
    viewModel: DailySetupViewModel = hiltViewModel()
) {
    val lastPromptedDate by viewModel.lastPromptedDate.collectAsStateWithLifecycle()
    val todayStr = viewModel.getCurrentDateString()

    val collegeStartTimeMinutes by viewModel.collegeStartTimeMinutes.collectAsStateWithLifecycle(540)
    val collegeEndTimeMinutes by viewModel.collegeEndTimeMinutes.collectAsStateWithLifecycle(960)
    val periodDurationMinutes by viewModel.periodDurationMinutes.collectAsStateWithLifecycle(50)
    val lunchBreakDurationMinutes by viewModel.lunchBreakDurationMinutes.collectAsStateWithLifecycle(45)
    val lunchPeriodIndex by viewModel.lunchPeriodIndex.collectAsStateWithLifecycle(4)
    val periodsPerDayString by viewModel.periodsPerDayString.collectAsStateWithLifecycle("7,7,7,7,7,4")

    var showPrompt by remember { mutableStateOf(false) }
    var showOverrideSheet by remember { mutableStateOf(false) }

    val context = LocalContext.current

    LaunchedEffect(lastPromptedDate) {
        if (lastPromptedDate.isNotBlank() && lastPromptedDate != todayStr) {
            showPrompt = true
        } else if (lastPromptedDate.isEmpty()) {
            // First time launching app probably
            showPrompt = true
        }
    }

    // Determine default periods for today based on day of week
    val cal = Calendar.getInstance()
    var dow = cal.get(Calendar.DAY_OF_WEEK) - 2 // Monday = 0
    if (dow < 0) dow = 6 // Sunday
    val defaultVals = periodsPerDayString.split(",").map { it.toIntOrNull() ?: 7 }
    val defaultPeriodsToday = defaultVals.getOrElse(dow) { 7 }

    if (showPrompt) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Text(
                    text = "Daily Timetable Check",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Is today a Full Day following your normal timetable?",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    OutlinedButton(onClick = {
                        showPrompt = false
                        showOverrideSheet = true
                    }) {
                        Text("No, Customize")
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(onClick = {
                        viewModel.markPromptAsShown()
                        showPrompt = false
                        
                        // Schedule default notifications
                        PeriodNotificationManager.scheduleDailyAlarms(
                            context,
                            collegeStartTimeMinutes,
                            periodDurationMinutes,
                            lunchBreakDurationMinutes,
                            lunchPeriodIndex,
                            defaultPeriodsToday
                        )
                    }) {
                        Text("Yes, Full Day")
                    }
                }
            }
        }
    }

    if (showOverrideSheet) {
        // Reuse TimetableSetupSheet for today's override
        TimetableSetupSheet(
            initialStartMins = collegeStartTimeMinutes,
            initialEndMins = collegeEndTimeMinutes,
            initialPeriodMins = periodDurationMinutes,
            initialLunchMins = lunchBreakDurationMinutes,
            initialLunchIndex = lunchPeriodIndex,
            onSave = { start, end, period, lunch, lunchIdx ->
                // Do NOT save to viewmodel, just use for today's scheduling
                PeriodNotificationManager.scheduleDailyAlarms(
                    context,
                    start,
                    period,
                    lunch,
                    lunchIdx,
                    defaultPeriodsToday // ideally we'd ask for periods count for today too, but we can assume default or let them edit
                )
                viewModel.markPromptAsShown()
                showOverrideSheet = false
            },
            onDismiss = {
                showOverrideSheet = false
                showPrompt = true // Force them to pick something
            }
        )
    }
}
