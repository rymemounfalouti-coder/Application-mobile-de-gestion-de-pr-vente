import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String?> readLocalJson(String name) async {
  final file = await _file(name);
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> writeLocalJson(String name, String contents) async {
  final file = await _file(name);
  if (!await file.parent.exists()) {
    await file.parent.create(recursive: true);
  }
  await file.writeAsString(contents);
}

Future<File> _file(String name) async {
  final directory = await getApplicationSupportDirectory();
  return File('${directory.path}${Platform.pathSeparator}$name');
}
