package com.attendx.app.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "subjects")
data class Subject(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val code: String,
    val facultyName: String,
    val colorHex: String,
    val createdAt: Long = System.currentTimeMillis()
)
