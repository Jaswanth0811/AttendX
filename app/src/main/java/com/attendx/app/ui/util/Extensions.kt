package com.attendx.app.ui.util

import androidx.compose.ui.graphics.Color

fun String.toComposeColor(): Color {
    return try {
        Color(android.graphics.Color.parseColor(this))
    } catch (e: Exception) {
        Color(0xFF4F46E5) // Default indigo
    }
}

fun Color.toHexString(): String {
    val red = (this.red * 255).toInt()
    val green = (this.green * 255).toInt()
    val blue = (this.blue * 255).toInt()
    return String.format("#%02X%02X%02X", red, green, blue)
}

fun Float.toPercentageString(): String {
    return "${String.format("%.1f", this)}%"
}

fun calculateAttendancePercentage(present: Int, total: Int): Float {
    return if (total > 0) (present.toFloat() / total.toFloat()) * 100f else 100f
}

fun calculateSafeBunks(attended: Int, total: Int, targetPercent: Float = 75f): Int {
    if (total == 0) return 0
    val currentPercent = calculateAttendancePercentage(attended, total)
    return if (currentPercent > targetPercent) {
        ((attended - (targetPercent / 100f) * total) / (targetPercent / 100f)).toInt()
    } else {
        0
    }
}

fun calculateClassesNeeded(attended: Int, total: Int, targetPercent: Float = 75f): Int {
    if (total == 0) return 0
    val currentPercent = calculateAttendancePercentage(attended, total)
    return if (currentPercent < targetPercent) {
        val needed = ((targetPercent / 100f * total - attended) / (1f - targetPercent / 100f))
        kotlin.math.ceil(needed.toDouble()).toInt()
    } else {
        0
    }
}
