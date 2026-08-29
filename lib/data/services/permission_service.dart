import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'library_media_store.dart';

/// Handles runtime permission requests for audio media access.
class PermissionService {
  PermissionService({LibraryMediaStore? library})
    : _library = library ?? LibraryMediaStore();

  final LibraryMediaStore _library;

  /// Request the appropriate audio permission based on platform/version.
  ///
  /// Android 13+ (API 33): READ_MEDIA_AUDIO
  /// Android 12-: READ_EXTERNAL_STORAGE
  /// iOS: Handled via Info.plist (NSAppleMusicUsageDescription)
  Future<bool> requestAudioPermission() async {
    if (Platform.isAndroid) {
      // Request notification permission first (Android 13+ / API 33).
      // Required for foreground service media playback notifications.
      await Permission.notification.request();

      // Request both. Permission.audio is READ_MEDIA_AUDIO on API 33+ and a
      // no-op below that. Permission.storage is READ_EXTERNAL_STORAGE on
      // API 32- and a no-op on 33+. Asking both avoids a false "granted"
      // on older devices if audio is vacuously granted.
      final audioStatus = await Permission.audio.request();
      final storageStatus = await Permission.storage.request();
      if (!audioStatus.isGranted && !storageStatus.isGranted) {
        return false;
      }
      return _mediaStoreAccessible();
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
    try {
      if (Platform.isAndroid) {
        final osGranted =
            await Permission.audio.isGranted ||
            await Permission.storage.isGranted;
        if (!osGranted) return false;
        return _mediaStoreAccessible();
      }
      if (Platform.isIOS) {
        return Permission.mediaLibrary.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('hasAudioPermission error: $e');
      return false;
    }
  }

  /// OS grant can disagree with MediaStore on some OEMs / after updates.
  Future<bool> _mediaStoreAccessible() async {
    try {
      return await _library.probe();
    } catch (error) {
      if (error is PlatformException && error.code == 'permission_denied') {
        return false;
      }
      if (error is MissingPluginException) return true;
      return false;
    }
  }
}
