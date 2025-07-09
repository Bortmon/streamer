package com.example.streamer

import android.view.ViewGroup
import androidx.mediarouter.app.MediaRouteButton
import androidx.mediarouter.app.MediaRouteChooserDialog
import androidx.mediarouter.media.MediaRouter
import androidx.mediarouter.media.MediaRouteSelector
import androidx.appcompat.view.ContextThemeWrapper
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import com.google.android.gms.cast.MediaLoadRequestData
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private companion object {
        const val CHANNEL_NAME = "com.example.streamer/cast"
    }

    private val castContext: CastContext by lazy {
        CastContext.getSharedInstance(applicationContext)
    }

    private var sessionManagerListener: SessionManagerListener<CastSession>? = null
    private var pendingUrlToCast: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        setupSessionManagerListener()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSmartCasting" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        startSmartCasting(url)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "URL kan niet null zijn", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startSmartCasting(url: String) {
        val castSession = castContext.sessionManager.currentCastSession
        if (castSession != null && castSession.isConnected) {
            castVideo(url)
        } else {
            pendingUrlToCast = url
            showCastDialog()
        }
    }

    private fun showCastDialog() {
        println("Programmatisch de Cast-dialoog tonen via een virtuele knop...")

        try {

            val castButton = MediaRouteButton(this)

            val selector = MediaRouteSelector.Builder()
                .addControlCategory(CastMediaControlIntent.categoryForCast(castContext.castOptions.receiverApplicationId))
                .build()
            castButton.routeSelector = selector


            val rootView = findViewById<ViewGroup>(android.R.id.content)
            rootView.addView(castButton)


            castButton.performClick()


            castButton.postDelayed({
                try {
                    rootView.removeView(castButton)
                } catch (e: Exception) {

                }
            }, 200)

        } catch (e: Exception) {
            println("MediaRouteButton methode gefaald: ${e.message}")
            try {
                val themedContext = ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Light_Dialog)
                val dialog = MediaRouteChooserDialog(themedContext)
                val selector = MediaRouteSelector.Builder()
                    .addControlCategory(CastMediaControlIntent.categoryForCast(castContext.castOptions.receiverApplicationId))
                    .build()
                dialog.setRouteSelector(selector)
                dialog.show()
            } catch (e2: Exception) {
                println("MediaRouteChooserDialog methode gefaald: ${e2.message}")
                try {
                    val dialog = MediaRouteChooserDialog(this)
                    val selector = MediaRouteSelector.Builder()
                        .addControlCategory(CastMediaControlIntent.categoryForCast(castContext.castOptions.receiverApplicationId))
                        .build()
                    dialog.setRouteSelector(selector)
                    dialog.show()
                } catch (e3: Exception) {
                    println("Alle methodes gefaald: ${e3.message}")
                }
            }
        }
    }

    private fun castVideo(url: String) {
        val castSession = castContext.sessionManager.currentCastSession ?: return
        val movieMetadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
        movieMetadata.putString(MediaMetadata.KEY_TITLE, "Streamer Video")

        val contentType = if (url.contains(".m3u8")) "application/x-mpegURL" else "video/mp4"

        val mediaInfo = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(contentType)
            .setMetadata(movieMetadata)
            .build()

        val remoteMediaClient: RemoteMediaClient = castSession.remoteMediaClient ?: return
        val loadRequestData = MediaLoadRequestData.Builder().setMediaInfo(mediaInfo).build()
        remoteMediaClient.load(loadRequestData)
    }

    private fun setupSessionManagerListener() {
        sessionManagerListener = object : SessionManagerListener<CastSession> {
            override fun onSessionStarted(session: CastSession, sessionId: String) {
                pendingUrlToCast?.let { url ->
                    castVideo(url)
                    pendingUrlToCast = null
                }
            }

            override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {
                // Handle session resumed
                pendingUrlToCast?.let { url ->
                    castVideo(url)
                    pendingUrlToCast = null
                }
            }

            override fun onSessionStarting(session: CastSession) {}
            override fun onSessionEnding(session: CastSession) {}
            override fun onSessionEnded(session: CastSession, error: Int) {}
            override fun onSessionSuspended(session: CastSession, reason: Int) {}
            override fun onSessionResuming(session: CastSession, sessionId: String) {}
            override fun onSessionResumeFailed(session: CastSession, error: Int) {}
            override fun onSessionStartFailed(session: CastSession, error: Int) {}
        }
    }

    override fun onResume() {
        super.onResume()
        sessionManagerListener?.let {
            castContext.sessionManager.addSessionManagerListener(it, CastSession::class.java)
        }
    }

    override fun onPause() {
        super.onPause()
        sessionManagerListener?.let {
            castContext.sessionManager.removeSessionManagerListener(it, CastSession::class.java)
        }
    }
}