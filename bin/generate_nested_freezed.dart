import 'dart:convert';
import 'dart:io';
import 'dart:async';

// --- KONFIGURASI GLOBAL ---
String packageName = '';
bool autoNamingMode = true;
List<String> filesToCleanup = [];
List<String> generatedDartFiles = [];

const String currentVersion = '1.0.0';
// Pastikan file version.txt di repositori cloud Anda HANYA berisi angka versi (contoh: 1.0.1)
const String versionUrl =
    'https://raw.githubusercontent.com/[NAMA_ORGANISASI]/taffgen-cli/main/version.txt';

Future<void> checkUpdate() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

    final request = await client.getUrl(Uri.parse(versionUrl));
    final response = await request.close();

    if (response.statusCode == 200) {
      final latestVersion = await response.transform(utf8.decoder).join();
      final cleanLatest = latestVersion.trim();

      if (cleanLatest.isNotEmpty && cleanLatest != currentVersion) {
        stdout
          ..writeln(
            '\n🌟 ====================================================== 🌟',
          )
          ..writeln(
            '🚀 [UPDATE TERSEDIA] Versi CLI terbaru ($cleanLatest) telah rilis!',
          )
          ..writeln('Versi Anda saat ini: $currentVersion')
          ..writeln('Jalankan perintah ini di terminal untuk memperbarui:')
          ..writeln(
            'dart pub global activate --source git https://github.com/[NAMA_ORGANISASI]/taffgen-cli.git',
          )
          ..writeln(
            '🌟 ====================================================== 🌟\n',
          );
      }
    }
  } catch (e) {
    // Silent fail: Jika tidak ada internet atau gagal fetch, abaikan saja dan lanjut.
  }
}

void main(List<String> args) async {
  if (args.contains('--version') || args.contains('-v')) {
    stdout.writeln('📦 TaffGen CLI Version: $currentVersion');
    return;
  }

  if (args.contains('--uninstall')) {
    stdout.writeln(
      '\n🗑️  Memulai proses uninstall TaffGen CLI dari device Anda...',
    );

    final process = await Process.run('dart', [
      'pub',
      'global',
      'deactivate',
      'voltunes_cli',
    ]);

    if (process.exitCode == 0) {
      stdout.writeln('✅ TaffGen CLI berhasil dihapus sepenuhnya dari lokal.');
      stdout.writeln('Sampai jumpa lagi! 👋\n');
    } else {
      stdout.writeln('⚠️ Gagal menghapus CLI:\n${process.stderr}');
    }
    return;
  }

  print('🚀 INIT TAFF CLI FREEZED GENERATOR...\n');

  await checkUpdate();

  // 1. Deteksi Package Name dari pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    final pubspecContent = pubspecFile.readAsStringSync();
    final nameMatch = RegExp(
      r'^name:\s*(.+)$',
      multiLine: true,
    ).firstMatch(pubspecContent);
    if (nameMatch != null) {
      packageName = nameMatch.group(1)!.trim();
    }
  }

  if (packageName.isEmpty) {
    print(
      '⚠️ Gagal mendeteksi nama package dari pubspec.yaml. Masukkan manual:',
    );
    final pkgInput = stdin.readLineSync()?.trim();
    packageName = (pkgInput != null && pkgInput.isNotEmpty) ? pkgInput : 'app';
  }

  print('📦 Package: $packageName');
  print(
    '📂 Workspace: ${Directory.current.path.split(Platform.pathSeparator).last}\n',
  );

  // 2. Global Workflow Config
  print('⚙️  MODE WORKFLOW GENERATOR');
  print('1. Default');
  print(
    '2. Override (Kontrol penuh untuk kustomisasi nama file, nama parameter, tipe data, dan fromJson)',
  );
  stdout.write('Pilih mode (1/2) [default: 1]: ');
  final mode = stdin.readLineSync()?.trim();
  autoNamingMode = mode != '2';

  // 3. Input Root
  stdout.write('\n✏️  Enter Root Class Name (PascalCase, misal: RootModel): ');
  final rootClassInput = stdin.readLineSync()?.trim();
  final rootClass = (rootClassInput != null && rootClassInput.isNotEmpty)
      ? rootClassInput
      : 'RootModel';

  String? rootFileName;
  if (!autoNamingMode) {
    rootFileName = await askFileName(rootClass);
  }

  stdout.write('🎯 Enter Target Folder (misal: lib/src/app/model): ');
  final rootFolderInput = stdin.readLineSync()?.trim();
  final rootFolder = (rootFolderInput != null && rootFolderInput.isNotEmpty)
      ? rootFolderInput
      : 'lib/src/app/model';

  Directory(rootFolder).createSync(recursive: true);
  final rootBaseName = rootFileName ?? toSnakeCase(rootClass);
  final jsonPath = '$rootFolder/$rootBaseName.json';
  final jsonFile = File(jsonPath)..writeAsStringSync('{\n  \n}');

  filesToCleanup.add(jsonPath);

  print('\n📄 File template JSON telah dibuat di: $jsonPath');
  stdout.write(
    'Silakan buka file tersebut di IDE, paste RAW JSON Anda ke dalamnya, save, lalu ketik "y" dan Enter: ',
  );

  while (stdin.readLineSync()?.trim().toLowerCase() != 'y') {
    stdout.write('Ketik "y" jika sudah selesai mem-paste JSON: ');
  }

  if (!jsonFile.existsSync()) {
    print('❌ Error: JSON file tidak ditemukan!');
    return;
  }

  // 4. Proses Try-Catch & Auto Cleanup
  try {
    filesToCleanup.add(jsonPath);
    final jsonContent = jsonFile.readAsStringSync();
    final jsonMap = jsonDecode(jsonContent) as Map<String, dynamic>;

    print('\n🧱 Memulai proses generate untuk $rootClass...');
    await processObject(
      rootClass,
      rootFolder,
      jsonMap,
      customFileName: rootFileName,
    );

    final frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    var frameIndex = 0;

    print('');
    final timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      stdout.write(
        '\r🔨 Membangun file boilerplate (.freezed.dart & .g.dart) ${frames[frameIndex]}',
      );
      frameIndex = (frameIndex + 1) % frames.length;
    });

    final result = await Process.run('make', ['bldm']);

    timer.cancel();

    stdout.write('\r\x1b[K');
    print('✅ Membangun file boilerplate selesai.');
    if (result.stdout.toString().isNotEmpty) print(result.stdout);

    if (result.exitCode != 0 ||
        result.stderr.toString().toLowerCase().contains('severe')) {
      print('⚠️ Pesan Build (Error):\n${result.stderr}');
      throw Exception(
        'Proses build gagal atau terdapat error (Exit Code: ${result.exitCode}).',
      );
    }

    print('🪄  Merapihkan kode...');
    if (generatedDartFiles.isNotEmpty) {
      final formatResult = await Process.run('dart', [
        'format',
        ...generatedDartFiles,
      ]);
      if (formatResult.exitCode == 0) {
        print('✨ Berhasil merapihkan ${generatedDartFiles.length} file.');
      } else {
        print('⚠️ Gagal memformat file:\n${formatResult.stderr}');
      }
    }

    print('\n🧹 Membersihkan file temporary...');
    for (final path in filesToCleanup) {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }
    print('✨ Workspace bersih.\n');

    if (generatedDartFiles.length == 1) {
      print('🔥 GACOR PARAH!');
      print(
        '✅ file ${generatedDartFiles.first} berhasil dieksekusi tanpa celah!',
      );
    } else if (generatedDartFiles.length > 1) {
      print('🔥 GACOR PARAH!');
      for (final file in generatedDartFiles) {
        print('• $file');
      }
      print('✅ Semua file berhasil dieksekusi tanpa celah!');
    }
  } catch (e, stacktrace) {
    print('\n❌ TERJADI KESALAHAN PROSES!');
    print(e);
    print(stacktrace);
    print(
      '\n⚠️ File temporary (.json & .md) TIDAK dihapus agar bisa Anda jadikan referensi debugging.',
    );
  }
}

// --- FUNGSI REKURSIF UTAMA ---
Future<String> processObject(
  String className,
  String folderPath,
  Map<String, dynamic> data, {
  String? customFileName,
}) async {
  Directory(folderPath).createSync(recursive: true);

  final fileName =
      customFileName ??
      (autoNamingMode ? toSnakeCase(className) : await askFileName(className));
  final fullPath = '$folderPath/$fileName.dart';

  // 1. Generate & Parse Override Template .md
  final overrides = await handleMarkdownOverride(folderPath, fileName, data);

  final imports = <String>{};
  final requiredFields = StringBuffer();
  final optionalFields = StringBuffer();
  final requiredEmptyFields = StringBuffer();
  final optionalEmptyFields = StringBuffer();

  // 2. Loop Setiap Key di JSON
  for (final entry in data.entries) {
    final key = entry.key;
    final value = entry.value;
    var camelKey = toCamelCase(key);

    var dataType = '';
    var decorators = "@JsonKey(name: '$key')";

    // Cek apakah ada Override
    if (overrides.containsKey(key)) {
      final ov = overrides[key]!;

      if (ov['namaParam'] != '-') {
        camelKey = ov['namaParam']!;
      }

      // Rule 8: Inferensi otomatis jika Tipe Data '-' tapi punya custom fromJson
      if (ov['tipe'] == '-' && ov['fromJsonFn'] != '-') {
        if (value == null) {
          throw Exception(
            '❌ [ERROR OVERRIDE] Key "$key" bernilai null di JSON. CLI tidak bisa inferensi tipe data otomatis. Isi Tipe Data di file .md!',
          );
        }
        dataType = inferPrimitiveType(key, value);
      } else if (ov['tipe'] != '-') {
        dataType = ov['tipe']!;
      }

      if (ov['importTipe'] != '-') imports.add(ov['importTipe']!);
      if (ov['fromJsonFn'] != '-') {
        decorators = "@JsonKey(name: '$key', fromJson: ${ov['fromJsonFn']})";
      }
      if (ov['importFromJson'] != '-') imports.add(ov['importFromJson']!);

      if (dataType.isNotEmpty) {
        final isNullable = dataType.endsWith('?') || dataType == 'dynamic';
        final reqKeyword = isNullable ? '' : 'required ';

        final fieldLine = '    $decorators $reqKeyword$dataType $camelKey,\n';

        var emptyLine = '';
        final defVal = getDefaultValue(dataType);
        if (defVal != null) {
          emptyLine = '        $camelKey: $defVal,\n';
        }

        if (isNullable) {
          optionalFields.write(fieldLine);
          optionalEmptyFields.write(emptyLine);
        } else {
          requiredFields.write(fieldLine);
          requiredEmptyFields.write(emptyLine);
        }
        continue; // Lanjut ke key berikutnya
      }
    }

    // --- AUTO-RULES KETAT & NULL CATCHER ---
    if (value == null) {
      dataType = await handleNullCatcher(key, folderPath);
      if (dataType.contains('import|')) {
        final split = dataType.split('|');
        imports.add(split[1]);
        dataType = split[2];
      }
    } else if (value is Map) {
      final res = await handleMap(
        key,
        value as Map<String, dynamic>,
        folderPath,
      );
      imports.add(res['import']!);
      dataType = res['type']!;
    } else if (value is List) {
      final res = await handleList(key, value, folderPath);
      if (res['import']!.isNotEmpty) imports.add(res['import']!);
      dataType = res['type']!;
    } else {
      // Strict Rules Primitive
      if (key == 'id' && value is num) {
        dataType = 'int';
      } else if (value is num && key != 'id') {
        dataType = 'double';
      } else if (value is bool) {
        dataType = 'bool';
      } else {
        dataType = 'String';
      }
    }

    final isNullable = dataType.endsWith('?') || dataType == 'dynamic';
    final reqKeyword = isNullable ? '' : 'required ';

    final fieldLine = '    $decorators $reqKeyword$dataType $camelKey,\n';

    var emptyLine = '';
    final defVal = getDefaultValue(dataType);
    if (defVal != null) {
      emptyLine = '        $camelKey: $defVal,\n';
    }

    if (isNullable) {
      optionalFields.write(fieldLine);
      optionalEmptyFields.write(emptyLine);
    } else {
      requiredFields.write(fieldLine);
      requiredEmptyFields.write(emptyLine);
    }
  }

  // 3. Tulis File Class Freezed
  imports.add("import 'package:freezed_annotation/freezed_annotation.dart';");
  final formattedImports = formatImports(imports);
  final generatedCode =
      '''
$formattedImports

part '$fileName.freezed.dart';
part '$fileName.g.dart';

@freezed
abstract class $className with _\$$className {
  factory $className({
$requiredFields$optionalFields  }) = _$className;
  const $className._();

  factory $className.empty() => $className(
$requiredEmptyFields$optionalEmptyFields      );

  factory $className.fromJson(Map<String, dynamic> json) => _\$${className}FromJson(json);
}
''';

  File(fullPath).writeAsStringSync(generatedCode);
  generatedDartFiles.add(fullPath);

  return fullPath;
}

// --- HANDLER NULL ---
Future<String> handleNullCatcher(String key, String currentFolder) async {
  print('\n⚠️ [VALUE NULL DITEMUKAN] pada key "$key".');
  print('Silakan pilih tipe data dasar yang seharusnya:');
  print(
    '1. int\n2. String\n3. double\n4. bool\n5. num\n6. Object (Memicu Import/Baru)',
  );
  print('💡 Tips: Ketik angka saja untuk wajib/required (contoh: "1" -> int).');
  print('         Tambahkan "?" untuk nullable (contoh: "1?" -> int?).');
  stdout.write('Pilih (1-6 atau 1?-6?): ');

  final input = stdin.readLineSync()?.trim() ?? 'dynamic';

  // Deteksi apakah user menambahkan tanda '?' di akhir input
  final isNullable = input.endsWith('?');

  // Ambil angka dasarnya saja untuk switch case
  final choice = input.replaceAll('?', '');

  var baseType = 'dynamic';

  switch (choice) {
    case '1':
      baseType = 'int';
    case '2':
      baseType = 'String';
    case '3':
      baseType = 'double';
    case '4':
      baseType = 'bool';
    case '5':
      baseType = 'num';
    case '6':
      stdout.write(
        '1. Import class existing\n2. Import file .json (dummy)\nPilih (1/2): ',
      );
      final objChoice = stdin.readLineSync()?.trim();
      if (objChoice == '1') {
        stdout.write(
          'Masukkan relative path dari lib/ (misal: lib/src/.../model.dart): ',
        );
        final path = stdin.readLineSync()?.trim() ?? '';
        final imp = formatImport(path);
        stdout.write('Masukkan Nama Class dari file tersebut: ');
        final cls = stdin.readLineSync()?.trim() ?? 'Object';
        baseType = 'import|$imp|$cls';
      } else {
        stdout.write('Masukkan path ke dummy JSON (misal: dummy.json): ');
        final dummyPath = stdin.readLineSync()?.trim() ?? '';
        filesToCleanup.add(dummyPath);
        final dJson =
            jsonDecode(File(dummyPath).readAsStringSync())
                as Map<String, dynamic>;
        stdout.write('Nama Class baru: ');
        final cls = stdin.readLineSync()?.trim() ?? 'NewModel';
        stdout.write('Target Folder: ');
        final targetF = stdin.readLineSync()?.trim() ?? currentFolder;
        final resPath = await processObject(cls, targetF, dJson);
        baseType = 'import|${formatImport(resPath)}|$cls';
      }
    default:
      return 'dynamic';
  }

  // Gabungkan baseType dengan '?' jika user meminta nullable
  return isNullable ? '$baseType?' : baseType;
}

// --- HANDLER MAP & LIST ---
Future<Map<String, String>> handleMap(
  String key,
  Map<String, dynamic> map,
  String currentFolder,
) async {
  print('\n📦 [NESTED OBJECT FOUND] Key: "$key"');
  print('1. Gunakan class Freezed yang sudah ada (Import)');
  print('2. Buat class Freezed baru (Deep Dive)');
  stdout.write('Pilih (1/2): ');
  final choice = stdin.readLineSync()?.trim();

  if (choice == '1') {
    stdout.write('Enter existing file path (misal: lib/src/.../model.dart): ');
    final path = stdin.readLineSync()?.trim() ?? '';
    stdout.write('Enter Class Name dari file tersebut: ');
    final cls = stdin.readLineSync()?.trim() ?? 'DynamicClass';
    return {'import': formatImport(path), 'type': cls};
  } else {
    stdout.write('✏️  Enter Class Name for "$key": ');
    final cls = stdin.readLineSync()?.trim() ?? 'DynamicClass';
    stdout.write('🎯 Enter Target Folder (default: $currentFolder): ');
    var targetF = stdin.readLineSync()?.trim() ?? '';
    if (targetF.isEmpty) targetF = currentFolder;

    final path = await processObject(cls, targetF, map);
    return {'import': formatImport(path), 'type': cls};
  }
}

Future<Map<String, String>> handleList(
  String key,
  List<dynamic> list,
  String currentFolder,
) async {
  if (list.isEmpty) {
    print('\n🈳 [ARRAY KOSONG FOUND] Key: "$key"');
    print('1. Import file .json dummy');
    print('2. Import class existing');
    print('3. Skip (pakai List<dynamic>)');
    stdout.write('Pilih (1/2/3): ');
    final choice = stdin.readLineSync()?.trim();

    if (choice == '1') {
      stdout.write('Nama Class baru untuk isi array ini: ');
      final cls = stdin.readLineSync()?.trim() ?? 'NewModel';
      stdout.write('Target Folder (default: $currentFolder): ');
      var targetF = stdin.readLineSync()?.trim() ?? '';
      if (targetF.isEmpty) targetF = currentFolder;

      Directory(targetF).createSync(recursive: true);
      final safeKeyName = toSnakeCase(key);
      final dummyPath = '$targetF/template_array_$safeKeyName.json';
      final dummyFile = File(dummyPath)..writeAsStringSync('{\n  \n}');

      filesToCleanup.add(dummyPath);

      print(
        '\n📄 File dummy JSON untuk array "$key" telah dibuat di: $dummyPath',
      );
      stdout.write(
        'Silakan buka, paste objek tunggal JSON Anda ke dalamnya, save, lalu ketik "y" dan Enter: ',
      );

      while (stdin.readLineSync()?.trim().toLowerCase() != 'y') {
        stdout.write('Ketik "y" jika sudah selesai: ');
      }

      if (!dummyFile.existsSync()) {
        print('❌ Error: Dummy JSON file tidak ditemukan!');
        return {'import': '', 'type': 'List<dynamic>'};
      }

      final dJson =
          jsonDecode(dummyFile.readAsStringSync()) as Map<String, dynamic>;

      final resPath = await processObject(cls, targetF, dJson);
      return {'import': formatImport(resPath), 'type': 'List<$cls>'};
    } else if (choice == '2') {
      stdout.write('Enter existing file path: ');
      final path = stdin.readLineSync()?.trim() ?? '';
      stdout.write('Enter Class Name: ');
      final cls = stdin.readLineSync()?.trim() ?? 'DynamicClass';
      return {'import': formatImport(path), 'type': 'List<$cls>'};
    } else {
      return {'import': '', 'type': 'List<dynamic>'};
    }
  } else if (list.first is Map) {
    print('\n📚 [ARRAY BERISI DATA FOUND] Key: "$key"');
    print('1. Gunakan class Freezed yang sudah ada (Import)');
    print('2. Buat class Freezed baru dari index ke-0');
    stdout.write('Pilih (1/2): ');
    final choice = stdin.readLineSync()?.trim();

    if (choice == '1') {
      stdout.write('Enter existing file path: ');
      final path = stdin.readLineSync()?.trim() ?? '';
      stdout.write('Enter Class Name: ');
      final cls = stdin.readLineSync()?.trim() ?? 'DynamicClass';
      return {'import': formatImport(path), 'type': 'List<$cls>'};
    } else {
      stdout.write('✏️  Enter Class Name for list "$key": ');
      final cls = stdin.readLineSync()?.trim() ?? 'DynamicClass';
      stdout.write('🎯 Enter Target Folder (default: $currentFolder): ');
      var targetF = stdin.readLineSync()?.trim() ?? '';
      if (targetF.isEmpty) targetF = currentFolder;

      final path = await processObject(
        cls,
        targetF,
        list.first as Map<String, dynamic>,
      );
      return {'import': formatImport(path), 'type': 'List<$cls>'};
    }
  } else {
    // Array Primitif
    var primType = 'String';
    if (list.first is int) primType = 'int';
    if (list.first is double) primType = 'double';
    if (list.first is bool) primType = 'bool';
    return {'import': '', 'type': 'List<$primType>'};
  }
}

// --- HANDLER MARKDOWN OVERRIDE ---
Future<Map<String, Map<String, String>>> handleMarkdownOverride(
  String folderPath,
  String fileName,
  Map<String, dynamic> data,
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

  final mdContent =
      '''
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
        'importTipe': formatImport(parts[3]),
        'fromJsonFn': parts[4],
        'importFromJson': formatImport(parts[5]),
        'namaParam': parts[6],
      };
    }
  }
  return overrides;
}

// --- UTILS ---
String formatImport(String rawPath) {
  if (rawPath == '-') return '-';
  if (rawPath.startsWith('lib/')) {
    return "import 'package:$packageName/${rawPath.substring(4)}';";
  }
  return rawPath.startsWith('import') ? rawPath : "import '$rawPath';";
}

Future<String> askFileName(String className) async {
  final defaultName = toSnakeCase(className);
  stdout.write(
    '✏️  Enter custom file name untuk $className (tanpa .dart) [default: $defaultName]: ',
  );
  final input = stdin.readLineSync()?.trim();
  return (input != null && input.isNotEmpty) ? input : defaultName;
}

String toSnakeCase(String text) {
  return text
      .replaceAllMapped(
        RegExp('(?<=[a-z])[A-Z]'),
        (Match m) => '_${m.group(0)}',
      )
      .toLowerCase();
}

String toCamelCase(String text) {
  return text.replaceAllMapped(
    RegExp('_([a-z])'),
    (Match m) => m.group(1)!.toUpperCase(),
  );
}

String inferPrimitiveType(String key, dynamic value) {
  if (key == 'id' && value is num) return 'int';
  if (value is num && key != 'id') return 'double';
  if (value is bool) return 'bool';
  return 'String';
}

String? getDefaultValue(String type) {
  if (type.endsWith('?')) return null;
  if (type.startsWith('List')) return '[]';
  switch (type) {
    case 'int':
      return '0';
    case 'double':
      return '0';
    case 'bool':
      return 'false';
    case 'String':
      return "''";
    case 'num':
      return '0';
    case 'DateTime':
      return 'DateTime(0)';
    case 'dynamic':
      return null;
    default:
      return '$type.empty()';
  }
}

String formatImports(Set<String> imports) {
  final dart = imports.where((e) => e.startsWith("import 'dart:")).toList()
    ..sort();
  final pkg = imports.where((e) => e.startsWith("import 'package:")).toList()
    ..sort();
  final rel =
      imports
          .where(
            (e) =>
                !e.startsWith("import 'dart:") &&
                !e.startsWith("import 'package:"),
          )
          .toList()
        ..sort();

  final result = <String>[];
  if (dart.isNotEmpty) result.add(dart.join('\n'));
  if (pkg.isNotEmpty) result.add(pkg.join('\n'));
  if (rel.isNotEmpty) result.add(rel.join('\n'));

  return result.join('\n\n');
}
