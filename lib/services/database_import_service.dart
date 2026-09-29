import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/db_helper.dart';

class SqlImportResult {
  final bool success;
  final int statementsExecuted;
  final List<String> tablesAffected;
  final String message;
  final String? errorMessage;
  final Duration duration;
  final String fileName;
  final int fileSizeBytes;

  const SqlImportResult({
    required this.success,
    required this.statementsExecuted,
    required this.tablesAffected,
    required this.message,
    this.errorMessage,
    required this.duration,
    required this.fileName,
    required this.fileSizeBytes,
  });

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class DatabaseImportService {
  static final DatabaseImportService _instance = DatabaseImportService._internal();
  factory DatabaseImportService() => _instance;
  DatabaseImportService._internal();

  /// Parse a raw SQL script into distinct executable SQL statements.
  /// Handles single-line comments (--), block comments (/* */),
  /// and ignores semicolons inside single or double-quoted strings.
  static List<String> parseSqlStatements(String sql) {
    final List<String> statements = [];
    final StringBuffer current = StringBuffer();

    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    bool inLineComment = false;
    bool inBlockComment = false;

    final length = sql.length;
    for (int i = 0; i < length; i++) {
      final char = sql[i];
      final nextChar = (i + 1 < length) ? sql[i + 1] : '';

      // Check comments
      if (!inSingleQuote && !inDoubleQuote) {
        if (!inLineComment && !inBlockComment) {
          if (char == '-' && nextChar == '-') {
            inLineComment = true;
            i++; // skip next -
            continue;
          }
          if (char == '#' && (i == 0 || sql[i - 1] == '\n' || sql[i - 1] == ' ')) {
            inLineComment = true;
            continue;
          }
          if (char == '/' && nextChar == '*') {
            inBlockComment = true;
            i++; // skip next *
            continue;
          }
        } else if (inLineComment) {
          if (char == '\n' || char == '\r') {
            inLineComment = false;
          }
          continue;
        } else if (inBlockComment) {
          if (char == '*' && nextChar == '/') {
            inBlockComment = false;
            i++; // skip next /
          }
          continue;
        }
      }

      if (inLineComment || inBlockComment) continue;

      // Handle quotes
      if (char == "'" && !inDoubleQuote) {
        // SQLite escaped single quote is ''
        if (inSingleQuote && nextChar == "'") {
          current.write("''");
          i++; // skip escaped quote
          continue;
        }
        inSingleQuote = !inSingleQuote;
        current.write(char);
        continue;
      }

      if (char == '"' && !inSingleQuote) {
        if (inDoubleQuote && nextChar == '"') {
          current.write('""');
          i++;
          continue;
        }
        inDoubleQuote = !inDoubleQuote;
        current.write(char);
        continue;
      }

      // Check statement boundary
      if (char == ';' && !inSingleQuote && !inDoubleQuote) {
        final stmt = current.toString().trim();
        if (stmt.isNotEmpty) {
          statements.add(stmt);
        }
        current.clear();
        continue;
      }

      current.write(char);
    }

    final trailing = current.toString().trim();
    if (trailing.isNotEmpty) {
      statements.add(trailing);
    }

    return statements;
  }

  /// Import and execute a `.sql` script from raw text.
  Future<SqlImportResult> importSqlScript({
    required String sqlContent,
    String fileName = 'imported_script.sql',
    int fileSizeBytes = 0,
  }) async {
    final stopwatch = Stopwatch()..start();
    final statements = parseSqlStatements(sqlContent);

    if (statements.isEmpty) {
      return SqlImportResult(
        success: false,
        statementsExecuted: 0,
        tablesAffected: [],
        message: 'No executable SQL statements found in file.',
        errorMessage: 'The SQL file appears empty or only contains comments.',
        duration: stopwatch.elapsed,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      );
    }

    final db = await DbHelper().database;
    final Set<String> tablesAffected = {};
    int executed = 0;

    try {
      await db.transaction((txn) async {
        for (final stmt in statements) {
          final trimmed = stmt.trim();
          if (trimmed.isEmpty) continue;

          final upper = trimmed.toUpperCase();
          // Skip redundant transaction boundary commands since we are inside a txn
          if (upper.startsWith('BEGIN TRANSACTION') ||
              upper.startsWith('BEGIN;') ||
              upper.startsWith('COMMIT') ||
              upper.startsWith('ROLLBACK')) {
            continue;
          }

          // Detect table name from statement for reporting
          final tableMatch = RegExp(
            r'\b(?:INTO|FROM|TABLE|UPDATE)\s+([`"\[]?\w+[`"\]]?)',
            caseSensitive: false,
          ).firstMatch(trimmed);
          if (tableMatch != null) {
            final tName = tableMatch.group(1)?.replaceAll(RegExp(r'[`"\[\]]'), '') ?? '';
            if (tName.isNotEmpty && !tName.toUpperCase().startsWith('SQLITE_')) {
              tablesAffected.add(tName);
            }
          }

          await txn.execute(trimmed);
          executed++;
        }
      });

      // Ensure product images and cache are consistent
      await DbHelper().ensureProductImagesOnDb(db);

      stopwatch.stop();
      return SqlImportResult(
        success: true,
        statementsExecuted: executed,
        tablesAffected: tablesAffected.toList()..sort(),
        message: 'Successfully executed $executed SQL statements.',
        duration: stopwatch.elapsed,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[DatabaseImportService] SQL Import error: $e');
      return SqlImportResult(
        success: false,
        statementsExecuted: executed,
        tablesAffected: tablesAffected.toList(),
        message: 'SQL Import failed: $e',
        errorMessage: e.toString(),
        duration: stopwatch.elapsed,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      );
    }
  }

  /// Import a `.sql` or `.db` / `.sqlite` file from disk.
  Future<SqlImportResult> importFile(File file) async {
    final stopwatch = Stopwatch()..start();
    if (!await file.exists()) {
      return SqlImportResult(
        success: false,
        statementsExecuted: 0,
        tablesAffected: [],
        message: 'File does not exist: ${file.path}',
        errorMessage: 'File not found',
        duration: stopwatch.elapsed,
        fileName: p.basename(file.path),
        fileSizeBytes: 0,
      );
    }

    final fileName = p.basename(file.path);
    final ext = p.extension(file.path).toLowerCase();
    final fileBytes = await file.length();

    // 1. Binary SQLite Database (.db or .sqlite)
    if (ext == '.db' || ext == '.sqlite' || ext == '.sqlite3') {
      return await _importBinaryDatabaseFile(file);
    }

    // 2. SQL text script (.sql, .txt, etc.)
    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (_) {
      try {
        content = await file.readAsString(encoding: latin1);
      } catch (e) {
        return SqlImportResult(
          success: false,
          statementsExecuted: 0,
          tablesAffected: [],
          message: 'Unable to decode SQL file: $e',
          errorMessage: e.toString(),
          duration: stopwatch.elapsed,
          fileName: fileName,
          fileSizeBytes: fileBytes,
        );
      }
    }

    return await importSqlScript(
      sqlContent: content,
      fileName: fileName,
      fileSizeBytes: fileBytes,
    );
  }

  /// Replace active SQLite database with an imported .db file safely
  Future<SqlImportResult> _importBinaryDatabaseFile(File file) async {
    final stopwatch = Stopwatch()..start();
    final fileName = p.basename(file.path);
    final fileBytes = await file.length();

    if (fileBytes < 100) {
      return SqlImportResult(
        success: false,
        statementsExecuted: 0,
        tablesAffected: [],
        message: 'Invalid SQLite database file: file size too small ($fileBytes bytes).',
        errorMessage: 'File too small',
        duration: stopwatch.elapsed,
        fileName: fileName,
        fileSizeBytes: fileBytes,
      );
    }

    // Verify SQLite 3 header: "SQLite format 3\000"
    final headerBytes = await file.openRead(0, 16).first;
    const sqliteHeader = [83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0];
    bool isValidHeader = headerBytes.length >= 16;
    if (isValidHeader) {
      for (int i = 0; i < 16; i++) {
        if (headerBytes[i] != sqliteHeader[i]) {
          isValidHeader = false;
          break;
        }
      }
    }

    if (!isValidHeader) {
      return SqlImportResult(
        success: false,
        statementsExecuted: 0,
        tablesAffected: [],
        message: 'Invalid SQLite database file: header signature does not match SQLite 3 format.',
        errorMessage: 'Invalid SQLite 3 header',
        duration: stopwatch.elapsed,
        fileName: fileName,
        fileSizeBytes: fileBytes,
      );
    }

    try {
      final dbPath = await getDatabasesPath();
      final targetPath = p.join(dbPath, 'omni_pos.db');

      // Backup current active database first
      final currentFile = File(targetPath);
      if (await currentFile.exists()) {
        final backupPath = p.join(
          dbPath,
          'omni_pos_pre_import_${DateTime.now().millisecondsSinceEpoch}.bak',
        );
        await currentFile.copy(backupPath);
      }

      // Close current active database
      await DbHelper().closeDatabase();

      // Copy imported file to active database path
      await file.copy(targetPath);

      // Reopen and verify
      final db = await DbHelper().database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();

      await DbHelper().ensureProductImagesOnDb(db);

      stopwatch.stop();
      return SqlImportResult(
        success: true,
        statementsExecuted: tables.length,
        tablesAffected: tableNames..sort(),
        message: 'SQLite database restored successfully! Loaded ${tableNames.length} tables.',
        duration: stopwatch.elapsed,
        fileName: fileName,
        fileSizeBytes: fileBytes,
      );
    } catch (e) {
      stopwatch.stop();
      return SqlImportResult(
        success: false,
        statementsExecuted: 0,
        tablesAffected: [],
        message: 'Failed to import SQLite database: $e',
        errorMessage: e.toString(),
        duration: stopwatch.elapsed,
        fileName: fileName,
        fileSizeBytes: fileBytes,
      );
    }
  }

  /// Export current database schema and records as an executable `.sql` script dump.
  Future<File> exportSqlDump({Directory? destinationDir}) async {
    final db = await DbHelper().database;
    final buffer = StringBuffer();

    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final fileTimestamp = DateFormat('yyyyMMdd_HHmmss').format(now);

    buffer.writeln('-- ==============================================================');
    buffer.writeln('-- CA SOLUTION POS Database Export');
    buffer.writeln('-- Export Date: $timestamp');
    buffer.writeln('-- Engine: SQLite 3');
    buffer.writeln('-- ==============================================================');
    buffer.writeln();
    buffer.writeln('PRAGMA foreign_keys = OFF;');
    buffer.writeln();

    // Query all tables
    final tables = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;",
    );

    for (final table in tables) {
      final tableName = table['name'] as String;
      final createSql = table['sql'] as String?;

      if (createSql != null && createSql.trim().isNotEmpty) {
        buffer.writeln('-- Table structure for $tableName');
        buffer.writeln('DROP TABLE IF EXISTS "$tableName";');
        buffer.writeln('$createSql;');
        buffer.writeln();
      }

      // Query table rows
      final rows = await db.query(tableName);
      if (rows.isNotEmpty) {
        buffer.writeln('-- Data dump for $tableName (${rows.length} rows)');
        for (final row in rows) {
          final columns = row.keys.map((k) => '"$k"').join(', ');
          final values = row.values.map((v) {
            if (v == null) return 'NULL';
            if (v is num) return v.toString();
            final str = v.toString().replaceAll("'", "''");
            return "'$str'";
          }).join(', ');
          buffer.writeln('INSERT INTO "$tableName" ($columns) VALUES ($values);');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('PRAGMA foreign_keys = ON;');
    buffer.writeln('-- End of POS SQL Dump');

    final dir = destinationDir ?? await _getDefaultBackupDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final exportFile = File(p.join(dir.path, 'pos_backup_$fileTimestamp.sql'));
    await exportFile.writeAsString(buffer.toString(), flush: true);
    return exportFile;
  }

  /// Export the raw SQLite `.db` binary file
  Future<File> exportDatabaseBinary({Directory? destinationDir}) async {
    final dbPath = await getDatabasesPath();
    final sourceFile = File(p.join(dbPath, 'omni_pos.db'));

    final now = DateTime.now();
    final fileTimestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final dir = destinationDir ?? await _getDefaultBackupDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final targetFile = File(p.join(dir.path, 'omni_pos_backup_$fileTimestamp.db'));
    return await sourceFile.copy(targetFile.path);
  }

  Future<Directory> _getDefaultBackupDirectory() async {
    try {
      if (Platform.isWindows) {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          return Directory(p.join(downloads.path, 'POS_Backups'));
        }
      } else if (Platform.isAndroid) {
        final androidDownload = Directory('/storage/emulated/0/Download/POS_Backups');
        if (await androidDownload.parent.exists()) {
          return androidDownload;
        }
      }
    } catch (_) {}

    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'POS_Backups'));
  }
}
