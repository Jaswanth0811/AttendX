package com.attendx.app.ui.screens.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.TrendingDown
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.ui.components.AnimatedCircularProgress
import com.attendx.app.ui.components.AnimatedCounter
import com.attendx.app.ui.components.GlassCard
import com.attendx.app.ui.theme.AbsentRed
import com.attendx.app.ui.theme.PresentGreen
import com.attendx.app.ui.util.DateUtils
import com.attendx.app.ui.util.calculateSafeBunks
import com.attendx.app.ui.util.toComposeColor
import com.attendx.app.ui.screens.setup.DailySetupPrompt
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    viewModel: DashboardViewModel = hiltViewModel(),
    onNavigateToSubjects: () -> Unit,
    onNavigateToAttendanceEntry: () -> Unit,
    onNavigateToAnalytics: () -> Unit
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(rememberTopAppBarState())

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            LargeTopAppBar(
                title = { 
                    Text(
                        "Good ${getGreeting()}!", 
                        fontWeight = FontWeight.Bold,
                        letterSpacing = (-0.5).sp
                    ) 
                },
                scrollBehavior = scrollBehavior,
                colors = TopAppBarDefaults.largeTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    scrolledContainerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onNavigateToAttendanceEntry,
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
                shape = RoundedCornerShape(20.dp) // iOS style fab
            ) {
                Icon(Icons.Default.Add, "Mark Attendance")
                Spacer(Modifier.width(8.dp))
                Text("Mark", fontWeight = FontWeight.Bold)
            }
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header subtitle
            item {
                Text("Here's your attendance overview",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 4.dp))
            }
            
            // Daily Setup Alert
            item {
                DailySetupPrompt()
            }

            // Overall Progress Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(24.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer
                    )
                ) {
                        Row(
                            modifier = Modifier.padding(24.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            AnimatedCircularProgress(
                                percentage = state.overallPercentage,
                                size = 130.dp,
                                strokeWidth = 14.dp,
                                progressColor = when {
                                    state.totalClasses == 0 -> MaterialTheme.colorScheme.outline
                                    state.overallPercentage >= state.targetPercentage -> PresentGreen
                                    else -> AbsentRed
                                },
                                label = "Overall",
                                customText = if (state.totalClasses == 0) "—" else null
                            )
                            Spacer(Modifier.width(24.dp))
                            Column {
                                StatRow("Present Days", state.presentDays, PresentGreen)
                                Spacer(Modifier.height(8.dp))
                                StatRow("Absent Days", state.absentDays, AbsentRed)
                                Spacer(Modifier.height(8.dp))
                                StatRow("Total Days", state.totalDays,
                                    MaterialTheme.colorScheme.onSurfaceVariant)
                                Spacer(Modifier.height(12.dp))
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.LocalFireDepartment, null,
                                        Modifier.size(20.dp),
                                        tint = MaterialTheme.colorScheme.tertiary)
                                    Spacer(Modifier.width(4.dp))
                                    Text("${state.streak} day streak",
                                        style = MaterialTheme.typography.labelLarge,
                                        fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
            }

            // Today's Schedule
            item {
                Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween,
                    Alignment.CenterVertically) {
                    Text("Today's Schedule",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold)
                    Text(DateUtils.dayOfWeekName(DateUtils.getTodayDayOfWeek()),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary)
                }
            }

            item {
                if (state.todaySlots.isEmpty()) {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                    ) {
                        Text("No classes scheduled today 🎉",
                            modifier = Modifier.padding(24.dp),
                            style = MaterialTheme.typography.bodyLarge)
                    }
                } else {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        items(state.todaySlots) { slot ->
                            val subject = state.subjects.find { it.id == slot.subjectId }
                            PeriodCard(slot, subject)
                        }
                    }
                }
            }

            // Low Attendance Alerts
            if (state.lowAttendanceSubjects.isNotEmpty()) {
                item {
                    Text("⚠️ Low Attendance",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.error)
                }
                items(state.lowAttendanceSubjects) { info ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer
                        ),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Row(Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Warning, null,
                                tint = MaterialTheme.colorScheme.error)
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(info.subject.name,
                                    fontWeight = FontWeight.SemiBold)
                                Text("${info.percentage.toInt()}% — Need more classes",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onErrorContainer)
                            }
                        }
                    }
                }
            }

            // Quick Actions
            item {
                Row(Modifier.fillMaxWidth(), Arrangement.spacedBy(12.dp)) {
                    Card(
                        onClick = onNavigateToSubjects,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(20.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.secondaryContainer)
                    ) {
                        Column(Modifier.padding(16.dp)) {
                            Icon(Icons.Default.MenuBook, null,
                                tint = MaterialTheme.colorScheme.onSecondaryContainer)
                            Spacer(Modifier.height(8.dp))
                            Text("Subjects",
                                fontWeight = FontWeight.SemiBold)
                            Text("${state.subjects.size} added",
                                style = MaterialTheme.typography.bodySmall)
                        }
                    }
                    Card(
                        onClick = onNavigateToAnalytics,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(20.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.tertiaryContainer)
                    ) {
                        Column(Modifier.padding(16.dp)) {
                            Icon(Icons.Default.TrendingDown, null,
                                tint = MaterialTheme.colorScheme.onTertiaryContainer)
                            Spacer(Modifier.height(8.dp))
                            Text("Analytics",
                                fontWeight = FontWeight.SemiBold)
                            Text("View insights",
                                style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }

            // Safe Bunk Summary
            if (state.subjectAttendance.isNotEmpty()) {
                item {
                    Text("Safe Bunk Calculator",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold)
                }
                items(state.subjectAttendance.filter { it.totalCount > 0 }) { info ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Row(Modifier.padding(12.dp).fillMaxWidth(),
                            Arrangement.SpaceBetween,
                            Alignment.CenterVertically) {
                            Column {
                                Text(info.subject.name,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium)
                                Text("${info.percentage.toInt()}% attendance",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            if (info.percentage < state.targetPercentage) {
                                Text("🔴 Attend more!",
                                    style = MaterialTheme.typography.labelLarge,
                                    color = AbsentRed,
                                    fontWeight = FontWeight.Bold)
                            } else if (info.safeBunks > 0) {
                                Text("🟢 Can miss ${info.safeBunks}",
                                    style = MaterialTheme.typography.labelLarge,
                                    color = PresentGreen,
                                    fontWeight = FontWeight.Bold)
                            } else {
                                Text("🟢 On track",
                                    style = MaterialTheme.typography.labelLarge,
                                    color = PresentGreen,
                                    fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            item { Spacer(Modifier.height(80.dp)) }
        }
    }
}

@Composable
private fun StatRow(label: String, value: Int, color: androidx.compose.ui.graphics.Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).background(color, RoundedCornerShape(4.dp)))
        Spacer(Modifier.width(8.dp))
        Text(label, style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.width(8.dp))
        AnimatedCounter(value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun PeriodCard(
    slot: com.attendx.app.data.local.entity.TimetableSlot,
    subject: com.attendx.app.data.local.entity.Subject?
) {
    val color = subject?.colorHex?.toComposeColor()
        ?: MaterialTheme.colorScheme.surfaceVariant
    Card(
        modifier = Modifier.width(140.dp),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.15f))
    ) {
        Column(Modifier.padding(14.dp)) {
            Text("Period ${slot.periodNumber}",
                style = MaterialTheme.typography.labelSmall,
                color = color)
            Spacer(Modifier.height(4.dp))
            Text(subject?.name ?: "Free Period",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1)
            Text("${DateUtils.formatTime(slot.startTime)} - ${DateUtils.formatTime(slot.endTime)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

private fun getGreeting(): String {
    val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
    return when {
        hour < 12 -> "Morning"
        hour < 17 -> "Afternoon"
        else -> "Evening"
    }
}
