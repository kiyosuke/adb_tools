import 'dart:async';

import 'package:adb/adb.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

final adb = Adb();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var adbPath = await adb.usingAdbPath();
  if (adbPath == null) {
    adbPath = await adb.whichAdb();
    print('adbPath: $adbPath');
    if (adbPath != null) {
      adb.setUseAdbPath(adbPath);
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyPage(),
    );
  }
}

class MyPage extends StatefulWidget {
  const MyPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String? adbPath;
  List<AndroidDevice> devices = const [];
  List<String> packages = const [];
  AndroidDevice? selectedDevice;
  String? selectedPackageName;
  bool isRecording = false;
  StreamSubscription? screenRecordSubscription;

  bool get isDeviceSelected => selectedDevice != null;

  bool get isPackageSelected => selectedPackageName != null;

  @override
  void initState() {
    super.initState();
    adb.usingAdbPath().then((value) => setState(() => adbPath = value));
    adb.getDevices().then((value) => setState(() => devices = value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adb example app'),
        actions: [
          TextButton(
            onPressed: () {
              adb.getDevices().then((value) => setState(() => devices = value));
              getInstalledApps();
            },
            child: const Text(
              '更新',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adb Path: $adbPath'),
          DropdownButton<AndroidDevice>(
            items: [
              for (var device in devices)
                DropdownMenuItem<AndroidDevice>(
                  enabled: selectedDevice != device,
                  value: device,
                  child: Text(device.deviceName),
                )
            ],
            value: selectedDevice,
            onChanged: (device) {
              setState(() => selectedDevice = device);
              getInstalledApps();
            },
          ),
          DropdownButton<String>(
            items: [
              for (var package in packages)
                DropdownMenuItem(
                  enabled: selectedPackageName != package,
                  value: package,
                  child: Text(package),
                ),
            ],
            value: selectedPackageName,
            onChanged: (value) => setState(() => selectedPackageName = value),
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: (isDeviceSelected)
                    ? () async {
                        final serialId = selectedDevice?.serialId;
                        if (serialId == null) return;
                        final directory = await getDirectoryPath();
                        if (directory == null) return;
                        try {
                          final filepath =
                              await adb.screenshot(serialId: serialId);
                          if (filepath == null) return;
                          final result =
                              await adb.pullFile(serialId, filepath, directory);
                          if (result) {
                            await adb.removeFile(serialId, filepath);
                          }
                          print('スクリーンショット結果: $result');
                        } catch (e) {
                          print('スクリーンショット失敗。 e: $e');
                        }
                      }
                    : null,
                child: const Text('スクリーンショット'),
              ),
              TextButton(
                onPressed: (isDeviceSelected && isPackageSelected)
                    ? () async {
                        final device = selectedDevice;
                        if (device == null) return;
                        final packageName = selectedPackageName;
                        if (packageName == null) return;
                        try {
                          final result = await adb.uninstallPackage(
                              serialId: device.serialId,
                              packageName: packageName);
                          if (result) {
                            setState(() => selectedPackageName = null);
                          }
                          print('アンインストール結果: $result');
                        } catch (e) {
                          print('アンインストール失敗');
                        }
                        getInstalledApps();
                      }
                    : null,
                child: const Text('アンインストール'),
              ),
              TextButton(
                onPressed: (isDeviceSelected) ? () async {
                  final device = selectedDevice;
                  if (device==null) return;
                  final file = await openFile(acceptedTypeGroups: [XTypeGroup(label: 'apk', extensions: ['apk'])]);
                  if (file == null) return;
                  try {
                    final result = await adb.installApk(serialId: device.serialId, apkFilePath: file.path);
                    print('APKインストール結果: $result');
                  } catch (e) {
                    print('APKインストール失敗');
                  }
                  getInstalledApps();
                } : null,
                child: const Text('APKインストール'),
              ),
            ],
          )
        ],
      ),
    );
  }

  void getInstalledApps() {
    final device = selectedDevice;
    if (device == null) return;
    adb.getInstalledApps(device.serialId).then((value) {
      setState(() => packages = value);
    });
  }
}
