import 'dart:io';
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
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveFileScope,
    ],
  );

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = await googleSignIn.signIn();
    if (account == null) return null;

    final headers = await account.authHeaders;
    if (headers.isEmpty) {
      throw Exception('Could not get authentication headers. Ensure OAuth client ID is configured.');
    }
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  Future<void> backupDatabase() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception("User didn't sign in.");

    final dbFolder = await getDatabasesPath();
    final dbPath = p.join(dbFolder, 'attendx_database');
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception("Database file not found.");
    }

    // Force sqlite to flush WAL
    await DatabaseHelper().checkpoint();

    // Find existing backup
    final query = "name = 'attendx_database_backup.db' and 'appDataFolder' in parents";
    final fileList = await driveApi.files.list(spaces: 'appDataFolder', q: query);

    final drive.File fileToUpload = drive.File()
      ..name = 'attendx_database_backup.db'
      ..parents = ['appDataFolder'];

    final media = drive.Media(dbFile.openRead(), dbFile.lengthSync());

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final fileId = fileList.files!.first.id!;
      await driveApi.files.update(fileToUpload, fileId, uploadMedia: media);
    } else {
      await driveApi.files.create(fileToUpload, uploadMedia: media);
    }
  }

  Future<void> restoreDatabase() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception("User didn't sign in.");

    final query = "name = 'attendx_database_backup.db' and 'appDataFolder' in parents";
    final fileList = await driveApi.files.list(spaces: 'appDataFolder', q: query);

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception("No backup found on Google Drive.");
    }

    final fileId = fileList.files!.first.id!;
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
    
    // Remove WAL files so they don't corrupt the restored DB
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();
  }
}
