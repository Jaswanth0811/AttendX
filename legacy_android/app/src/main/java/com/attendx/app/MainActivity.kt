package com.attendx.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.attendx.app.ui.components.BottomNavBar
import com.attendx.app.ui.navigation.NavGraph
import com.attendx.app.ui.navigation.Screen
import com.attendx.app.ui.theme.AttendXTheme
import com.attendx.app.util.PeriodNotificationManager
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.MutableStateFlow
import androidx.compose.runtime.collectAsState

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val intentFlow = MutableStateFlow<android.content.Intent?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intentFlow.value = intent
        PeriodNotificationManager.createNotificationChannel(this)
        enableEdgeToEdge()
        setContent {
            AttendXTheme {
                val currentIntent by intentFlow.collectAsState()
                AttendXMainScreen(currentIntent)
            }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intentFlow.value = intent
    }
}

@Composable
fun AttendXMainScreen(intent: android.content.Intent? = null) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val bottomNavScreens = listOf(
        Screen.Dashboard.route,
        Screen.Timetable.route,
        Screen.Attendance.route,
        Screen.Analytics.route,
        Screen.Settings.route
    )
    val showBottomBar = currentRoute in bottomNavScreens

    androidx.compose.runtime.LaunchedEffect(intent) {
        if (intent?.getStringExtra("navigate_to") == "attendance_entry") {
            navController.navigate(Screen.AttendanceEntry.createRoute(com.attendx.app.ui.util.DateUtils.getTodayStartMillis()))
        }
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            AnimatedVisibility(
                visible = showBottomBar,
                enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
                exit = slideOutVertically(targetOffsetY = { it }) + fadeOut()
            ) {
                BottomNavBar(
                    currentRoute = currentRoute,
                    onNavigate = { route ->
                        navController.navigate(route) {
                            popUpTo(Screen.Dashboard.route) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
        }
    ) { innerPadding ->
        Box(modifier = Modifier.padding(innerPadding)) {
            NavGraph(navController = navController)
        }
    }
}
