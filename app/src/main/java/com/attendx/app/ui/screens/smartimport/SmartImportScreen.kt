package com.attendx.app.ui.screens.smartimport

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.TableChart
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.result.launch
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.ui.util.DateUtils

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SmartImportScreen(
    viewModel: ImportViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val scrollState = rememberScrollState()
    val context = LocalContext.current

    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        if (bitmap != null) {
            viewModel.processImage(bitmap)
        }
    }

    val fileLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri ->
        if (uri != null) {
            val content = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
            if (content != null) {
                viewModel.processCsv(content)
            }
        }
    }

    // Success dialog
    if (state.showSuccess) {
        AlertDialog(
            onDismissRequest = { viewModel.resetState() },
            title = { Text("Import Successful") },
            text = { Text("All selected subjects and timetable slots have been added.") },
            confirmButton = {
                Button(onClick = { 
                    viewModel.resetState()
                    onNavigateBack()
                }) { Text("Done") }
            }
        )
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Smart Import", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Intro Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)
                ),
                shape = RoundedCornerShape(20.dp)
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Info, null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.width(12.dp))
                    Text(
                        "Automatically add your subjects and daily schedule by scanning a photo or uploading a file.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
            }

            Text(
                "Choose Import Method",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )

            // Method Cards
            ImportMethodCard(
                icon = Icons.Default.CameraAlt,
                title = "Scan Timetable Photo",
                subtitle = "Take a photo of your printed or handwritten timetable and let AI extract the details.",
                onClick = { cameraLauncher.launch() }
            )

            ImportMethodCard(
                icon = Icons.Default.Description,
                title = "Import CSV File",
                subtitle = "Upload a .csv file with your subject names and timings.",
                onClick = { fileLauncher.launch("text/comma-separated-values") }
            )
            
            // Preview Section
            AnimatedVisibility(
                visible = state.detectedSlots.isNotEmpty(),
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut()
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "Detected Slots (${state.detectedSlots.size})",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        TextButton(onClick = { viewModel.resetState() }) {
                            Text("Clear")
                        }
                    }

                    state.detectedSlots.forEachIndexed { index, slot ->
                        PendingSlotItem(
                            slot = slot,
                            onToggle = { viewModel.toggleSlotSelection(index) }
                        )
                    }

                    Spacer(Modifier.height(16.dp))

                    Button(
                        onClick = { viewModel.confirmImport() },
                        modifier = Modifier.fillMaxWidth().height(56.dp),
                        shape = RoundedCornerShape(16.dp),
                        enabled = !state.isLoading && state.detectedSlots.any { it.isSelected }
                    ) {
                        if (state.isLoading) {
                            CircularProgressIndicator(modifier = Modifier.size(24.dp), color = MaterialTheme.colorScheme.onPrimary)
                        } else {
                            Icon(Icons.Default.Check, null)
                            Spacer(Modifier.width(8.dp))
                            Text("Confirm & Save All", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            Spacer(Modifier.height(24.dp))

            // Instructions Card
            Text(
                "Tips for best results",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold
            )
            
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                TipRow("Ensure the photo is clear and well-lit.")
                TipRow("Subjects should be clearly written or printed.")
                TipRow("Times should follow common formats (e.g. 09:00 - 10:00).")
            }
        }
    }
}

@Composable
private fun ImportMethodCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier.padding(20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                modifier = Modifier.size(48.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
                }
            }
            Spacer(Modifier.width(16.dp))
            Column {
                Text(title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun PendingSlotItem(
    slot: PendingImportSlot,
    onToggle: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (slot.isSelected) 
                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f) 
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        )
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(checked = slot.isSelected, onCheckedChange = { onToggle() })
            Spacer(Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(slot.subjectName, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyLarge)
                Row {
                    Text(
                        DateUtils.dayOfWeekName(slot.dayOfWeek),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "${slot.startTime} - ${slot.endTime}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun TipRow(text: String) {
    Row(verticalAlignment = Alignment.Top) {
        Text("• ", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
        Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
