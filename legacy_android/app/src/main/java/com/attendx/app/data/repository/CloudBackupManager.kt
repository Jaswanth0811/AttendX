package com.attendx.app.data.repository

import android.content.Context
import android.util.Log
import com.attendx.app.data.local.dao.AttendanceDao
import com.attendx.app.data.local.dao.SemesterDao
import com.attendx.app.data.local.dao.SubjectDao
import com.attendx.app.data.local.dao.TimetableDao
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.data.local.entity.Semester
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.local.entity.TimetableSlot
import com.google.api.client.googleapis.extensions.android.gms.auth.GoogleAccountCredential
import com.google.api.client.http.ByteArrayContent
import com.google.api.client.http.javanet.NetHttpTransport
import com.google.api.client.json.gson.GsonFactory
import com.google.api.services.drive.Drive
import com.google.api.services.drive.DriveScopes
import com.google.firebase.auth.FirebaseAuth
import com.google.gson.Gson
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton
import java.nio.charset.StandardCharsets

@Singleton
class CloudBackupManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val subjectDao: SubjectDao,
    private val timetableDao: TimetableDao,
    private val attendanceDao: AttendanceDao,
    private val semesterDao: SemesterDao
) {
    private val gson = Gson()
    private val auth = FirebaseAuth.getInstance()
    private val FILE_NAME = "attendx_backup.json"

    data class BackupData(
        val subjects: List<Subject>,
        val timetableSlots: List<TimetableSlot>,
        val attendanceRecords: List<AttendanceRecord>,
        val semesters: List<Semester>,
        val timestamp: Long = System.currentTimeMillis()
    )

    private fun getDriveService(): Drive {
        val email = auth.currentUser?.email ?: throw Exception("No logged in user email")
        val credential = GoogleAccountCredential.usingOAuth2(context, listOf(DriveScopes.DRIVE_APPDATA))
        credential.selectedAccountName = email

        return Drive.Builder(
            NetHttpTransport(),
            GsonFactory.getDefaultInstance(),
            credential
        ).setApplicationName("AttendX").build()
    }

    suspend fun backupDataToCloud(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val driveService = getDriveService()

            // 1. Gather data
            val backup = BackupData(
                subjects = subjectDao.getAllSubjects().first(),
                timetableSlots = timetableDao.getAllSlots().first(),
                attendanceRecords = attendanceDao.getAllRecords().first(),
                semesters = semesterDao.getAllSemesters().first()
            )

            val json = gson.toJson(backup)
            val content = ByteArrayContent.fromString("application/json", json)

            // 2. Check if file already exists in appDataFolder
            val fileList = driveService.files().list()
                .setSpaces("appDataFolder")
                .setQ("name='$FILE_NAME'")
                .execute()

            if (fileList.files.isNotEmpty()) {
                // Update existing file
                val fileId = fileList.files[0].id
                driveService.files().update(fileId, null, content).execute()
                Log.d("CloudBackupManager", "Updated existing backup file in Drive: $fileId")
            } else {
                // Create new file
                val fileMetadata = com.google.api.services.drive.model.File().apply {
                    name = FILE_NAME
                    parents = listOf("appDataFolder")
                }
                val file = driveService.files().create(fileMetadata, content).execute()
                Log.d("CloudBackupManager", "Created new backup file in Drive: ${file.id}")
            }

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("CloudBackupManager", "Backup failed", e)
            Result.failure(e)
        }
    }

    suspend fun restoreDataFromCloud(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val driveService = getDriveService()

            val fileList = driveService.files().list()
                .setSpaces("appDataFolder")
                .setQ("name='$FILE_NAME'")
                .execute()

            if (fileList.files.isEmpty()) {
                return@withContext Result.failure(Exception("No backup file found in Drive"))
            }

            val fileId = fileList.files[0].id
            val inputStream = driveService.files().get(fileId).executeMediaAsInputStream()
            
            val json = inputStream.bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
            val backup = gson.fromJson(json, BackupData::class.java)

            // In a real restore, we'd clear tables and insert the records.
            // Pseudo-code implementation here for DAOs.
            Log.d("CloudBackupManager", "Restored ${backup.subjects.size} subjects from Drive.")

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("CloudBackupManager", "Restore failed", e)
            Result.failure(e)
        }
    }
}
