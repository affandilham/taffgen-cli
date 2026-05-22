import 'dart:convert';
import 'dart:io';
import '../utils/formatter.dart';

class TemplateParser {
  static Future<Map<String, Map<String, String>>> handleMarkdownOverride(
    String folderPath,
    String fileName,
    Map<String, dynamic> data,
    String packageName,
    List<String> filesToCleanup,
  ) async {
    final mdPath = '$folderPath/$fileName.md';
    final jsonPath = '$folderPath/$fileName.json';

    const encoder = JsonEncoder.withIndent('  ');
    File(jsonPath).writeAsStringSync(encoder.convert(data));
    filesToCleanup.add(jsonPath);

    var maxKeyLen = 16;
    for (final k in data.keys) {
      if (k.length > maxKeyLen) maxKeyLen = k.length;
    }

    final mdContent = '''
# 🛠️ TEMPLATE OVERRIDE CLASS FREEZED
Isi tabel di bawah ini untuk melakukan override tipe data atau converter. 
- Gunakan tanda `-` jika ingin menggunakan nilai bawaan otomatis (skip).
- Kolom **[Key JSON]** WAJIB DIISI jika Anda melakukan modifikasi pada baris tersebut.
- Simpan file ini, lalu kembali ke terminal dan tekan 'y'.

| ${'Key JSON (Wajib)'.padRight(maxKeyLen)} | Tipe Data Baru | Import Path Tipe Data | Nama Fungsi fromJson | Import Path fromJson | Nama Parameter Baru |
| ${'-' * maxKeyLen} | -------------- | --------------------- | -------------------- | -------------------- | ------------------- |
${data.keys.map((k) => '| ${k.padRight(maxKeyLen)} | -              | -                     | -                    | -                    | -                   |').join('\n')}
''';

    File(mdPath).writeAsStringSync(mdContent);
    filesToCleanup.add(mdPath);

    print('\n📝 Template Override telah dibuat di: $mdPath');
    stdout.write(
      'Silakan buka file .md tersebut di IDE, isi jika perlu, save, lalu ketik "y" dan Enter: ',
    );
    while (stdin.readLineSync()?.trim().toLowerCase() != 'y') {
      stdout.write('Ketik "y" jika sudah selesai: ');
    }

    final overrides = <String, Map<String, String>>{};
    final savedMd = File(mdPath).readAsLinesSync();

    for (final line in savedMd) {
      if (!line.startsWith('|') ||
          line.contains('---') ||
          line.contains('Key JSON')) {
        continue;
      }
      final parts = line.split('|').map((e) => e.trim()).toList();
      if (parts.length >= 7) {
        final key = parts[1];
        if (key == '-' || key.isEmpty) {
          continue;
        }

        // Jika kolom lain semua '-', berarti skip
        if (parts[2] == '-' &&
            parts[3] == '-' &&
            parts[4] == '-' &&
            parts[5] == '-' &&
            parts[6] == '-') {
          continue;
        }

        overrides[key] = {
          'tipe': parts[2],
          'importTipe': Formatter.formatImport(parts[3], packageName),
          'fromJsonFn': parts[4],
          'importFromJson': Formatter.formatImport(parts[5], packageName),
          'namaParam': parts[6],
        };
      }
    }
    return overrides;
  }
}
