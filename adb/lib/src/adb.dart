import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb/src/adb_not_found_exception.dart';
import 'package:adb/src/adb_preferences.dart';
import 'package:adb/src/model/android_device.dart';
import 'package:process_run/shell.dart';

typedef Command = List<String>;
typedef OnProcess = void Function(Process process);
typedef TimestampFormat = String Function(DateTime value);

const _sdcard = '/sdcard';

String _defaultTimestampFormat(DateTime value) {
  return value.millisecondsSinceEpoch.toString();
}

class Adb {
  final _preference = AdbPreferences();

  static String? get _userHome =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

  final Shell _shell = Shell(
    workingDirectory: _userHome,
    environment: Platform.environment,
    throwOnError: false,
    stderrEncoding: const Utf8Codec(),
    stdoutEncoding: const Utf8Codec(),
  );

  Future<String?> whichAdb() async {
    final command = (Platform.isWindows) ? 'where' : 'which';
    final result = await _shell.runExecutableArguments(command, ['adb']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    } else {
      return null;
    }
  }

  Future<String?> usingAdbPath() async {
    return await _preference.getAdbPath();
  }

  Future<void> setUseAdbPath(String path) async {
    await _preference.setAdbPath(path);
  }

  Future<ProcessResult> adb(
    Command command, {
    OnProcess? onProcess,
  }) async {
    final adbPath = await usingAdbPath();
    if (adbPath == null || adbPath.isEmpty) {
      throw AdbNotFoundException();
    }
    return await _shell.runExecutableArguments(
      adbPath,
      command,
      onProcess: onProcess,
    );
  }

  /// 接続中デバイスのリストを取得
  Future<List<AndroidDevice>> getDevices() async {
    final devices = await adb(const ['devices']);
    for (var value in devices.outLines) {
      if (value.contains('List of devices attached')) {
        continue;
      }
    }
    print('[getDevices] result: $devices');
    return Stream.fromIterable(devices.outLines)
        .where((value) => !value.contains('List of devices attached'))
        .where((value) => value.contains('device'))
        .map((value) => value.split('\t'))
        .where((value) => value.isNotEmpty)
        .map((value) => value[0])
        .asyncMap((serialId) async {
      final brand = await getBrand(serialId);
      final model = await getModel(serialId);
      return AndroidDevice(serialId: serialId, brand: brand, model: model);
    }).toList();
  }

  Future<String> getBrand(String serialId) async {
    final command = ['-s', serialId, 'shell', 'getprop', 'ro.product.brand'];
    final brand = await adb(command);
    if (brand.outLines.isEmpty) {
      return serialId;
    } else {
      return brand.outLines.first;
    }
  }

  Future<String> getModel(String serialId) async {
    final command = ['-s', serialId, 'shell', 'getprop', 'ro.product.model'];
    final model = await adb(command);
    if (model.outLines.isEmpty) {
      return serialId;
    } else {
      return model.outLines.first;
    }
  }

  /// [apkFilePath]で指定したapkファイルを端末にインストール
  Future<bool> installApk({
    required String serialId,
    required String apkFilePath,
    bool replaceExistingApplication = false,
    bool allowTestPackages = false,
    bool allowVersionCodeDowngrade = false,
  }) async {
    final command = [
      '-s',
      serialId,
      'install',
      if (replaceExistingApplication) '-r',
      if (allowTestPackages) '-t',
      if (allowVersionCodeDowngrade) '-d',
      apkFilePath,
    ];
    final result = await adb(command);
    return result.exitCode == 0;
  }

  /// [packageName]に一致するパッケージをアンインストール
  Future<bool> uninstallPackage({
    required String serialId,
    required String packageName,
    bool keep = false,
  }) async {
    final command = ['-s', serialId, 'uninstall', if (keep) '-k', packageName];
    final result = await adb(command);
    return result.exitCode == 0;
  }

  /// インストール済みパッケージのリストを取得
  Future<List<String>> getInstalledApps(String serialId) async {
    final command = ['-s', serialId, 'shell', 'pm', 'list', 'packages', '-3'];
    final result = await adb(command);
    return result.outLines.map((e) => e.replaceAll('package:', '')).toList()
      ..sort((a, b) => a.compareTo(b));
  }

  /// [packageName]の保存先パスを取得
  Future<String?> getPackagePath({
    required String serialId,
    required String packageName,
  }) async {
    final command = ['-s', serialId, 'shell', 'pm', 'path', packageName];
    final result = await adb(command);
    if (result.outLines.isEmpty) {
      return null;
    } else {
      return result.outLines.first;
    }
  }

  /// スクリーンショットを撮影
  /// 撮影した画像は端末の/sdcard/配下に保存されるため[pullFile]を使って取得する
  Future<String?> screenshot({
    required String serialId,
    TimestampFormat timestampFormat = _defaultTimestampFormat,
  }) async {
    final filename =
        'screenshot-${_defaultTimestampFormat(DateTime.now())}.png';
    final filepath = '$_sdcard/$filename';
    final command = ['-s', serialId, 'shell', 'screencap', '-p', filepath];
    final result = await adb(command);
    if (result.exitCode == 0) {
      return filepath;
    } else {
      return null;
    }
  }

  Future<bool> copyFile(
    String serialId, {
    required String from,
    required String to,
  }) async {
    final command = ['-s', serialId, 'shell', 'cp', from, to];
    final result = await adb(command);
    return result.exitCode == 0;
  }

  /// [targetFile]を[outputDir]にコピーして取得
  Future<bool> pullFile(
    String serialId,
    String targetFile,
    String outputDir,
  ) async {
    final command = [
      '-s',
      serialId,
      'pull',
      targetFile,
      '$outputDir/${File(targetFile).uri.pathSegments.last}',
    ];
    final result = await adb(command);
    return result.exitCode == 0;
  }

  Future<bool> removeFile(
    String serialId,
    String targetFile,
  ) async {
    final command = ['-s', serialId, 'shell', 'rm', targetFile];
    final result = await adb(command);
    return result.exitCode == 0;
  }

  // Stream<void> screenRecord({
  //   required String serialId,
  //   Duration timeLimit = const Duration(minutes: 3),
  //   TimestampFormat timestampFormat = _defaultTimestampFormat,
  // }) async* {
  //   final timestamp = _defaultTimestampFormat(DateTime.now());
  //   final tempFile = '$_sdcard/$timestamp.mp4';
  //   final command = ['-s', serialId, 'shell', 'screenrecord', '--time-limit', '${timeLimit.inSeconds}', tempFile,];
  //   await adb(command);
  // }

  bool killProcess() {
    return _shell.kill();
  }
}
