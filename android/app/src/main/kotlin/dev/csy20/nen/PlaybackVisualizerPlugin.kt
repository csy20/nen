package dev.csy20.nen

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.min
import kotlin.math.sqrt

class PlaybackVisualizerPlugin(
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val method = MethodChannel(messenger, CHANNEL)
    private val events = EventChannel(messenger, EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var visualizer: Visualizer? = null
    private var sink: EventChannel.EventSink? = null

    init {
        method.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val sessionId = call.arguments as? Int
                if (sessionId == null || sessionId <= 0) {
                    result.error("bad_session", "Invalid audio session id", null)
                    return
                }
                try {
                    start(sessionId)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("start_failed", e.message, null)
                }
            }
            "stop" -> {
                stop()
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

    private fun start(sessionId: Int) {
        stop()
        val captureSize = Visualizer.getCaptureSizeRange().let { range ->
            1024.coerceIn(range[0], range[1])
        }
        val viz = Visualizer(sessionId)
        viz.enabled = false
        viz.captureSize = captureSize
        val rate = Visualizer.getMaxCaptureRate().coerceAtMost(20_000)
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
                    mainHandler.post { sink?.success(out) }
                }
            },
            rate,
            false,
            true,
        )
        viz.enabled = true
        visualizer = viz
    }

    private fun stop() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (_: Exception) {
        }
        visualizer = null
    }

    companion object {
        const val CHANNEL = "dev.csy20.nen/visualizer"
        const val EVENT_CHANNEL = "dev.csy20.nen/visualizer/fft"

        fun register(messenger: BinaryMessenger) {
            PlaybackVisualizerPlugin(messenger)
        }
    }
}
