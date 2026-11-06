import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/models.dart';
import 'storage.dart';

/// 백업 파일 (.zip): manifest.json + data.json + photos/*
class Backup {
  static const manifestName = 'manifest.json';
  static const dataName = 'data.json';
  static const photoDir = 'photos/';
  static const format = 'parkgolf-diary-backup';

  static String fileName(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'parkgolf-backup-${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}.zip';
  }

  static Future<Uint8List> build(
      AppData data, Storage storage, DateTime at) async {
    final archive = Archive();
    final rounds = data.rounds.where((r) => r.deletedAt == null).length;
    final photos = <String>{for (final r in data.rounds) ...r.photos};
    archive.addFile(ArchiveFile.string(
        manifestName,
        jsonEncode({
          'format': format,
          'version': AppData.schemaVersion,
          'createdAt': at.toIso8601String(),
          'rounds': rounds,
          'photos': photos.length,
        })));
    archive.addFile(ArchiveFile.string(dataName, jsonEncode(data.toJson())));
    for (final p in photos) {
      final bytes = await storage.readPhoto(p);
      if (bytes != null) {
        archive.addFile(ArchiveFile.noCompress('$photoDir$p', bytes.length, bytes));
      }
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// 백업 파일을 읽어요. 형식이 맞지 않으면 [FormatException].
  static BackupContent read(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('백업 파일이 아니에요');
    }
    final manifestFile = archive.findFile(manifestName);
    final dataFile = archive.findFile(dataName);
    if (manifestFile == null || dataFile == null) {
      throw const FormatException('백업 파일이 아니에요');
    }
    final manifest =
        jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
    if (manifest['format'] != format) {
      throw const FormatException('백업 파일이 아니에요');
    }
    final data = AppData.fromJson(
        jsonDecode(utf8.decode(dataFile.content)) as Map<String, dynamic>);
    final photos = <String, Uint8List>{};
    for (final f in archive.files) {
      if (f.isFile && f.name.startsWith(photoDir)) {
        final name = f.name.substring(photoDir.length);
        if (name.isNotEmpty && !name.contains('/') && !name.contains('..')) {
          photos[name] = f.content;
        }
      }
    }
    return BackupContent(
      createdAt: DateTime.tryParse('${manifest['createdAt']}'),
      data: data,
      photos: photos,
      sizeBytes: bytes.length,
    );
  }
}

class BackupContent {
  BackupContent({
    required this.createdAt,
    required this.data,
    required this.photos,
    required this.sizeBytes,
  });

  final DateTime? createdAt;
  final AppData data;
  final Map<String, Uint8List> photos;
  final int sizeBytes;

  int get roundCount => data.rounds.where((r) => r.deletedAt == null).length;
}

String formatBytes(int b) {
  if (b < 1024) return '${b}B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)}KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
}
