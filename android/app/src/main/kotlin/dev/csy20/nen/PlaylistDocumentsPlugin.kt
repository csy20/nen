package dev.csy20.nen

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/** User-owned backups: never export into Android/data or app-specific storage. */
class PlaylistDocumentsPlugin : FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activityBinding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private var exportContents: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.csy20.nen/documents")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        fail("document_cancelled", "Document operation was interrupted")
        ioExecutor.shutdown()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
        fail("document_cancelled", "Document operation was interrupted")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "savePlaylistBackup" && call.method != "openPlaylistBackup") {
            result.notImplemented()
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("no_activity", "Open nen to choose a document", null)
            return
        }
        if (pending != null) {
            result.error("document_busy", "A document picker is already open", null)
            return
        }
        val exporting = call.method == "savePlaylistBackup"
        val contents = if (exporting) call.argument<String>("contents") else null
        if (exporting && contents == null) {
            result.error("invalid_backup", "Playlist backup contents are required", null)
            return
        }
        val intent = Intent(if (exporting) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            if (exporting) {
                type = "application/json"
                putExtra(Intent.EXTRA_TITLE, "nen_playlists.json")
            } else {
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
            }
        }
        pending = result
        exportContents = contents
        try {
            activity.startActivityForResult(intent, if (exporting) EXPORT_REQUEST else IMPORT_REQUEST)
        } catch (error: Exception) {
            fail("document_unavailable", "Could not open the system document picker")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != EXPORT_REQUEST && requestCode != IMPORT_REQUEST) return false
        val reply = pending ?: return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            complete(null)
            return true
        }
        val contents = exportContents
        ioExecutor.execute {
            try {
                val value: Any = if (requestCode == EXPORT_REQUEST) {
                    val output = context.contentResolver.openOutputStream(uri, "wt")
                        ?: throw java.io.IOException("Could not write the selected document")
                    output.bufferedWriter(Charsets.UTF_8).use { it.write(contents!!) }
                    true
                } else {
                    val input = context.contentResolver.openInputStream(uri)
                        ?: throw java.io.IOException("Could not read the selected document")
                    input.bufferedReader(Charsets.UTF_8).use { reader ->
                        val text = StringBuilder()
                        val buffer = CharArray(8192)
                        while (true) {
                            val count = reader.read(buffer)
                            if (count < 0) break
                            if (text.length + count > MAX_BACKUP_CHARS) {
                                throw java.io.IOException("Playlist backup is too large")
                            }
                            text.append(buffer, 0, count)
                        }
                        text.toString()
                    }
                }
                mainHandler.post { if (pending === reply) complete(value) }
            } catch (error: Exception) {
                mainHandler.post {
                    if (pending === reply) fail("document_io_error", "Could not access the selected document")
                }
            }
        }
        return true
    }

    private fun complete(value: Any?) {
        val reply = pending
        pending = null
        exportContents = null
        reply?.success(value)
    }

    private fun fail(code: String, message: String) {
        val reply = pending
        pending = null
        exportContents = null
        reply?.error(code, message, null)
    }

    companion object {
        private const val EXPORT_REQUEST = 42021
        private const val IMPORT_REQUEST = 42022
        private const val MAX_BACKUP_CHARS = 10 * 1024 * 1024
    }
}
