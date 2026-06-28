package com.attendx.app.ui.theme

import androidx.compose.ui.graphics.Color

// iOS-inspired Primary palette - System Indigo / Blue vibe
val PrimaryLight = Color(0xFF007AFF) // System Blue
val OnPrimaryLight = Color(0xFFFFFFFF)
val PrimaryContainerLight = Color(0xFFE5F1FF)
val OnPrimaryContainerLight = Color(0xFF004080)

val PrimaryDark = Color(0xFF0A84FF)
val OnPrimaryDark = Color(0xFFFFFFFF)
val PrimaryContainerDark = Color(0xFF003066)
val OnPrimaryContainerDark = Color(0xFFCCE4FF)

// Secondary palette
val SecondaryLight = Color(0xFF5856D6) // System Indigo
val OnSecondaryLight = Color(0xFFFFFFFF)
val SecondaryContainerLight = Color(0xFFEFEFFB)
val OnSecondaryContainerLight = Color(0xFF2C2B6B)

val SecondaryDark = Color(0xFF5E5CE6)
val OnSecondaryDark = Color(0xFFFFFFFF)
val SecondaryContainerDark = Color(0xFF2F2E73)
val OnSecondaryContainerDark = Color(0xFFDFDFF7)

// Tertiary palette
val TertiaryLight = Color(0xFFFF9500) // System Orange
val OnTertiaryLight = Color(0xFFFFFFFF)
val TertiaryContainerLight = Color(0xFFFFF4E5)
val OnTertiaryContainerLight = Color(0xFF804A00)

val TertiaryDark = Color(0xFFFF9F0A)
val OnTertiaryDark = Color(0xFFFFFFFF)
val TertiaryContainerDark = Color(0xFF804F05)
val OnTertiaryContainerDark = Color(0xFFFFEAD0)

// Error palette
val ErrorLight = Color(0xFFFF3B30) // System Red
val OnErrorLight = Color(0xFFFFFFFF)
val ErrorContainerLight = Color(0xFFFFEBEA)
val OnErrorContainerLight = Color(0xFF801D18)

val ErrorDark = Color(0xFFFF453A)
val OnErrorDark = Color(0xFFFFFFFF)
val ErrorContainerDark = Color(0xFF80221D)
val OnErrorContainerDark = Color(0xFFFFECEB)

// Surfaces - Light (iOS style)
val BackgroundLight = Color(0xFFF2F2F7) // iOS grouped background
val OnBackgroundLight = Color(0xFF000000)
val SurfaceLight = Color(0xFFFFFFFF) // iOS Card
val OnSurfaceLight = Color(0xFF000000)
val SurfaceVariantLight = Color(0xFFFFFFFF)
val OnSurfaceVariantLight = Color(0xFF8E8E93) // iOS Secondary Label
val OutlineLight = Color(0xFFD1D1D6) // iOS Separator
val OutlineVariantLight = Color(0xFFE5E5EA)
val SurfaceContainerLight = Color(0xFFFFFFFF)
val SurfaceContainerHighLight = Color(0xFFF2F2F7)

// Surfaces - Dark (iOS style)
val BackgroundDark = Color(0xFF000000) // True black OLED
val OnBackgroundDark = Color(0xFFFFFFFF)
val SurfaceDark = Color(0xFF1C1C1E) // iOS Dark Card
val OnSurfaceDark = Color(0xFFFFFFFF)
val SurfaceVariantDark = Color(0xFF1C1C1E)
val OnSurfaceVariantDark = Color(0xFFEBEBF5).copy(alpha = 0.6f) // iOS Secondary Label
val OutlineDark = Color(0xFF38383A) // iOS Separator
val OutlineVariantDark = Color(0xFF2C2C2E)
val SurfaceContainerDark = Color(0xFF1C1C1E)
val SurfaceContainerHighDark = Color(0xFF2C2C2E)

// Attendance status colors (iOS standard green/red)
val PresentGreen = Color(0xFF34C759)
val AbsentRed = Color(0xFFFF3B30)
val CancelledGray = Color(0xFF8E8E93)
val SeminarPurple = Color(0xFFAF52DE)
val FreePeriodBlue = Color(0xFF32ADE6)

// Subject color options
val SubjectColors = listOf(
    Color(0xFF007AFF), // Blue
    Color(0xFFFF3B30), // Red
    Color(0xFF34C759), // Green
    Color(0xFFFF9500), // Orange
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF2D55), // Pink
    Color(0xFF32ADE6), // Cyan
    Color(0xFF5856D6), // Indigo
    Color(0xFFFFCC00), // Yellow
    Color(0xFF8E8E93)  // Gray
)

// Glass effect colors
val GlassWhite = Color(0x66FFFFFF)
val GlassBorder = Color(0x33FFFFFF)
val GlassDarkBg = Color(0x40000000)
