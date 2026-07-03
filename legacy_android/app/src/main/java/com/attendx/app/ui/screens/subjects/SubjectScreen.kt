package com.attendx.app.ui.screens.subjects

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.attendx.app.ui.components.EmptyState
import com.attendx.app.ui.components.SubjectCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SubjectScreen(
    viewModel: SubjectViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    if (state.showAddSheet) {
        AddEditSubjectSheet(
            editingSubject = state.editingSubject,
            onAdd = { name, code, faculty, color ->
                viewModel.addSubject(name, code, faculty, color)
            },
            onUpdate = { viewModel.updateSubject(it) },
            onDismiss = { viewModel.hideSheet() }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Subjects", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { viewModel.showAddSheet() },
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Default.Add, "Add Subject",
                    tint = MaterialTheme.colorScheme.onPrimary)
            }
        }
    ) { padding ->
        if (state.subjects.isEmpty() && !state.isLoading) {
            EmptyState(
                icon = Icons.Default.MenuBook,
                title = "No Subjects Yet",
                message = "Add your subjects to start tracking attendance",
                modifier = Modifier.padding(padding)
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(state.subjects, key = { it.subject.id }) { item ->
                    SubjectCard(
                        subject = item.subject,
                        attendancePercent = item.percentage,
                        presentCount = item.presentCount,
                        totalCount = item.totalCount,
                        onEdit = { viewModel.showEditSheet(item.subject) },
                        onDelete = { viewModel.deleteSubject(item.subject) }
                    )
                }
                item { Spacer(Modifier.height(80.dp)) }
            }
        }
    }
}
