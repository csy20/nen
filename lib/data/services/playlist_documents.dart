import 'package:flutter/services.dart';

/// Saves and opens playlist backups through Android's system document picker.
/// A null/false reply represents user cancellation.
class PlaylistDocuments {
  PlaylistDocuments({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dev.csy20.nen/documents');

  final MethodChannel _channel;

  Future<bool> save(String contents) async {
    return await _channel.invokeMethod<bool>('savePlaylistBackup', {
          'contents': contents,
        }) ==
        true;
  }

  Future<String?> open() => _channel.invokeMethod<String>('openPlaylistBackup');
}
