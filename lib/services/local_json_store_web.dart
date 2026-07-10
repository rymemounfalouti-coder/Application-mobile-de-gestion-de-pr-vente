import 'dart:js_interop';

Future<String?> readLocalJson(String name) async => _localStorage.getItem(name);

Future<void> writeLocalJson(String name, String contents) async =>
    _localStorage.setItem(name, contents);

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

@JS('window.localStorage')
external _Storage get _localStorage;
