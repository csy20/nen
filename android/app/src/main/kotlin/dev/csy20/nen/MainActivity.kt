package dev.csy20.nen

import android.content.Context
import android.os.Bundle
import android.util.Log
import com.lucasjosino.on_audio_query.PluginProvider
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            if (!flutterEngine.plugins.has(LibraryMediaStorePlugin::class.java)) {
                flutterEngine.plugins.add(LibraryMediaStorePlugin())
            }
        } catch (t: Throwable) {
            Log.w(TAG, "library plugin register failed", t)
        }
        bindOnAudioQueryContext()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bindOnAudioQueryContext()
    }

    override fun onResume() {
        super.onResume()
        bindOnAudioQueryContext()
    }

    private fun bindOnAudioQueryContext() {
        try {
            PluginProvider.set(this)
        } catch (t: Throwable) {
            Log.w(TAG, "on_audio_query context init failed", t)
        }
    }

    companion object {
        private const val TAG = "NenMainActivity"
    }
}
