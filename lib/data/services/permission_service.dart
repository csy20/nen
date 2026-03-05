import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Handles runtime permission requests for audio media access.
class PermissionService {
  /// Request the appropriate audio permission based on platform/version.
  ///
  /// Android 13+ (API 33): READ_MEDIA_AUDIO
  /// Android 12-: READ_EXTERNAL_STORAGE
  /// iOS: Handled via Info.plist (NSAppleMusicUsageDescription)
  Future<bool> requestAudioPermission() async {
    if (Platform.isAndroid) {
      // On Android 13+, request READ_MEDIA_AUDIO.
      // On Android 12 and below, request READ_EXTERNAL_STORAGE.
      // permission_handler handles version detection internally for
      // Permission.audio (maps to READ_MEDIA_AUDIO on 33+).
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) return true;

      // Fallback for older Android versions
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }

    if (Platform.isIOS) {
      // iOS uses Info.plist key; no explicit runtime request needed for
      // on-device music files via MediaQuery, but we still check.
      final status = await Permission.mediaLibrary.request();
      return status.isGranted;
    }

    // Desktop — no permissions needed
    return true;
  }

  /// Check whether we already have permission.
  Future<bool> hasAudioPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.audio.isGranted) return true;
      return Permission.storage.isGranted;
    }
    if (Platform.isIOS) {
      return Permission.mediaLibrary.isGranted;
    }
    return true;
  }
}
