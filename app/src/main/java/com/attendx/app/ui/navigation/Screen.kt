package com.attendx.app.ui.navigation

sealed class Screen(val route: String) {
    data object Splash : Screen("splash")
    data object Dashboard : Screen("dashboard")
    data object Timetable : Screen("timetable")
    data object Attendance : Screen("attendance")
    data object AttendanceEntry : Screen("attendance_entry?date={date}") {
        fun createRoute(dateMillis: Long) = "attendance_entry?date=$dateMillis"
    }
    data object EditAttendance : Screen("edit_attendance?date={date}") {
        fun createRoute(dateMillis: Long) = "edit_attendance?date=$dateMillis"
    }
    data object AttendanceHistory : Screen("attendance_history")
    data object Analytics : Screen("analytics")
    data object Settings : Screen("settings")
    data object Subjects : Screen("subjects")
    data object SmartImport : Screen("smart_import")
}
