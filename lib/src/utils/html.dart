import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'utils_impl.dart';

/// Utils class
class Utils implements UtilsImpl {
  Utils._();

  static final Utils _utils = Utils._();

  static Utils get instance => _utils;

  @override
  Future<Map<String, dynamic>?> get(String path, [bool? isCollection = false, List<List>? conditions]) async {
    // Fetch the documents for this collection
    if (isCollection != null && isCollection == true) {
      var dataCol = web.window.localStorage.entries.singleWhere(
        (e) => e.key == path,
        orElse: () => const MapEntry('', ''),
      );
      if (dataCol.key != '') {
        if (conditions != null && conditions.first.isNotEmpty) {
          return _getAll(dataCol);
        } else {
          return _getAll(dataCol);
        }
      }
    } else {
      final data = await _readFromStorage(path);
      final id = path.substring(path.lastIndexOf('/') + 1, path.length);
      if (data is Map<String, dynamic>) {
        if (data.containsKey(id)) return data[id];
        return null;
      }
    }
    return null;
  }

  @override
  Future<dynamic>? set(Map<String, dynamic> data, String path) {
    return _writeToStorage(data, path);
  }

  @override
  Future delete(String path) async {
    _deleteFromStorage(path);
  }

  @override
  Stream<Map<String, dynamic>> stream(String path, [List<List>? conditions]) {
    // ignore: close_sinks
    final storage = _storageCache[path] ??
        _storageCache.putIfAbsent(path, () => StreamController<Map<String, dynamic>>.broadcast());

    _initStream(storage, path);
    return storage.stream;
  }

  Map<String, dynamic>? _getAll(MapEntry<String, String> dataCol) {
    final items = <String, dynamic>{};
    try {
      final mapCol = json.decode(dataCol.value) as Map<String, dynamic>;
      mapCol.forEach((key, value) {
        final data = value as Map<String, dynamic>;
        items[key] = data;
      });
      if (items.isEmpty) return null;
      return items;
    } catch (error) {
      rethrow;
    }
  }

  void _initStream(StreamController<Map<String, dynamic>> storage, String path) {
    var dataCol = web.window.localStorage.entries.singleWhere(
      (e) => e.key == path,
      orElse: () => const MapEntry('', ''),
    );
    try {
      if (dataCol.key != '') {
        final mapCol = json.decode(dataCol.value) as Map<String, dynamic>;
        mapCol.forEach((key, value) {
          final data = value as Map<String, dynamic>;
          storage.add(data);
        });
      }
    } catch (error) {
      rethrow;
    }
  }

  final _storageCache = <String, StreamController<Map<String, dynamic>>>{};

  Future<dynamic> _readFromStorage(String path) async {
    final key = path.replaceAll(RegExp(r'[^\/]+\/?$'), '');
    final data = web.window.localStorage.entries.firstWhere(
      (i) => i.key == key,
      orElse: () => const MapEntry('', ''),
    );
    if (data != const MapEntry('', '')) {
      try {
        return json.decode(data.value) as Map<String, dynamic>;
      } catch (e) {
        return e;
      }
    }
  }

  Future<dynamic> _writeToStorage(
    Map<String, dynamic> data,
    String path,
  ) async {
    final key = path.replaceAll(RegExp(r'[^\/]+\/?$'), '');

    final uri = Uri.parse(path);
    final id = uri.pathSegments.last;
    var dataCol = web.window.localStorage.entries.singleWhere(
      (e) => e.key == key,
      orElse: () => const MapEntry('', ''),
    );
    try {
      if (dataCol.key != '') {
        final mapCol = json.decode(dataCol.value) as Map<String, dynamic>;
        mapCol[id] = data;
        dataCol = MapEntry(id, json.encode(mapCol));
        web.window.localStorage.update(
          key,
          (value) => dataCol.value,
          ifAbsent: () => dataCol.value,
        );
      } else {
        web.window.localStorage.update(
          key,
          (value) => json.encode({id: data}),
          ifAbsent: () => json.encode({id: data}),
        );
      }
      // ignore: close_sinks
      final storage = _storageCache[key] ??
          _storageCache.putIfAbsent(key, () => StreamController<Map<String, dynamic>>.broadcast());

      storage.sink.add(data);
    } catch (error) {
      rethrow;
    }
  }

  Future<dynamic> _deleteFromStorage(String path) async {
    if (path.endsWith('/')) {
      // If path is a directory path
      final dataCol = web.window.localStorage.entries.singleWhere(
        (element) => element.key == path,
        orElse: () => const MapEntry('', ''),
      );

      try {
        if (dataCol.key != '') {
          web.window.localStorage.delete(dataCol.key.toJS);
        }
      } catch (error) {
        rethrow;
      }
    } else {
      // If path is a file path
      final uri = Uri.parse(path);
      final key = path.replaceAll(RegExp(r'[^\/]+\/?$'), '');
      final id = uri.pathSegments.last;
      var dataCol = web.window.localStorage.entries.singleWhere(
        (e) => e.key == key,
        orElse: () => const MapEntry('', ''),
      );

      try {
        if (dataCol.key != '') {
          final mapCol = json.decode(dataCol.value) as Map<String, dynamic>;
          mapCol.remove(id);
          web.window.localStorage.update(
            key,
            (value) => json.encode(mapCol),
            ifAbsent: () => dataCol.value,
          );
        }
      } catch (error) {
        rethrow;
      }
    }
  }

  @override
  void setCustomSavePath(String path) {}

  @override
  void setUseSupportDirectory(bool useSupportDir) {}
}

//
extension on web.Storage {
  void forEach(void f(String key, String value)) {
    for (var i = 0; true; i++) {
      final item = key(i);
      if (item == null) return;

      f(item, this[item]!);
    }
  }

  Iterable<String> get keys {
    final keys = <String>[];
    forEach((k, v) => keys.add(k));
    return keys;
  }

  Iterable<String> get values {
    final values = <String>[];
    forEach((k, v) => values.add(v));
    return values;
  }

  Iterable<MapEntry<String, String>> get entries {
    return keys.map((String key) => MapEntry<String, String>(key, this[key] as String));
  }

  String update(String key, String update(String value), {String Function()? ifAbsent}) {
    if (this.containsKey(key)) {
      return this[key] = update(this[key] as String);
    }
    if (ifAbsent != null) {
      return this[key] = ifAbsent();
    }
    throw ArgumentError.value(key, "key", "Key not in map.");
  }

  // TODO(nweiz): update this when maps support lazy iteration
  bool containsValue(Object? value) => values.any((e) => e == value);

  bool containsKey(Object? key) => getItem(key as String) != null;
}
