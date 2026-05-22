import 'dart:io';

class BuildRunnerService {
  static Future<ProcessResult> buildModels(String targetDir) async {
    final errorFiles = await _collectErrorFiles(targetDir, false);

    if (errorFiles.isEmpty) {
      return ProcessResult(0, 0, 'All generated files are up-to-date', '');
    }

    final buildArgs = [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs'
    ];
    for (final file in errorFiles) {
      buildArgs.add('--build-filter=$file');
    }

    return await Process.run('dart', buildArgs);
  }

  static Future<List<String>> _collectErrorFiles(
      String targetDir, bool onlyFreezed) async {
    final dir = Directory(targetDir);
    if (!dir.existsSync()) return [];

    final errorFiles = <String>{};

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (entity.path.endsWith('.freezed.dart') ||
            entity.path.endsWith('.g.dart')) {
          continue;
        }

        final content = await entity.readAsString();

        if (onlyFreezed && !content.contains('@freezed')) {
          continue;
        }

        final parts = _extractPartFiles(content);
        for (final part in parts) {
          final generatedFilePath = '${entity.parent.path}/$part';
          if (await _needsGeneration(entity.path, generatedFilePath)) {
            errorFiles.add(generatedFilePath);
          }
        }
      }
    }

    final sorted = errorFiles.toList()..sort();
    return sorted;
  }

  static List<String> _extractPartFiles(String content) {
    final matches =
        RegExp(r"part '([^']*\.(freezed|g)\.dart)';").allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }

  static Future<bool> _needsGeneration(
      String sourcePath, String generatedPath) async {
    final generatedFile = File(generatedPath);
    if (!await generatedFile.exists()) {
      return true;
    }

    final sourceFile = File(sourcePath);
    final sourceStat = await sourceFile.stat();
    final generatedStat = await generatedFile.stat();

    if (sourceStat.modified.isAfter(generatedStat.modified)) {
      return true;
    }

    return false;
  }
}
