package com.attendx.app.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.tween
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight

@Composable
fun AnimatedCounter(
    targetValue: Int,
    modifier: Modifier = Modifier,
    style: TextStyle = MaterialTheme.typography.headlineLarge,
    color: Color = MaterialTheme.colorScheme.onSurface,
    suffix: String = "",
    prefix: String = ""
) {
    var animTarget by remember { mutableIntStateOf(0) }
    val animatedValue by animateIntAsState(
        targetValue = animTarget,
        animationSpec = tween(1000, easing = FastOutSlowInEasing),
        label = "counter"
    )
    LaunchedEffect(targetValue) { animTarget = targetValue }

    Text(
        text = "$prefix$animatedValue$suffix",
        style = style,
        fontWeight = FontWeight.Bold,
        color = color,
        modifier = modifier
    )
}
