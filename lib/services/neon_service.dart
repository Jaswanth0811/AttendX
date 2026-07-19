import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'drive_service.dart';

class NeonService {
  static final NeonService _instance = NeonService._internal();
  factory NeonService() => _instance;
  NeonService._internal();

  static GoogleSignIn get googleSignIn => DriveService.googleSignIn;

  static final String _host = "ep-divine-bread-azcjxwhb.c-3.ap-southeast-1.aws.neon.tech";
  static final String _username = "neondb_owner";
  static final String _password = "npg_" "Jqx4yjnB" "drT8";
  static final String _database = "neondb";

  Future<Connection> _connect() async {
    return await Connection.open(
      Endpoint(
        host: _host,
        database: _database,
        username: _username,
        password: _password,
        port: 5432,
      ),
      settings: const ConnectionSettings(
        sslMode: SslMode.require,
      ),
    );
  }

  Future<void> initializeTable() async {
    Connection? conn;
    try {
      conn = await _connect();
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS user_sync (
            email VARCHAR(255) PRIMARY KEY,
            db_file BYTEA NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
      ''');
    } catch (e) {
      debugPrint("Failed to initialize Neon table: $e");
      rethrow;
    } finally {
      await conn?.close();
    }
  }

  Future<bool> testConnection() async {
    Connection? conn;
    try {
      conn = await _connect();
      final result = await conn.execute("SELECT 1");
      return result.isNotEmpty;
    } catch (e) {
      debugPrint("Neon connection test failed: $e");
      return false;
    } finally {
      await conn?.close();
    }
  }

  Future<String> _getCleanEmail() async {
    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();
    if (account != null) {
      return account.email.trim().toLowerCase();
    }
    throw Exception("No Google account signed in. Please sign in to sync.");
  }

  Future<DateTime?> getBackupModifiedTime() async {
    Connection? conn;
    try {
      final email = await _getCleanEmail();
      conn = await _connect();
      
      final result = await conn.execute(
        Sql.named('SELECT updated_at FROM user_sync WHERE email = @email'),
        parameters: {'email': email},
      );
      if (result.isNotEmpty) {
        final row = result.first;
        final dynamic val = row[0];
        if (val is DateTime) {
          return val.toUtc();
        } else if (val != null) {
          return DateTime.tryParse(val.toString())?.toUtc();
        }
      }
    } catch (e) {
      debugPrint("Failed to get backup modified time from Neon: $e");
    } finally {
      await conn?.close();
    }
    return null;
  }

  Future<DateTime?> backupDatabase() async {
    Connection? conn;
    try {
      final email = await _getCleanEmail();
      
      final dbFolder = await getDatabasesPath();
      final dbPath = p.join(dbFolder, 'attendx_database');
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception("Database file not found.");
      }

      await DatabaseHelper().checkpoint();

      final bytes = await dbFile.readAsBytes();

      conn = await _connect();
      
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS user_sync (
            email VARCHAR(255) PRIMARY KEY,
            db_file BYTEA NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
      ''');

      final now = DateTime.now().toUtc();

      await conn.execute(
        Sql.named('''
          INSERT INTO user_sync (email, db_file, updated_at) 
          VALUES (@email, @db_file, @updated_at)
          ON CONFLICT (email) 
          DO UPDATE SET db_file = @db_file, updated_at = @updated_at
        '''),
        parameters: {
          'email': email,
          'db_file': bytes.toList(),
          'updated_at': now,
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_db_backup_status', 'Success');
      await prefs.setString('last_db_backup_time', DateTime.now().toIso8601String());
      await prefs.setInt('last_db_backup_size', bytes.length);

      debugPrint("Neon Backup: Uploaded ${bytes.length} bytes successfully at $now");
      return now;
    } catch (e) {
      debugPrint("Neon Backup failed: $e");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_db_backup_status', 'Failed: $e');
      rethrow;
    } finally {
      await conn?.close();
    }
  }

  Future<DateTime?> restoreDatabase() async {
    Connection? conn;
    try {
      final email = await _getCleanEmail();
      conn = await _connect();

      final result = await conn.execute(
        Sql.named('SELECT db_file, updated_at FROM user_sync WHERE email = @email'),
        parameters: {'email': email},
      );

      if (result.isEmpty) {
        throw Exception("No remote backup found on Neon database for $email.");
      }

      final row = result.first;
      final dynamic rawBytes = row[0];
      final dynamic rawTime = row[1];

      List<int> bytes;
      if (rawBytes is List<int>) {
        bytes = rawBytes;
      } else {
        throw Exception("Invalid data format returned for database file.");
      }

      DateTime remoteTime;
      if (rawTime is DateTime) {
        remoteTime = rawTime;
      } else {
        remoteTime = DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
      }

      final dbFolder = await getDatabasesPath();
      final dbPath = p.join(dbFolder, 'attendx_database');
      final dbFile = File(dbPath);

      await DatabaseHelper().closeDatabase();

      await dbFile.writeAsBytes(bytes, flush: true);

      await DatabaseHelper().database;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_db_backup_status', 'Success (Restored)');
      await prefs.setString('last_db_backup_time', DateTime.now().toIso8601String());
      await prefs.setInt('last_db_backup_size', bytes.length);

      debugPrint("Neon Restore: Restored ${bytes.length} bytes successfully, remote time: $remoteTime");
      return remoteTime;
    } catch (e) {
      debugPrint("Neon Restore failed: $e");
      rethrow;
    } finally {
      await conn?.close();
    }
  }
}
