import 'dart:io';

import 'package:flutter/material.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final databasePath = switch (Platform.operatingSystem) {
    'android' => '/data/user/0/com.example.life_os_app/files/life_os.db',
    'macos' =>
      '${Platform.environment['HOME']}/Library/Application Support/life_os.db',
    'ios' => 'life_os.db',
    _ => File('life_os.db').absolute.path,
  };
  runApp(LifeOsApp(databasePath: databasePath));
}
