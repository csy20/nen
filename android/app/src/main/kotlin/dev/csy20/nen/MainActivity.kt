package dev.csy20.nen

import android.content.Context
import android.os.Bundle
import android.util.Log
import com.lucasjosino.on_audio_query.PluginProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val engine = super.provideFlutterEngine(context)
            ?: error("AudioService Flutter engine missing")
        registerNenPlugins(engine)
        return engine
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerNenPlugins(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bindOnAudioQueryContext()
    }

    override fun onResume() {
        super.onResume()
        bindOnAudioQueryContext()
    }

    private fun registerNenPlugins(engine: FlutterEngine) {
        if (!engine.plugins.has(LibraryMediaStorePlugin::class.java)) {
            engine.plugins.add(LibraryMediaStorePlugin())
        }
        PlaybackVisualizerPlugin.register(engine.dartExecutor.binaryMessenger)
        bindOnAudioQueryContext()
    }

    /**
     * on_audio_query only stores context in onAttachedToActivity. audio_service
     * starts Dart before that callback, and minified Play builds can skip it.
     * Force-feed the activity so leftover plugin calls don't crash.
     */
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
