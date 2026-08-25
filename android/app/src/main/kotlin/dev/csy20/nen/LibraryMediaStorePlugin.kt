package dev.csy20.nen

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import android.util.Size
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Queries on-device audio through MediaStore using the application context.
 * Registered as a FlutterPlugin so the channel exists as soon as the engine
 * attaches — audio_service starts Dart before MainActivity can bind a raw
 * MethodChannel.
 */
class LibraryMediaStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var appContext: Context? = null
    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        val methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler(this)
        channel = methodChannel
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "probe" -> runAsync(result) { probe() }
            "querySongs" -> runAsync(result) { querySongs() }
            "queryArtwork" -> {
                val id = (call.argument<Number>("id"))?.toLong()
                if (id == null) {
                    result.error("bad_args", "id is required", null)
                    return
                }
                val size = call.argument<Int>("size") ?: 96
                val albumId = (call.argument<Number>("albumId"))?.toLong() ?: 0L
                runAsync(result) { queryArtwork(id, albumId, size) }
            }
            else -> result.notImplemented()
        }
    }

    private fun requireContext(): Context {
        return appContext ?: throw IllegalStateException("library plugin not attached")
    }

    private fun runAsync(result: MethodChannel.Result, action: () -> Any?) {
        queryExecutor.execute {
            try {
                val value = action()
                mainHandler.post {
                    try {
                        result.success(value)
                    } catch (e: Exception) {
                        Log.w(TAG, "reply failed", e)
                    }
                }
            } catch (e: SecurityException) {
                mainHandler.post {
                    try {
                        result.error("permission_denied", e.message, null)
                    } catch (err: Exception) {
                        Log.w(TAG, "permission reply failed", err)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "library query failed", e)
                mainHandler.post {
                    try {
                        result.error("query_failed", e.message, null)
                    } catch (err: Exception) {
                        Log.w(TAG, "error reply failed", err)
                    }
                }
            }
        }
    }

    private fun audioCollection(): Uri {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
    }

    private fun probe(): Map<String, Any> {
        val context = requireContext()
        context.contentResolver.query(
            audioCollection(),
            arrayOf(MediaStore.Audio.Media._ID),
            null,
            null,
            "${MediaStore.Audio.Media._ID} ASC",
        )?.use { /* opening the cursor is the permission check */ }
        val ok = HashMap<String, Any>(1)
        ok["ok"] = true
        return ok
    }

    private fun querySongs(): ArrayList<HashMap<String, Any?>> {
        val context = requireContext()
        val collection = audioCollection()
        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.ARTIST_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.IS_MUSIC,
            MediaStore.Audio.Media.IS_RINGTONE,
            MediaStore.Audio.Media.IS_NOTIFICATION,
            MediaStore.Audio.Media.IS_ALARM,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection.add(MediaStore.Audio.Media.RELATIVE_PATH)
        }
        projection.add(MediaStore.Audio.Media.DATA)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            projection.add(MediaStore.Audio.Media.YEAR)
        }

        val sort = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
        val songs = ArrayList<HashMap<String, Any?>>()
        val cursor = try {
            context.contentResolver.query(
                collection,
                projection.toTypedArray(),
                null,
                null,
                sort,
            )
        } catch (_: IllegalArgumentException) {
            val essential = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.ALBUM_ID,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.DISPLAY_NAME,
            )
            context.contentResolver.query(collection, essential, null, null, sort)
        }
        cursor?.use { rows ->
            fun idx(column: String): Int = rows.getColumnIndex(column)

            val idCol = idx(MediaStore.Audio.Media._ID)
            val titleCol = idx(MediaStore.Audio.Media.TITLE)
            val artistCol = idx(MediaStore.Audio.Media.ARTIST)
            val albumCol = idx(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = idx(MediaStore.Audio.Media.ALBUM_ID)
            val artistIdCol = idx(MediaStore.Audio.Media.ARTIST_ID)
            val durationCol = idx(MediaStore.Audio.Media.DURATION)
            val sizeCol = idx(MediaStore.Audio.Media.SIZE)
            val trackCol = idx(MediaStore.Audio.Media.TRACK)
            val displayCol = idx(MediaStore.Audio.Media.DISPLAY_NAME)
            val dataCol = idx(MediaStore.Audio.Media.DATA)
            val relativeCol = idx(MediaStore.Audio.Media.RELATIVE_PATH)
            val yearCol = idx(MediaStore.Audio.Media.YEAR)
            val ringtoneCol = idx(MediaStore.Audio.Media.IS_RINGTONE)
            val notificationCol = idx(MediaStore.Audio.Media.IS_NOTIFICATION)
            val alarmCol = idx(MediaStore.Audio.Media.IS_ALARM)

            while (rows.moveToNext()) {
                if (idCol < 0) continue
                if (isFlagSet(rows, ringtoneCol) ||
                    isFlagSet(rows, notificationCol) ||
                    isFlagSet(rows, alarmCol)
                ) {
                    continue
                }

                val id = rows.getLong(idCol)
                val displayName = stringOrEmpty(rows, displayCol)
                val filePath = stringOrEmpty(rows, dataCol)
                val map = HashMap<String, Any?>(16)
                map["id"] = id
                map["title"] = stringOrEmpty(rows, titleCol).ifEmpty { displayName }
                map["artist"] = stringOrEmpty(rows, artistCol)
                map["album"] = stringOrEmpty(rows, albumCol)
                map["albumId"] = longOrZero(rows, albumIdCol)
                map["artistId"] = longOrZero(rows, artistIdCol)
                map["duration"] = longOrZero(rows, durationCol)
                map["filePath"] = filePath
                map["relativePath"] = stringOrEmpty(rows, relativeCol)
                map["displayName"] = displayName
                map["uri"] = ContentUris.withAppendedId(collection, id).toString()
                map["fileExtension"] = fileExtension(displayName, filePath)
                map["fileSize"] = longOrZero(rows, sizeCol)
                map["trackNumber"] = intOrZero(rows, trackCol)
                map["year"] = intOrZero(rows, yearCol)
                songs.add(map)
            }
        }
        return songs
    }

    private fun queryArtwork(songId: Long, albumId: Long, size: Int): ByteArray? {
        val context = requireContext()
        val safeSize = size.coerceIn(32, 1024)
        val songUri = ContentUris.withAppendedId(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            songId,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val bitmap = context.contentResolver.loadThumbnail(
                    songUri,
                    Size(safeSize, safeSize),
                    null,
                )
                return encodeJpeg(bitmap)
            } catch (_: Exception) {
            }
        }

        if (albumId > 0L) {
            val artUri = ContentUris.withAppendedId(
                Uri.parse("content://media/external/audio/albumart"),
                albumId,
            )
            try {
                context.contentResolver.openInputStream(artUri)?.use { stream ->
                    val bytes = stream.readBytes()
                    if (bytes.isNotEmpty()) return bytes
                }
            } catch (_: Exception) {
            }
        }

        var retriever: MediaMetadataRetriever? = null
        try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(context, songUri)
            val embedded = retriever.embeddedPicture ?: return null
            val decoded = BitmapFactory.decodeByteArray(embedded, 0, embedded.size)
                ?: return embedded
            val scaled = Bitmap.createScaledBitmap(decoded, safeSize, safeSize, true)
            if (scaled != decoded) decoded.recycle()
            return encodeJpeg(scaled)
        } catch (_: Exception) {
            return null
        } finally {
            try {
                retriever?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun encodeJpeg(bitmap: Bitmap): ByteArray {
        val out = ByteArrayOutputStream()
        try {
            bitmap.compress(Bitmap.CompressFormat.JPEG, 70, out)
            return out.toByteArray()
        } finally {
            if (!bitmap.isRecycled) {
                bitmap.recycle()
            }
        }
    }

    private fun isFlagSet(cursor: android.database.Cursor, column: Int): Boolean {
        if (column < 0) return false
        return cursor.getInt(column) != 0
    }

    private fun stringOrEmpty(cursor: android.database.Cursor, column: Int): String {
        if (column < 0 || cursor.isNull(column)) return ""
        return cursor.getString(column).orEmpty()
    }

    private fun longOrZero(cursor: android.database.Cursor, column: Int): Long {
        if (column < 0 || cursor.isNull(column)) return 0L
        return cursor.getLong(column)
    }

    private fun intOrZero(cursor: android.database.Cursor, column: Int): Int {
        if (column < 0 || cursor.isNull(column)) return 0
        return cursor.getInt(column)
    }

    private fun fileExtension(displayName: String, filePath: String): String {
        val name = displayName.ifEmpty { filePath.substringAfterLast('/') }
        val dot = name.lastIndexOf('.')
        if (dot <= 0 || dot == name.length - 1) return ""
        return name.substring(dot + 1).lowercase()
    }

    companion object {
        const val CHANNEL = "dev.csy20.nen/library"
        private const val TAG = "NenLibrary"

        private val queryExecutor: java.util.concurrent.ExecutorService =
            Executors.newSingleThreadExecutor { runnable ->
                Thread(runnable, "nen-library").apply { isDaemon = true }
            }
    }
}
