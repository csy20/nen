import 'package:flutter/services.dart';

import '../../domain/audio/audio_format.dart';
import '../../domain/entities/entities.dart';

/// Thrown when the on-device library cannot be read.
class LibraryAccessException implements Exception {
  final String message;
  final bool permissionDenied;
  const LibraryAccessException(this.message, {this.permissionDenied = false});

  @override
  String toString() => message;
}

/// Native MediaStore client. Uses application context, not Activity.
class LibraryMediaStore {
  LibraryMediaStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dev.csy20.nen/library');

  final MethodChannel _channel;

  Future<int> sdkInt() async {
    final value = await _channel.invokeMethod<int>('sdkInt');
    return value ?? 0;
  }

  /// Returns true if MediaStore can be opened. False on permission denial.
  Future<bool> probe() async {
    try {
      await _channel.invokeMethod<dynamic>('probe');
      return true;
    } on PlatformException catch (error) {
      if (error.code == 'permission_denied') return false;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> querySongs() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('querySongs');
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }

  Future<Uint8List?> queryArtwork(
    int songId, {
    int size = 96,
    int albumId = 0,
  }) async {
    final raw = await _channel.invokeMethod<Uint8List>('queryArtwork', {
      'id': songId,
      'size': size,
      'albumId': albumId,
    });
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

int nativeInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

String nativeString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

Song songFromNativeRow(Map<String, dynamic> row) {
  final filePath = nativeString(row['filePath']);
  final displayName = nativeString(row['displayName']);
  return Song(
    id: nativeInt(row['id']),
    title: nativeString(row['title'], 'Unknown Title'),
    artist: _unknownIfBlank(nativeString(row['artist']), 'Unknown Artist'),
    album: _unknownIfBlank(nativeString(row['album']), 'Unknown Album'),
    albumId: nativeInt(row['albumId']),
    artistId: nativeInt(row['artistId']),
    duration: Duration(milliseconds: nativeInt(row['duration'])),
    // Never substitute MediaStore RELATIVE_PATH for a filesystem path.
    // On Android 10+ DATA is often empty; playback must use [uri].
    filePath: filePath,
    uri: nativeString(row['uri']),
    fileExtension: AudioFormat.normalizeExtension(
      nativeString(row['fileExtension']),
      fallbackPath: filePath.isNotEmpty ? filePath : displayName,
    ),
    fileSize: nativeInt(row['fileSize']),
    trackNumber: nativeInt(row['trackNumber']),
    year: nativeInt(row['year']),
  );
}

String _unknownIfBlank(String value, String fallback) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '<unknown>') return fallback;
  return trimmed;
}

String libraryErrorMessage(Object error) {
  if (error is LibraryAccessException) return error.message;
  final text = error.toString();
  if (text.contains('lateinit') ||
      text.contains('PluginProvider') ||
      text.contains('MissingPermissions') ||
      text.contains('permission_denied')) {
    return 'Could not access your music library. Pull to retry, or grant audio permission in system settings.';
  }
  if (text.contains('PlatformException') || text.length > 140) {
    return 'Could not load your music library. Please try again.';
  }
  return text;
}
