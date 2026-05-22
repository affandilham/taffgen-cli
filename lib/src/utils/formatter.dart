import 'dart:io';

class Formatter {
  static String formatImport(String rawPath, String packageName) {
    if (rawPath == '-') return '-';
    if (rawPath.startsWith('lib/')) {
      return "import 'package:$packageName/${rawPath.substring(4)}';";
    }
    return rawPath.startsWith('import') ? rawPath : "import '$rawPath';";
  }

  static Future<String> askFileName(
      String className, bool autoNamingMode) async {
    final defaultName = toSnakeCase(className);
    if (autoNamingMode) return defaultName;
    stdout.write(
      '✏️  Enter custom file name untuk $className (tanpa .dart) [default: $defaultName]: ',
    );
    final input = stdin.readLineSync()?.trim();
    return (input != null && input.isNotEmpty) ? input : defaultName;
  }

  static String toSnakeCase(String text) {
    return text
        .replaceAllMapped(
          RegExp('(?<=[a-z])[A-Z]'),
          (Match m) => '_${m.group(0)}',
        )
        .toLowerCase();
  }

  static String toCamelCase(String text) {
    return text.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (Match m) => m.group(1)!.toUpperCase(),
    );
  }

  static String inferPrimitiveType(String key, dynamic value) {
    if (key == 'id' && value is num) return 'int';
    if (value is num && key != 'id') return 'double';
    if (value is bool) return 'bool';
    return 'String';
  }

  static String? getDefaultValue(String type) {
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

  static String formatImports(Set<String> imports) {
    final dart = imports.where((e) => e.startsWith("import 'dart:")).toList()
      ..sort();
    final pkg = imports.where((e) => e.startsWith("import 'package:")).toList()
      ..sort();
    final rel = imports
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
}
