package com.attendx.app.ui.screens.smartimport

import java.util.regex.Pattern

object OCRParser {
    
    private val DAYS = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    private val DAYS_SHORT = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    
    // Pattern to match times like 09:00, 9:00 AM, 10-11, etc.
    private val TIME_PATTERN = Pattern.compile("(\\d{1,2}[:.-]\\d{2})|(\\d{1,2}\\s?(?:AM|PM))", Pattern.CASE_INSENSITIVE)

    fun parseTimetable(text: String): List<PendingImportSlot> {
        val lines = text.lines().filter { it.isNotBlank() }
        val slots = mutableListOf<PendingImportSlot>()
        
        var currentDay = 1 // Default to Monday
        
        lines.forEach { line ->
            // Check if line contains a day name
            val dayIndex = findDayIndex(line)
            if (dayIndex != -1) {
                currentDay = dayIndex + 1
            }
            
            // Try to extract subject and time from the line
            val times = extractTimes(line)
            if (times.isNotEmpty()) {
                // If we found times, the rest of the line might be the subject
                val subjectName = cleanSubjectName(line, times)
                if (subjectName.length > 2) {
                    slots.add(
                        PendingImportSlot(
                            subjectName = subjectName,
                            dayOfWeek = currentDay,
                            startTime = times.getOrNull(0) ?: "09:00",
                            endTime = times.getOrNull(1) ?: "10:00"
                        )
                    )
                }
            } else if (line.length > 3 && !isDayName(line)) {
                // Potential subject line without time (maybe time was on previous line?)
                // For now, let's just assume it's a subject if it's not a day
            }
        }
        
        return slots
    }

    private fun findDayIndex(text: String): Int {
        DAYS.forEachIndexed { index, day ->
            if (text.contains(day, ignoreCase = true)) return index
        }
        DAYS_SHORT.forEachIndexed { index, day ->
            if (text.contains(day, ignoreCase = true)) return index
        }
        return -1
    }

    private fun isDayName(text: String): Boolean = findDayIndex(text) != -1

    private fun extractTimes(text: String): List<String> {
        val times = mutableListOf<String>()
        val matcher = TIME_PATTERN.matcher(text)
        while (matcher.find()) {
            times.add(matcher.group())
        }
        return times
    }

    private fun cleanSubjectName(line: String, times: List<String>): String {
        var clean = line
        // Remove times
        times.forEach { clean = clean.replace(it, "", ignoreCase = true) }
        // Remove day names
        DAYS.forEach { clean = clean.replace(it, "", ignoreCase = true) }
        DAYS_SHORT.forEach { clean = clean.replace(it, "", ignoreCase = true) }
        // Remove common separators
        clean = clean.replace(Regex("[:\\-–]"), " ")
        return clean.trim().split(" ").firstOrNull { it.length > 2 } ?: clean.trim()
    }
}
