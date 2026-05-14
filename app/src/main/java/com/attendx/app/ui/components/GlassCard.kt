package com.attendx.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.attendx.app.ui.theme.GlassBorder
import com.attendx.app.ui.theme.GlassWhite

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 20.dp,
    backgroundColor: Color? = null,
    content: @Composable BoxScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)
    val bgColor = backgroundColor ?: MaterialTheme.colorScheme.surface.copy(alpha = 0.7f)
    val gradient = Brush.verticalGradient(
        colors = listOf(
            GlassWhite,
            bgColor
        )
    )

    Box(
        modifier = modifier
            .clip(shape)
            .background(gradient)
            .border(
                width = 1.dp,
                color = GlassBorder,
                shape = shape
            )
            .padding(16.dp),
        content = content
    )
}

@Composable
fun GradientCard(
    modifier: Modifier = Modifier,
    colors: List<Color>,
    cornerRadius: Dp = 20.dp,
    content: @Composable BoxScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)
    val gradient = Brush.linearGradient(colors = colors)

    Box(
        modifier = modifier
            .clip(shape)
            .background(gradient)
            .padding(16.dp),
        content = content
    )
}
