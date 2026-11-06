import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 휴대폰 안의 앱 전용 폴더에 데이터를 저장해요. 서버로 보내지 않아요.
abstract class Storage {
  Future<String?> readData();
  Future<void> writeData(String json);
  Future<String> savePhoto(String name, Uint8List bytes);
  Future<Uint8List?> readPhoto(String name);
  Future<void> deletePhoto(String name);
  Future<List<String>> listPhotos();
  Future<int> photoBytes();
  Future<void> clearAll();
  String? photoPath(String name);

  static Future<Storage> create() async {
    if (kIsWeb) return MemoryStorage();
    final dir = await getApplicationDocumentsDirectory();
    final s = FileStorage(dir);
    await s.init();
    return s;
  }
}

class FileStorage implements Storage {
  FileStorage(this.root);

  final Directory root;
  late final File _data = File('${root.path}/app_data.json');
  late final Directory _photos = Directory('${root.path}/photos');

  Future<void> init() async {
    if (!await _photos.exists()) await _photos.create(recursive: true);
  }

  @override
  Future<String?> readData() async =>
      await _data.exists() ? _data.readAsString() : null;

  /// 임시 파일에 쓴 뒤 바꿔 넣어서 쓰는 도중 앱이 꺼져도 데이터가 깨지지 않게 해요.
  @override
  Future<void> writeData(String json) async {
    final tmp = File('${_data.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_data.path);
  }

  @override
  Future<String> savePhoto(String name, Uint8List bytes) async {
    await File('${_photos.path}/$name').writeAsBytes(bytes, flush: true);
    return name;
  }

  @override
  Future<Uint8List?> readPhoto(String name) async {
    final f = File('${_photos.path}/$name');
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> deletePhoto(String name) async {
    final f = File('${_photos.path}/$name');
    if (await f.exists()) await f.delete();
  }

  @override
  Future<List<String>> listPhotos() async => (await _photos.list().toList())
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .toList();

  @override
  Future<int> photoBytes() async {
    var n = 0;
    await for (final f in _photos.list()) {
      if (f is File) n += await f.length();
    }
    return n;
  }

  @override
  Future<void> clearAll() async {
    if (await _data.exists()) await _data.delete();
    if (await _photos.exists()) await _photos.delete(recursive: true);
    await _photos.create(recursive: true);
  }

  @override
  String? photoPath(String name) => '${_photos.path}/$name';
}

/// 웹 미리보기 · 테스트용 (앱을 닫으면 사라져요).
class MemoryStorage implements Storage {
  String? _data;
  final Map<String, Uint8List> _photos = {};

  @override
  Future<String?> readData() async => _data;
  @override
  Future<void> writeData(String json) async => _data = json;
  @override
  Future<String> savePhoto(String name, Uint8List bytes) async {
    _photos[name] = bytes;
    return name;
  }

  @override
  Future<Uint8List?> readPhoto(String name) async => _photos[name];
  @override
  Future<void> deletePhoto(String name) async => _photos.remove(name);
  @override
  Future<List<String>> listPhotos() async => _photos.keys.toList();
  @override
  Future<int> photoBytes() async =>
      _photos.values.fold<int>(0, (a, b) => a + b.length);
  @override
  Future<void> clearAll() async {
    _data = null;
    _photos.clear();
  }

  @override
  String? photoPath(String name) => null;

  Map<String, dynamic>? get decoded =>
      _data == null ? null : jsonDecode(_data!) as Map<String, dynamic>;
}
