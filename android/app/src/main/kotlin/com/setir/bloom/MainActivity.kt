package com.setir.bloom

import android.os.Build
import android.os.Bundle
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var maxRate = 60f  // the rate asked for (named before the switch to 60 Hz)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferSteadyRefreshRate()
    }

    override fun onPostResume() {
        super.onPostResume()
        // Flutter draws into a SurfaceView; vote for the same rate on it too.
        // MIUI's adaptive refresh follows per-surface votes, not just the window's.
        findSurface(window.decorView)?.let { voteOn(it) }
    }

    /**
     * Ask for a steady 60 Hz. Clover's scenes animate every frame, so at 120 Hz
     * the phone did twice the work for motion that looks the same, which kept a
     * CPU core busy and heated the phone. (Pinning a rate also stops MIUI's
     * adaptive refresh from bouncing between modes.)
     */
    private fun preferSteadyRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        @Suppress("DEPRECATION")
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay) ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .minByOrNull { kotlin.math.abs(it.refreshRate - 60f) } ?: return
        maxRate = best.refreshRate
        window.attributes = window.attributes.also {
            it.preferredDisplayModeId = best.modeId
            it.preferredRefreshRate = best.refreshRate
        }
    }

    private fun voteOn(view: SurfaceView) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        fun vote(holder: SurfaceHolder) {
            val s = holder.surface
            if (s != null && s.isValid) s.setFrameRate(maxRate, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
        }
        vote(view.holder)
        view.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) = vote(holder)
            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) = vote(holder)
            override fun surfaceDestroyed(holder: SurfaceHolder) {}
        })
    }

    private fun findSurface(v: View): SurfaceView? {
        if (v is SurfaceView) return v
        if (v is ViewGroup) for (i in 0 until v.childCount) findSurface(v.getChildAt(i))?.let { return it }
        return null
    }
}
