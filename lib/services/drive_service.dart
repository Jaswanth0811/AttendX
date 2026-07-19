import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class DriveService {
  static final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId: '1053631789111-8pupmk1jmsfujpbuhp5ifdcnr81oesun.apps.googleusercontent.com',
    scopes: [
      'email',
      drive.DriveApi.driveAppdataScope,
    ],
  );

  Future<drive.DriveApi?> _getDriveApi({bool silentOnly = false}) async {
    GoogleSignInAccount? account = await googleSignIn.signInSilently();
    if (account == null && !silentOnly) {
      account = await googleSignIn.signIn();
    }
    if (account == null) return null;

    final headers = await account.authHeaders;
    if (headers.isEmpty) {
      throw Exception('Could not get authentication headers. Ensure OAuth client ID is configured.');
    }
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  Future<String> _getBackupFileName() async {
    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();
    if (account != null && account.email.contains('@')) {
      final prefix = account.email.split('@').first;
      return '$prefix.db';
    }
    return 'attendx_database_backup.db';
  }

  Future<DateTime?> getBackupModifiedTime() async {
    try {
      final driveApi = await _getDriveApi(silentOnly: true);
      if (driveApi == null) return null;

      final fileName = await _getBackupFileName();
      var query = "name = '$fileName' and 'appDataFolder' in parents";
      var fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: query,
        $fields: 'files(id, modifiedTime)',
      );

      // Fallback to legacy file name
      if ((fileList.files == null || fileList.files!.isEmpty) && fileName != 'attendx_database_backup.db') {
        const legacyFileName = 'attendx_database_backup.db';
        query = "name = '$legacyFileName' and 'appDataFolder' in parents";
        fileList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: query,
          $fields: 'files(id, modifiedTime)',
        );
      }

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.modifiedTime;
      }
    } catch (e) {
      debugPrint("Failed to fetch backup modified time: $e");
    }
    return null;
  }

  Future<DateTime?> backupDatabase({bool silentOnly = false}) async {
    final driveApi = await _getDriveApi(silentOnly: silentOnly);
    if (driveApi == null) throw Exception("User didn't sign in.");

    final dbFolder = await getDatabasesPath();
    final dbPath = p.join(dbFolder, 'attendx_database');
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception("Database file not found.");
    }

    await DatabaseHelper().checkpoint();

    final fileName = await _getBackupFileName();
    final query = "name = '$fileName' and 'appDataFolder' in parents";
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: query,
      $fields: 'files(id, name)',
    );

    final drive.File fileToUpload = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder'];

    final media = drive.Media(dbFile.openRead(), dbFile.lengthSync());

    drive.File uploadedFile;
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final fileId = fileList.files!.first.id!;
      final updateFile = drive.File()..name = fileName;
      uploadedFile = await driveApi.files.update(
        updateFile,
        fileId,
        uploadMedia: media,
        $fields: 'id, name, modifiedTime',
      );
    } else {
      uploadedFile = await driveApi.files.create(
        fileToUpload,
        uploadMedia: media,
        $fields: 'id, name, modifiedTime',
      );
    }
    return uploadedFile.modifiedTime;
  }

  Future<DateTime?> restoreDatabase({bool silentOnly = false}) async {
    final driveApi = await _getDriveApi(silentOnly: silentOnly);
    if (driveApi == null) throw Exception("User didn't sign in.");

    final fileName = await _getBackupFileName();
    var query = "name = '$fileName' and 'appDataFolder' in parents";
    var fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: query,
      $fields: 'files(id, name, modifiedTime)',
    );

    // Fallback to legacy file name
    if ((fileList.files == null || fileList.files!.isEmpty) && fileName != 'attendx_database_backup.db') {
      const legacyFileName = 'attendx_database_backup.db';
      query = "name = '$legacyFileName' and 'appDataFolder' in parents";
      fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: query,
        $fields: 'files(id, name, modifiedTime)',
      );
    }

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception("No backup found on Google Drive.");
    }

    final file = fileList.files!.first;
    final fileId = file.id!;
    final drive.Media response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final dbFolder = await getDatabasesPath();
    final dbPath = p.join(dbFolder, 'attendx_database');
    final dbFile = File(dbPath);
    final walFile = File('${dbPath}-wal');
    final shmFile = File('${dbPath}-shm');

    await DatabaseHelper().closeDatabase();

    final sink = dbFile.openWrite();
    await response.stream.pipe(sink);
    await sink.close();
    
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    return file.modifiedTime;
  }
}
