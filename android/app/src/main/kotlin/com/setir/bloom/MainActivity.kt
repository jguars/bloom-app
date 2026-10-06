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
    private var maxRate = 60f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighRefreshRate()
    }

    override fun onPostResume() {
        super.onPostResume()
        // Flutter draws into a SurfaceView; vote for the fast rate on it too.
        // MIUI's adaptive refresh follows per-surface votes, not just the window's.
        findSurface(window.decorView)?.let { voteOn(it) }
    }

    /**
     * Ask for the panel's fastest mode (e.g. 120 Hz). Without this, MIUI and
     * other skins keep apps that don't ask at 60 Hz, which feels choppy next
     * to the rest of the phone.
     */
    private fun preferHighRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        @Suppress("DEPRECATION")
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay) ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
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
