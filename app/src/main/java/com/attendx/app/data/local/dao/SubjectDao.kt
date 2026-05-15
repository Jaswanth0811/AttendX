package com.attendx.app.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.attendx.app.data.local.entity.Subject
import kotlinx.coroutines.flow.Flow

@Dao
interface SubjectDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(subject: Subject): Long

    @Update
    suspend fun update(subject: Subject)

    @Delete
    suspend fun delete(subject: Subject)

    @Query("SELECT * FROM subjects ORDER BY name ASC")
    fun getAllSubjects(): Flow<List<Subject>>

    @Query("SELECT * FROM subjects WHERE id = :id")
    suspend fun getSubjectById(id: Long): Subject?

    @Query("SELECT * FROM subjects WHERE id = :id")
    fun getSubjectByIdFlow(id: Long): Flow<Subject?>

    @Query("SELECT COUNT(*) FROM subjects")
    fun getSubjectCount(): Flow<Int>

    @Query("SELECT * FROM subjects WHERE name = :name LIMIT 1")
    suspend fun getSubjectByName(name: String): Subject?

    @Query("DELETE FROM subjects")
    suspend fun deleteAll()
}
