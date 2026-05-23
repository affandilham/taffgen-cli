import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../services/updater.dart';
import '../services/build_runner_service.dart';
import '../generators/freezed_builder.dart';
import '../utils/formatter.dart';

class TaffGenRunner {
  String packageName = '';
  bool autoNamingMode = true;
  List<String> filesToCleanup = [];
  List<String> generatedDartFiles = [];

  Future<void> execute(List<String> args) async {
    if (args.contains('--version') || args.contains('-v')) {
      stdout.writeln('📦 TaffGen CLI Version: ${UpdateService.currentVersion}');
      return;
    }

    if (await UpdateService.handleUninstall(args)) {
      return;
    }

    print('🚀 INIT TAFF CLI FREEZED GENERATOR...\n');

    await UpdateService.checkUpdate();

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
      packageName =
          (pkgInput != null && pkgInput.isNotEmpty) ? pkgInput : 'app';
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
    stdout
        .write('\n✏️  Enter Root Class Name (PascalCase, misal: RootModel): ');
    final rootClassInput = stdin.readLineSync()?.trim();
    final rootClass = (rootClassInput != null && rootClassInput.isNotEmpty)
        ? rootClassInput
        : 'RootModel';

    String? rootFileName;
    if (!autoNamingMode) {
      rootFileName = await Formatter.askFileName(rootClass, autoNamingMode);
    }

    stdout.write('🎯 Enter Target Folder (misal: lib/src/app/model): ');
    final rootFolderInput = stdin.readLineSync()?.trim();
    final rootFolder = (rootFolderInput != null && rootFolderInput.isNotEmpty)
        ? rootFolderInput
        : 'lib/src/app/model';

    Directory(rootFolder).createSync(recursive: true);
    final rootBaseName = rootFileName ?? Formatter.toSnakeCase(rootClass);
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

      final builder = FreezedBuilder(
        packageName: packageName,
        autoNamingMode: autoNamingMode,
        filesToCleanup: filesToCleanup,
        generatedDartFiles: generatedDartFiles,
      );

      await builder.processObject(
        rootClass,
        rootFolder,
        jsonMap,
        customFileName: rootFileName,
      );

      final frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
      var frameIndex = 0;

      final isAndroid = Platform.isAndroid ||
          (Platform.environment['PREFIX']?.contains('termux') == true);

      print('');
      final timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
        final msg = isAndroid
            ? '\r🔨 Building ${frames[frameIndex]}'
            : '\r🔨 Building boilerplate (.freezed.dart & .g.dart) ${frames[frameIndex]}';
        stdout.write(msg);
        frameIndex = (frameIndex + 1) % frames.length;
      });

      final result = await BuildRunnerService.buildModels(rootFolder);

      timer.cancel();

      stdout.write('\r\x1b[K');
      if (isAndroid) {
        print('✅ Build completed.');
      } else {
        print('✅ Boilerplate built successfully.');
      }
      if (result.stdout.toString().isNotEmpty) print(result.stdout);

      if (result.exitCode != 0 ||
          result.stderr.toString().toLowerCase().contains('severe')) {
        print('⚠️ Pesan Build (Error):');
        if (result.stderr.toString().isNotEmpty) print(result.stderr);
        if (result.stdout.toString().isNotEmpty) print(result.stdout);

        final combinedOutput =
            '${result.stdout} ${result.stderr}'.toLowerCase();
        if (combinedOutput.contains('could not find package') ||
            combinedOutput.contains('build_runner')) {
          print(
              '\n💡 HINT: Pastikan package `build_runner` dan `freezed` sudah ditambahkan di pubspec.yaml project Anda, lalu jalankan `dart pub get` (atau `flutter pub get`).');
        }

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
}
