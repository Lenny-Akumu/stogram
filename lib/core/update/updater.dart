import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import 'release.dart';

class InstallPermissionRequired implements Exception {
  const InstallPermissionRequired();
}

abstract interface class Updater {
  bool get supported;
  Future<ReleaseInfo?> latest();
  Future<String> download(
    ReleaseInfo release,
    void Function(double) onProgress,
  );
  Future<void> install(String path);
}

String? platformAsset() {
  if (Platform.isAndroid) return 'stogram.apk';
  if (Platform.isLinux) return 'stogram-linux-x64.tar.gz';
  if (Platform.isWindows) return 'stogram-windows-x64.zip';
  return null;
}

class GithubUpdater implements Updater {
  GithubUpdater({HttpClient? client}) : _http = client ?? HttpClient();

  static const _channel = MethodChannel('dev.lenny.app/update');
  final HttpClient _http;

  @override
  bool get supported => Env.buildTag.isNotEmpty && platformAsset() != null;

  @override
  Future<ReleaseInfo?> latest() async {
    final asset = platformAsset();
    if (asset == null) return null;
    final req = await _http.getUrl(
      Uri.https('api.github.com', '/repos/${Env.updateRepo}/releases', {
        'per_page': '10',
      }),
    );
    req.headers
      ..set(HttpHeaders.userAgentHeader, 'stogram-updater')
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final res = await req.close();
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw HttpException('GitHub responded ${res.statusCode}');
    }
    final body = await res.transform(utf8.decoder).join();
    return pickRelease(jsonDecode(body) as List<Object?>, asset);
  }

  @override
  Future<String> download(
    ReleaseInfo release,
    void Function(double) onProgress,
  ) async {
    final dir = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates',
    );
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}${release.assetName}',
    );
    final req = await _http.getUrl(Uri.parse(release.assetUrl));
    req.headers.set(HttpHeaders.userAgentHeader, 'stogram-updater');
    final res = await req.close();
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw HttpException('Download failed: ${res.statusCode}');
    }
    final total = res.contentLength > 0 ? res.contentLength : release.assetSize;
    final sink = file.openWrite();
    var got = 0;
    await for (final chunk in res) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) onProgress(got / total);
    }
    await sink.close();
    return file.path;
  }

  @override
  Future<void> install(String path) async {
    if (Platform.isAndroid) {
      final allowed = await _channel.invokeMethod<bool>('canInstall') ?? false;
      if (!allowed) {
        await _channel.invokeMethod<void>('openInstallSettings');
        throw const InstallPermissionRequired();
      }
      await _channel.invokeMethod<void>('install', {'path': path});
    } else if (Platform.isLinux) {
      await _installLinux(path);
    } else if (Platform.isWindows) {
      await _installWindows(path);
    }
  }

  Future<void> _installLinux(String path) async {
    final exe = File(Platform.resolvedExecutable);
    final root = exe.parent.path;
    final archive = TarDecoder().decodeBytes(
      GZipDecoder().decodeBytes(await File(path).readAsBytes()),
    );
    for (final entry in archive) {
      final name = entry.name.replaceFirst(RegExp(r'^\./'), '');
      if (name.isEmpty || !entry.isFile) continue;
      final target = File('$root/$name');
      await target.parent.create(recursive: true);
      // unlink first: overwriting a running binary in place fails
      if (target.existsSync()) await target.delete();
      await target.writeAsBytes(entry.content);
      if (entry.mode & 0x49 != 0) {
        await Process.run('chmod', ['+x', target.path]);
      }
    }
    await Process.start(exe.path, const [], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<void> _installWindows(String path) async {
    final exe = Platform.resolvedExecutable;
    final root = File(exe).parent.path;
    final staging = Directory('${File(path).parent.path}\\staging');
    if (staging.existsSync()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final target = File('${staging.path}\\${entry.name}');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.content);
    }
    final me = pid;
    final script = File('${File(path).parent.path}\\apply-update.ps1');
    await script.writeAsString('''
Wait-Process -Id $me -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Copy-Item -Path "${staging.path}\\*" -Destination "$root" -Recurse -Force
Start-Process -FilePath "$exe"
''');
    await Process.start('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      script.path,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}
