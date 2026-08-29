package dev.csy20.nen

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.min
import kotlin.math.sqrt

class PlaybackVisualizerPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private var method: MethodChannel? = null
    private var events: EventChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var workerThread: HandlerThread? = null
    private var worker: Handler? = null
    private var visualizer: Visualizer? = null
    private var sink: EventChannel.EventSink? = null
    private var generation = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        val methodChannel = MethodChannel(messenger, CHANNEL)
        val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        method = methodChannel
        events = eventChannel
        val thread = HandlerThread("nen-visualizer")
        thread.start()
        workerThread = thread
        worker = Handler(thread.looper)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val gen = synchronized(lock) { ++generation }
        worker?.post { stopLocked(gen) }
        workerThread?.quitSafely()
        workerThread = null
        worker = null
        method?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        method = null
        events = null
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val sessionId = (call.arguments as? Number)?.toInt() ?: 0
                if (sessionId <= 0) {
                    result.success(false)
                    return
                }
                val handler = worker
                if (handler == null) {
                    result.success(false)
                    return
                }
                val gen = synchronized(lock) { ++generation }
                handler.post {
                    val ok = startLocked(sessionId, gen)
                    mainHandler.post { result.success(ok) }
                }
            }
            "stop" -> {
                val gen = synchronized(lock) { ++generation }
                worker?.post { stopLocked(gen) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun startLocked(sessionId: Int, gen: Int): Boolean {
        stopLocked(gen)
        if (!stillCurrent(gen)) return false
        return try {
            val range = Visualizer.getCaptureSizeRange()
            if (range == null || range.size < 2 || range[1] <= 0) {
                Log.w(TAG, "visualizer capture size unavailable")
                return false
            }
            val captureSize = largestPowerOfTwoInRange(range[0], range[1])
            if (captureSize < 128) {
                Log.w(TAG, "visualizer capture size too small: $captureSize")
                return false
            }
            val viz = Visualizer(sessionId)
            viz.enabled = false
            viz.captureSize = captureSize
            val rate = Visualizer.getMaxCaptureRate().coerceIn(8_000, 15_000)
            viz.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        visualizer: Visualizer?,
                        waveform: ByteArray?,
                        samplingRate: Int,
                    ) {}

                    override fun onFftDataCapture(
                        visualizer: Visualizer?,
                        fft: ByteArray?,
                        samplingRate: Int,
                    ) {
                        if (!stillCurrent(gen)) return
                        if (fft == null || fft.size < 4) return
                        val out = ArrayList<Double>(256)
                        val pairs = min(256, (fft.size - 2) / 2)
                        for (i in 0 until 256) {
                            if (i >= pairs) {
                                out.add(0.0)
                                continue
                            }
                            val re = fft[2 + i * 2].toInt().toDouble()
                            val im = fft[3 + i * 2].toInt().toDouble()
                            var mag = sqrt(re * re + im * im) / 90.0
                            if (mag > 1.0) mag = 1.0
                            out.add(mag)
                        }
                        mainHandler.post {
                            if (!stillCurrent(gen)) return@post
                            sink?.success(out)
                        }
                    }
                },
                rate,
                false,
                true,
            )
            viz.enabled = true
            synchronized(lock) {
                if (!stillCurrent(gen)) {
                    try {
                        viz.enabled = false
                        viz.release()
                    } catch (_: Throwable) {
                    }
                    return false
                }
                visualizer = viz
            }
            true
        } catch (t: Throwable) {
            Log.w(TAG, "visualizer start failed session=$sessionId", t)
            stopLocked(gen)
            false
        }
    }

    private fun stopLocked(gen: Int) {
        val viz = synchronized(lock) {
            val current = visualizer
            visualizer = null
            current
        } ?: return
        try {
            viz.setDataCaptureListener(null, 0, false, false)
        } catch (_: Throwable) {
        }
        try {
            viz.enabled = false
        } catch (_: Throwable) {
        }
        try {
            viz.release()
        } catch (_: Throwable) {
        }
        // gen is used to invalidate in-flight start() posts
        if (gen < 0) return
    }

    private fun stillCurrent(gen: Int): Boolean {
        synchronized(lock) {
            return gen == generation
        }
    }

    companion object {
        const val CHANNEL = "dev.csy20.nen/visualizer"
        const val EVENT_CHANNEL = "dev.csy20.nen/visualizer/fft"
        private const val TAG = "NenVisualizer"

        fun largestPowerOfTwoInRange(min: Int, max: Int): Int {
            var size = 128
            var best = 0
            while (size <= max) {
                if (size >= min) best = size
                size *= 2
            }
            return best
        }
    }
}
