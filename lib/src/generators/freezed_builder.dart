import 'dart:convert';
import 'dart:io';
import 'template_parser.dart';
import '../utils/formatter.dart';

class FreezedBuilder {
  final String packageName;
  final bool autoNamingMode;
  final List<String> filesToCleanup;
  final List<String> generatedDartFiles;

  FreezedBuilder({
    required this.packageName,
    required this.autoNamingMode,
    required this.filesToCleanup,
    required this.generatedDartFiles,
  });

  Future<String> processObject(
    String className,
    String folderPath,
    Map<String, dynamic> data, {
    String? customFileName,
  }) async {
    Directory(folderPath).createSync(recursive: true);

    final fileName = customFileName ??
        (autoNamingMode
            ? Formatter.toSnakeCase(className)
            : await Formatter.askFileName(className, autoNamingMode));
    final fullPath = '$folderPath/$fileName.dart';

    // 1. Generate & Parse Override Template .md
    final overrides = await TemplateParser.handleMarkdownOverride(
        folderPath, fileName, data, packageName, filesToCleanup);

    final imports = <String>{};
    final requiredFields = StringBuffer();
    final optionalFields = StringBuffer();
    final requiredEmptyFields = StringBuffer();
    final optionalEmptyFields = StringBuffer();

    // 2. Loop Setiap Key di JSON
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      var camelKey = Formatter.toCamelCase(key);

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
          dataType = Formatter.inferPrimitiveType(key, value);
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
          final defVal = Formatter.getDefaultValue(dataType);
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
      final defVal = Formatter.getDefaultValue(dataType);
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
    final formattedImports = Formatter.formatImports(imports);
    final generatedCode = '''
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
    print(
        '💡 Tips: Ketik angka saja untuk wajib/required (contoh: "1" -> int).');
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
          final imp = Formatter.formatImport(path, packageName);
          stdout.write('Masukkan Nama Class dari file tersebut: ');
          final cls = stdin.readLineSync()?.trim() ?? 'Object';
          baseType = 'import|$imp|$cls';
        } else {
          stdout.write('Masukkan path ke dummy JSON (misal: dummy.json): ');
          final dummyPath = stdin.readLineSync()?.trim() ?? '';
          filesToCleanup.add(dummyPath);
          final dJson = jsonDecode(File(dummyPath).readAsStringSync())
              as Map<String, dynamic>;
          stdout.write('Nama Class baru: ');
          final cls = stdin.readLineSync()?.trim() ?? 'NewModel';
          stdout.write('Target Folder: ');
          final targetF = stdin.readLineSync()?.trim() ?? currentFolder;
          final resPath = await processObject(cls, targetF, dJson);
          baseType =
              'import|${Formatter.formatImport(resPath, packageName)}|$cls';
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
      stdout
          .write('Enter existing file path (misal: lib/src/.../model.dart): ');
      final path = stdin.readLineSync()?.trim() ?? '';
      stdout.write('Enter Class Name dari file tersebut: ');
      final cls = stdin.readLineSync()?.trim() ?? 'DynamicClass';
      return {'import': Formatter.formatImport(path, packageName), 'type': cls};
    } else {
      stdout.write('✏️  Enter Class Name for "$key": ');
      final cls = stdin.readLineSync()?.trim() ?? 'DynamicClass';
      stdout.write('🎯 Enter Target Folder (default: $currentFolder): ');
      var targetF = stdin.readLineSync()?.trim() ?? '';
      if (targetF.isEmpty) targetF = currentFolder;

      final path = await processObject(cls, targetF, map);
      return {'import': Formatter.formatImport(path, packageName), 'type': cls};
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
        final safeKeyName = Formatter.toSnakeCase(key);
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
        return {
          'import': Formatter.formatImport(resPath, packageName),
          'type': 'List<$cls>'
        };
      } else if (choice == '2') {
        stdout.write('Enter existing file path: ');
        final path = stdin.readLineSync()?.trim() ?? '';
        stdout.write('Enter Class Name: ');
        final cls = stdin.readLineSync()?.trim() ?? 'DynamicClass';
        return {
          'import': Formatter.formatImport(path, packageName),
          'type': 'List<$cls>'
        };
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
        return {
          'import': Formatter.formatImport(path, packageName),
          'type': 'List<$cls>'
        };
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
        return {
          'import': Formatter.formatImport(path, packageName),
          'type': 'List<$cls>'
        };
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
}
