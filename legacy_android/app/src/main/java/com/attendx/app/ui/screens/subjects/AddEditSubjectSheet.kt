package com.attendx.app.ui.screens.subjects

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.ui.theme.SubjectColors
import com.attendx.app.ui.util.toHexString

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditSubjectSheet(
    editingSubject: Subject?,
    onAdd: (String, String, String, String) -> Unit,
    onUpdate: (Subject) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var name by remember { mutableStateOf(editingSubject?.name ?: "") }
    var code by remember { mutableStateOf(editingSubject?.code ?: "") }
    var faculty by remember { mutableStateOf(editingSubject?.facultyName ?: "") }
    var selectedColor by remember {
        mutableStateOf(
            editingSubject?.colorHex?.let { hex ->
                SubjectColors.firstOrNull { it.toHexString() == hex } ?: SubjectColors[0]
            } ?: SubjectColors[0]
        )
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp)
        ) {
            Text(
                text = if (editingSubject != null) "Edit Subject" else "Add Subject",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(20.dp))

            OutlinedTextField(
                value = name, onValueChange = { name = it },
                label = { Text("Subject Name") },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp), singleLine = true
            )
            Spacer(Modifier.height(12.dp))

            OutlinedTextField(
                value = code, onValueChange = { code = it },
                label = { Text("Subject Code") },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp), singleLine = true
            )
            Spacer(Modifier.height(12.dp))

            OutlinedTextField(
                value = faculty, onValueChange = { faculty = it },
                label = { Text("Faculty Name") },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp), singleLine = true
            )
            Spacer(Modifier.height(16.dp))

            Text("Color", style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.height(8.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(SubjectColors) { color ->
                    FilterChip(
                        selected = selectedColor == color,
                        onClick = { selectedColor = color },
                        label = {},
                        leadingIcon = {
                            Surface(
                                modifier = Modifier.size(24.dp).clip(CircleShape),
                                color = color, content = {}
                            )
                        }
                    )
                }
            }
            Spacer(Modifier.height(24.dp))

            Button(
                onClick = {
                    if (name.isNotBlank()) {
                        val hex = selectedColor.toHexString()
                        if (editingSubject != null) {
                            onUpdate(editingSubject.copy(
                                name = name, code = code,
                                facultyName = faculty, colorHex = hex))
                        } else {
                            onAdd(name, code, faculty, hex)
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(14.dp)
            ) {
                Text(if (editingSubject != null) "Update" else "Add Subject",
                    fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}
