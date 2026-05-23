import 'dart:convert';
import 'dart:io';

class UpdateService {
  static const String currentVersion = '1.0.0';
  static const String versionUrl =
      'https://raw.githubusercontent.com/affandilham/taffgen-cli/main/version.txt';

  static Future<bool> checkUpdate() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);

      final request = await client.getUrl(Uri.parse(versionUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final latestVersion = await response.transform(utf8.decoder).join();
        final cleanLatest = latestVersion.trim();

        if (cleanLatest.isNotEmpty && cleanLatest != currentVersion) {
          final isAndroid = Platform.isAndroid ||
              (Platform.environment['PREFIX']?.contains('termux') == true);

          if (isAndroid) {
            stdout
              ..writeln('\n🌟 ============================ 🌟')
              ..writeln('🚀 Update v$cleanLatest tersedia!')
              ..writeln('⚙️ Mengunduh pembaruan otomatis...')
              ..writeln('🌟 ============================ 🌟\n');
          } else {
            stdout
              ..writeln(
                '\n🌟 ====================================================== 🌟',
              )
              ..writeln(
                '🚀 [UPDATE TERSEDIA] TaffGen CLI versi $cleanLatest ditemukan!',
              )
              ..writeln(
                  '⚙️ Memulai pembaruan otomatis. Harap tunggu sebentar...')
              ..writeln(
                '🌟 ====================================================== 🌟\n',
              );
          }

          final process = await Process.run('dart', [
            'pub',
            'global',
            'activate',
            '--source',
            'git',
            'https://github.com/affandilham/taffgen-cli.git'
          ]);

          if (process.exitCode == 0) {
            if (isAndroid) {
              await Process.run(
                  'sh', ['-c', 'chmod +x ~/.pub-cache/bin/taff-gen']);
              stdout.writeln('✅ Sukses! Silakan ketik ulang `taff-gen`.');
            } else {
              stdout.writeln(
                  '✅ Update berhasil! Silakan jalankan ulang perintah `taff-gen`.');
            }
          } else {
            stdout.writeln('⚠️ Gagal update otomatis:\n${process.stderr}');
            if (isAndroid) {
              stdout.writeln(
                  'Jalankan manual:\ndart pub global activate --source git https://github.com/affandilham/taffgen-cli.git');
            } else {
              stdout.writeln(
                  'Silakan jalankan manual: dart pub global activate --source git https://github.com/affandilham/taffgen-cli.git');
            }
          }
          return true;
        }
      }
    } catch (e) {
      // Silent fail: Jika tidak ada internet atau gagal fetch, abaikan saja dan lanjut.
    }
    return false;
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
