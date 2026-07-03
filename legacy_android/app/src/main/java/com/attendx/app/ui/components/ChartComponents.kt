package com.attendx.app.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

data class BarChartData(val label: String, val value: Float, val color: Color)
data class PieChartData(val label: String, val value: Float, val color: Color)

@Composable
fun BarChart(
    data: List<BarChartData>,
    modifier: Modifier = Modifier,
    maxValue: Float = 100f,
    barWidth: Dp = 32.dp,
    chartHeight: Dp = 200.dp
) {
    var animProgress by remember { mutableFloatStateOf(0f) }
    val animatedProgress by animateFloatAsState(
        targetValue = animProgress,
        animationSpec = tween(1000, easing = FastOutSlowInEasing),
        label = "bar_anim"
    )
    LaunchedEffect(data) { animProgress = 1f }

    Column(modifier = modifier.fillMaxWidth()) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(chartHeight)
        ) {
            if (data.isEmpty()) return@Canvas
            val spacing = (size.width - data.size * barWidth.toPx()) / (data.size + 1)
            val maxH = size.height - 30f

            data.forEachIndexed { i, item ->
                val x = spacing + i * (barWidth.toPx() + spacing)
                val barH = (item.value / maxValue) * maxH * animatedProgress
                val y = size.height - 30f - barH

                drawRoundRect(
                    color = item.color.copy(alpha = 0.15f),
                    topLeft = Offset(x, 0f),
                    size = Size(barWidth.toPx(), maxH),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(8f)
                )
                drawRoundRect(
                    color = item.color,
                    topLeft = Offset(x, y),
                    size = Size(barWidth.toPx(), barH),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(8f)
                )

                drawContext.canvas.nativeCanvas.drawText(
                    "${item.value.toInt()}%",
                    x + barWidth.toPx() / 2,
                    y - 8f,
                    android.graphics.Paint().apply {
                        textAlign = android.graphics.Paint.Align.CENTER
                        textSize = 24f
                        color = item.color.hashCode()
                    }
                )
            }
        }
        Spacer(modifier = Modifier.height(4.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            data.forEach {
                Text(it.label, style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 10.sp)
            }
        }
    }
}

@Composable
fun PieChart(
    data: List<PieChartData>,
    modifier: Modifier = Modifier,
    chartSize: Dp = 180.dp,
    strokeWidth: Dp = 30.dp
) {
    var animProgress by remember { mutableFloatStateOf(0f) }
    val animatedProgress by animateFloatAsState(
        targetValue = animProgress,
        animationSpec = tween(1200, easing = FastOutSlowInEasing),
        label = "pie_anim"
    )
    LaunchedEffect(data) { animProgress = 1f }

    val total = data.sumOf { it.value.toDouble() }.toFloat()
    if (total == 0f) return

    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(chartSize)) {
            Canvas(modifier = Modifier.size(chartSize)) {
                var startAngle = -90f
                data.forEach { item ->
                    val sweep = (item.value / total) * 360f * animatedProgress
                    drawArc(
                        color = item.color,
                        startAngle = startAngle,
                        sweepAngle = sweep,
                        useCenter = false,
                        style = Stroke(width = strokeWidth.toPx(), cap = StrokeCap.Butt)
                    )
                    startAngle += sweep
                }
            }
        }
        Spacer(modifier = Modifier.width(20.dp))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            data.forEach { item ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Canvas(modifier = Modifier.size(10.dp)) {
                        drawCircle(color = item.color)
                    }
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        "${item.label}: ${item.value.toInt()}",
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
        }
    }
}
