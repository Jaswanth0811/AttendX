package com.attendx.app.ui.screens.analytics

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.ui.components.AnimatedCircularProgress
import com.attendx.app.ui.components.AnimatedCounter
import com.attendx.app.ui.components.BarChart
import com.attendx.app.ui.components.BarChartData
import com.attendx.app.ui.components.PieChart
import com.attendx.app.ui.components.PieChartData
import com.attendx.app.ui.theme.AbsentRed
import com.attendx.app.ui.theme.CancelledGray
import com.attendx.app.ui.theme.PresentGreen
import com.attendx.app.ui.util.toComposeColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsScreen(
    viewModel: AnalyticsViewModel = hiltViewModel(),
    onNavigateToCalendar: () -> Unit
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Analytics", fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = onNavigateToCalendar) {
                        Icon(Icons.Default.CalendarMonth, "Calendar")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background)
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Overview Cards - Periods
            item {
                Text("Period Attendance", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("Total Classes", state.overallTotal, Modifier.weight(1f))
                    StatCard("Present", state.overallPresent, Modifier.weight(1f))
                    StatCard("Absent", state.overallAbsent, Modifier.weight(1f))
                }
            }

            // Overview Cards - Days
            item {
                Text("Day Attendance", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("Total Days", state.totalDays, Modifier.weight(1f))
                    StatCard("Present Days", state.presentDays, Modifier.weight(1f))
                    StatCard("Absent Days", state.absentDays, Modifier.weight(1f))
                }
            }

            // Overall Progress
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp)
                ) {
                    Column(
                        Modifier.padding(24.dp).fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text("Overall Attendance (Periods)",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold)
                        Spacer(Modifier.height(16.dp))
                        AnimatedCircularProgress(
                            percentage = state.overallPercentage,
                            size = 160.dp, strokeWidth = 16.dp,
                            progressColor = if (state.overallPercentage >= state.targetPercentage) PresentGreen else AbsentRed
                        )
                    }
                }
            }

            if (state.subjectStats.isNotEmpty()) {
                // Subject Detail Cards
                item {
                    Text("Subject Details",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold)
                }

                state.subjectStats.forEach { stat ->
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = stat.subject.colorHex.toComposeColor().copy(0.08f))
                        ) {
                            Row(Modifier.padding(14.dp).fillMaxWidth(),
                                Arrangement.SpaceBetween, Alignment.CenterVertically) {
                                Column {
                                    Text(stat.subject.name,
                                        fontWeight = FontWeight.SemiBold)
                                    Text("${stat.present}/${stat.total} classes",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(Modifier.height(4.dp))
                                    if (stat.total > 0) {
                                        if (stat.percentage < state.targetPercentage) {
                                            Text("🔴 Need ${stat.neededClasses} classes for ${state.targetPercentage.toInt()}%",
                                                style = MaterialTheme.typography.labelMedium,
                                                color = AbsentRed,
                                                fontWeight = FontWeight.SemiBold)
                                        } else {
                                            if (stat.safeBunks > 0) {
                                                Text("🟢 Can miss ${stat.safeBunks} classes",
                                                    style = MaterialTheme.typography.labelMedium,
                                                    color = PresentGreen,
                                                    fontWeight = FontWeight.SemiBold)
                                            } else {
                                                Text("🟢 On track (0 safe bunks)",
                                                    style = MaterialTheme.typography.labelMedium,
                                                    color = PresentGreen,
                                                    fontWeight = FontWeight.SemiBold)
                                            }
                                        }
                                    } else {
                                        Text("🟢 No classes recorded yet",
                                            style = MaterialTheme.typography.labelMedium,
                                            color = PresentGreen,
                                            fontWeight = FontWeight.SemiBold)
                                    }
                                }
                                Text(if (stat.total > 0) "${stat.percentage.toInt()}%" else "—",
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Bold,
                                    color = stat.subject.colorHex.toComposeColor())
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
private fun StatCard(label: String, value: Int, modifier: Modifier = Modifier) {
    Card(modifier = modifier, shape = RoundedCornerShape(16.dp)) {
        Column(Modifier.padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            AnimatedCounter(value, style = MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.height(2.dp))
            Text(label, style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
