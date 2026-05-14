package com.attendx.app.data.repository

import android.content.Context
import android.content.SharedPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val prefs: SharedPreferences = context.getSharedPreferences("attendx_settings", Context.MODE_PRIVATE)
    
    private val _targetPercentage = MutableStateFlow(prefs.getFloat("target_percentage", 75f))
    val targetPercentage: StateFlow<Float> = _targetPercentage.asStateFlow()

    fun setTargetPercentage(target: Float) {
        prefs.edit().putFloat("target_percentage", target).apply()
        _targetPercentage.value = target
    }
}
