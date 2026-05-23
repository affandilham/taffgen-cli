import 'dart:convert';
import 'dart:io';

class UpdateService {
  static const String currentVersion = '1.0.0';
  static const String versionUrl =
      'https://raw.githubusercontent.com/affandilham/taffgen-cli/main/version.txt';

  static Future<void> checkUpdate() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);

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
              'dart pub global activate --source git https://github.com/affandilham/taffgen-cli.git',
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

  static Future<bool> handleUninstall(List<String> args) async {
    if (args.contains('--uninstall')) {
      stdout.writeln(
        '\n🗑️  Memulai proses uninstall TaffGen CLI dari device Anda...',
      );

      final process = await Process.run('dart', [
        'pub',
        'global',
        'deactivate',
        'taff_gen',
      ]);

      if (process.exitCode == 0) {
        stdout.writeln('✅ TaffGen CLI berhasil dihapus sepenuhnya dari lokal.');
        stdout.writeln('Sampai jumpa lagi! 👋\n');
      } else {
        stdout.writeln('⚠️ Gagal menghapus CLI:\n${process.stderr}');
      }
      return true;
    }
    return false;
  }
}
