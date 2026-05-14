package com.attendx.app.ui.navigation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.attendx.app.ui.screens.analytics.AnalyticsScreen
import com.attendx.app.ui.screens.attendance.EditAttendanceScreen
import com.attendx.app.ui.screens.attendance.AttendanceHistoryScreen
import com.attendx.app.ui.screens.attendance.AttendanceEntryScreen
import com.attendx.app.ui.screens.attendance.AttendanceScreen
import com.attendx.app.ui.screens.dashboard.DashboardScreen
import com.attendx.app.ui.screens.settings.SettingsScreen
import com.attendx.app.ui.screens.splash.SplashScreen
import com.attendx.app.ui.screens.subjects.SubjectScreen
import com.attendx.app.ui.screens.timetable.TimetableScreen

@Composable
fun NavGraph(
    navController: NavHostController,
    darkMode: Boolean,
    onToggleDarkMode: (Boolean) -> Unit
) {
    NavHost(
        navController = navController,
        startDestination = Screen.Splash.route,
        enterTransition = {
            fadeIn(animationSpec = tween(300)) +
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Start, tween(300))
        },
        exitTransition = {
            fadeOut(animationSpec = tween(300)) +
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.Start, tween(300))
        },
        popEnterTransition = {
            fadeIn(animationSpec = tween(300)) +
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.End, tween(300))
        },
        popExitTransition = {
            fadeOut(animationSpec = tween(300)) +
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.End, tween(300))
        }
    ) {
        composable(Screen.Splash.route) {
            SplashScreen(
                onSplashComplete = {
                    navController.navigate(Screen.Dashboard.route) {
                        popUpTo(Screen.Splash.route) { inclusive = true }
                    }
                }
            )
        }

        composable(Screen.Dashboard.route) {
            DashboardScreen(
                onNavigateToSubjects = { navController.navigate(Screen.Subjects.route) },
                onNavigateToAttendanceEntry = { navController.navigate(Screen.AttendanceEntry.createRoute(com.attendx.app.ui.util.DateUtils.getTodayStartMillis())) },
                onNavigateToAnalytics = { navController.navigate(Screen.Analytics.route) }
            )
        }

        composable(Screen.Timetable.route) {
            TimetableScreen()
        }

        composable(Screen.Attendance.route) {
            AttendanceScreen(
                onNavigateToEntry = { navController.navigate(Screen.EditAttendance.createRoute(it ?: com.attendx.app.ui.util.DateUtils.getTodayStartMillis())) },
                onNavigateToHistory = { }
            )
        }

        composable(
            route = Screen.AttendanceEntry.route,
            arguments = listOf(androidx.navigation.navArgument("date") { type = androidx.navigation.NavType.StringType; nullable = true })
        ) {
            AttendanceEntryScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(
            route = Screen.EditAttendance.route,
            arguments = listOf(androidx.navigation.navArgument("date") { type = androidx.navigation.NavType.StringType; nullable = true })
        ) {
            EditAttendanceScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(Screen.AttendanceHistory.route) {
            AttendanceHistoryScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }

        composable(Screen.Analytics.route) {
            AnalyticsScreen(
                onNavigateToCalendar = { navController.navigate(Screen.Attendance.route) }
            )
        }

        composable(Screen.Settings.route) {
            SettingsScreen(
                darkMode = darkMode,
                onToggleDarkMode = onToggleDarkMode,
                onNavigateToHistory = { navController.navigate(Screen.AttendanceHistory.route) }
            )
        }

        composable(Screen.Subjects.route) {
            SubjectScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
