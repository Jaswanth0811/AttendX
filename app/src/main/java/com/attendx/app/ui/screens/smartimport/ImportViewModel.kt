package com.attendx.app.ui.screens.smartimport

import android.graphics.Bitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.local.entity.TimetableSlot
import com.attendx.app.data.repository.SubjectRepository
import com.attendx.app.data.repository.TimetableRepository
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import java.io.InputStream
import org.apache.poi.ss.usermodel.WorkbookFactory
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.attendx.app.data.util.AIConfig
import com.google.ai.client.generativeai.GenerativeModel
import com.google.ai.client.generativeai.type.content
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper

data class ImportState(
    val isLoading: Boolean = false,
    val detectedSlots: List<PendingImportSlot> = emptyList(),
    val error: String? = null,
    val showSuccess: Boolean = false
)

data class PendingImportSlot(
    val subjectName: String,
    val dayOfWeek: Int,
    val startTime: String,
    val endTime: String,
    val isSelected: Boolean = true
)

@HiltViewModel
class ImportViewModel @Inject constructor(
    private val subjectRepository: SubjectRepository,
    private val timetableRepository: TimetableRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ImportState())
    val uiState: StateFlow<ImportState> = _uiState.asStateFlow()

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    fun processImage(bitmap: Bitmap) {
        // Option 1: AI Processing (Better)
        if (AIConfig.GEMINI_API_KEY != "YOUR_API_KEY_HERE") {
            processImageWithAI(bitmap)
        } else {
            // Option 2: Local OCR (Offline fallback)
            processImageLocal(bitmap)
        }
    }

    private fun processImageWithAI(bitmap: Bitmap) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                val generativeModel = GenerativeModel(
                    modelName = "gemini-1.5-flash",
                    apiKey = AIConfig.GEMINI_API_KEY
                )

                val prompt = content {
                    image(bitmap)
                    text("Extract the timetable from this image. Return a JSON array of objects with fields: 'subjectName', 'dayOfWeek' (1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday), 'startTime' (format HH:mm), 'endTime' (format HH:mm). Return only the JSON array, no extra text.")
                }

                val response = generativeModel.generateContent(prompt)
                val rawText = response.text ?: "[]"
                val jsonString = rawText.substringAfter("[").substringBeforeLast("]").let { "[$it]" }
                
                val typeToken = object : TypeToken<List<PendingImportSlot>>() {}.type
                val parsedSlots: List<PendingImportSlot> = Gson().fromJson(jsonString, typeToken)
                
                _uiState.update { it.copy(
                    isLoading = false,
                    detectedSlots = parsedSlots
                ) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = "AI Processing failed: ${e.message}. Falling back to local OCR...") }
                processImageLocal(bitmap)
            }
        }
    }

    private fun processImageLocal(bitmap: Bitmap) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                val image = InputImage.fromBitmap(bitmap, 0)
                val result = recognizer.process(image).await()
                
                // Smart parsing logic
                val parsedSlots = OCRParser.parseTimetable(result.text)
                
                _uiState.update { it.copy(
                    isLoading = false,
                    detectedSlots = parsedSlots
                ) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = "Local OCR failed: ${e.message}") }
            }
        }
    }

    fun processExcel(bytes: ByteArray) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                val workbook = WorkbookFactory.create(bytes.inputStream())
                val sheet = workbook.getSheetAt(0)
                val parsedSlots = mutableListOf<PendingImportSlot>()
                
                sheet.forEach { row ->
                    val subject = row.getCell(0)?.toString() ?: ""
                    val day = row.getCell(1)?.toString()?.toDoubleOrNull()?.toInt() ?: 1
                    val start = row.getCell(2)?.toString() ?: ""
                    val end = row.getCell(3)?.toString() ?: ""
                    
                    if (subject.length > 2) {
                        parsedSlots.add(
                            PendingImportSlot(
                                subjectName = subject,
                                dayOfWeek = day,
                                startTime = start,
                                endTime = end
                            )
                        )
                    }
                }
                _uiState.update { it.copy(isLoading = false, detectedSlots = parsedSlots) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = "Failed to parse Excel: ${e.message}") }
            }
        }
    }

    fun processPdf(bytes: ByteArray, context: android.content.Context) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                PDFBoxResourceLoader.init(context)
                val document = PDDocument.load(bytes)
                val stripper = PDFTextStripper()
                val text = stripper.getText(document)
                document.close()
                
                if (AIConfig.GEMINI_API_KEY != "YOUR_API_KEY_HERE") {
                    processTextWithAI(text)
                } else {
                    val parsedSlots = OCRParser.parseTimetable(text)
                    _uiState.update { it.copy(isLoading = false, detectedSlots = parsedSlots) }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = "Failed to parse PDF: ${e.message}") }
            }
        }
    }

    private fun processTextWithAI(text: String) {
        viewModelScope.launch {
            try {
                val generativeModel = GenerativeModel(
                    modelName = "gemini-1.5-flash",
                    apiKey = AIConfig.GEMINI_API_KEY
                )

                val prompt = "Extract the timetable from this text. Return a JSON array of objects with fields: 'subjectName', 'dayOfWeek' (1=Mon, 2=Tue, etc.), 'startTime' (HH:mm), 'endTime' (HH:mm). Text:\n$text"

                val response = generativeModel.generateContent(prompt)
                val rawText = response.text ?: "[]"
                val jsonString = rawText.substringAfter("[").substringBeforeLast("]").let { "[$it]" }
                
                val typeToken = object : TypeToken<List<PendingImportSlot>>() {}.type
                val parsedSlots: List<PendingImportSlot> = Gson().fromJson(jsonString, typeToken)
                
                _uiState.update { it.copy(
                    isLoading = false,
                    detectedSlots = parsedSlots
                ) }
            } catch (e: Exception) {
                val parsedSlots = OCRParser.parseTimetable(text)
                _uiState.update { it.copy(isLoading = false, detectedSlots = parsedSlots, error = "AI Parsing failed, used local instead.") }
            }
        }
    }

    fun processCsv(content: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                val lines = content.lines().filter { it.isNotBlank() }
                val parsedSlots = lines.mapNotNull { line ->
                    val parts = line.split(",").map { it.trim() }
                    if (parts.size >= 3) {
                        PendingImportSlot(
                            subjectName = parts[0],
                            dayOfWeek = parts[1].toIntOrNull() ?: 1,
                            startTime = parts[2],
                            endTime = parts.getOrNull(3) ?: ""
                        )
                    } else null
                }
                _uiState.update { it.copy(isLoading = false, detectedSlots = parsedSlots) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = "Failed to parse CSV: ${e.message}") }
            }
        }
    }

    fun toggleSlotSelection(index: Int) {
        _uiState.update { state ->
            val newList = state.detectedSlots.toMutableList()
            newList[index] = newList[index].copy(isSelected = !newList[index].isSelected)
            state.copy(detectedSlots = newList)
        }
    }

    fun confirmImport() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val selectedSlots = _uiState.value.detectedSlots.filter { it.isSelected }
                
                // 1. Get or create subjects
                val subjectMap = mutableMapOf<String, Long>()
                selectedSlots.map { it.subjectName }.distinct().forEach { name ->
                    val existing = subjectRepository.getSubjectByName(name)
                    if (existing != null) {
                        subjectMap[name] = existing.id
                    } else {
                        val newId = subjectRepository.insertSubject(
                            Subject(
                                name = name,
                                code = "",
                                facultyName = "",
                                colorHex = "#" + Integer.toHexString((Math.random() * 16777215).toInt())
                            )
                        )
                        subjectMap[name] = newId
                    }
                }

                // 2. Insert timetable slots
                selectedSlots.forEach { slot ->
                    timetableRepository.insertSlot(
                        TimetableSlot(
                            dayOfWeek = slot.dayOfWeek,
                            periodNumber = 0, // We'll calculate or use time-based ordering
                            startTime = slot.startTime,
                            endTime = slot.endTime,
                            subjectId = subjectMap[slot.subjectName]
                        )
                    )
                }

                _uiState.update { it.copy(isLoading = false, showSuccess = true, detectedSlots = emptyList()) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = "Import failed: ${e.message}") }
            }
        }
    }
    
    fun resetState() {
        _uiState.update { ImportState() }
    }
}
