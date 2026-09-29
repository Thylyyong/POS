import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/services/database_import_service.dart';

void main() {
  test('DatabaseImportService.parseSqlStatements parses queries and ignores semicolons in quotes and comments', () {
    const sql = '''
    -- Initial comment
    CREATE TABLE test_table (id TEXT PRIMARY KEY, name TEXT);

    /* Block comment
       with multiple lines and ; semicolon inside */
    INSERT INTO test_table (id, name) VALUES ('1', 'Product; with semicolon');
    INSERT INTO test_table (id, name) VALUES ('2', 'It''s working; properly');

    # Shell style comment
    UPDATE test_table SET name = 'Updated; value' WHERE id = '1';
    ''';

    final statements = DatabaseImportService.parseSqlStatements(sql);
    expect(statements.length, 4);
    expect(statements[0], 'CREATE TABLE test_table (id TEXT PRIMARY KEY, name TEXT)');
    expect(statements[1], "INSERT INTO test_table (id, name) VALUES ('1', 'Product; with semicolon')");
    expect(statements[2], "INSERT INTO test_table (id, name) VALUES ('2', 'It''s working; properly')");
    expect(statements[3], "UPDATE test_table SET name = 'Updated; value' WHERE id = '1'");
  });
}
