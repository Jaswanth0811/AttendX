package com.attendx.app.ui.screens.attendance

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.History
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.ui.components.EmptyState
import com.attendx.app.ui.theme.AbsentRed
import com.attendx.app.ui.theme.PresentGreen
import com.attendx.app.ui.util.DateUtils

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttendanceHistoryScreen(
    viewModel: AttendanceViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Attendance History", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background)
            )
        }
    ) { padding ->
        if (state.allRecords.isEmpty() && !state.isLoading) {
            EmptyState(
                icon = Icons.Default.History,
                title = "No History",
                message = "You have not marked any attendance yet.",
                modifier = Modifier.padding(padding)
            )
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Group records by Date
                val groupedRecords = state.allRecords.groupBy { it.date }.toSortedMap(reverseOrder())

                groupedRecords.forEach { (dateMillis, records) ->
                    item {
                        Text(
                            text = DateUtils.formatDate(dateMillis),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(top = 8.dp, bottom = 4.dp)
                        )
                    }

                    items(records) { record ->
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
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
                                        ?: (if (isHoliday) "Holiday" else "Unknown")
                                        
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
                    Spacer(Modifier.height(40.dp))
                }
            }
        }
    }
}
