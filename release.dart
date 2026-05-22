import 'dart:io';

void main(List<String> args) async {
  // Capture the version argument sent from the Makefile
  if (args.isEmpty) {
    stdout.writeln('❌ Error: Version argument not found!');
    return;
  }

  final newVersion = args.first;

  // 1. Update pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    var content = pubspecFile.readAsStringSync();
    // Use Regex to find and replace the version: x.x.x line
    content = content.replaceAll(
      RegExp(r'^version:\s*.*$', multiLine: true),
      'version: $newVersion',
    );
    pubspecFile.writeAsStringSync(content);
    stdout.writeln('✅ pubspec.yaml successfully updated.');
  }

  // 2. Update version.txt (For Cloud Checker)
  File('version.txt').writeAsStringSync(newVersion);
  stdout.writeln('✅ version.txt successfully updated.');

  // 3. Update the variable in generate_nested_freezed.dart
  final dartFile = File('bin/generate_nested_freezed.dart');
  if (dartFile.existsSync()) {
    var dartCode = dartFile.readAsStringSync();
    dartCode = dartCode.replaceAll(
      RegExp(r"const String currentVersion = '.*';"),
      "const String currentVersion = '$newVersion';",
    );
    dartFile.writeAsStringSync(dartCode);
    stdout.writeln('✅ currentVersion variable in Dart file successfully updated.');
  }

  stdout.writeln(
      '\n🎉 Done! All files have been synchronized to version $newVersion.');
}
