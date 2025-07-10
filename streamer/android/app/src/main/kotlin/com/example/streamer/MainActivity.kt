// MainActivity.kt

package com.example.streamer

import android.view.ViewGroup
import androidx.appcompat.view.ContextThemeWrapper
import androidx.mediarouter.app.MediaRouteButton
import androidx.mediarouter.app.MediaRouteChooserDialog
import androidx.mediarouter.media.MediaRouteSelector
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.MediaTrack
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity: FlutterFragmentActivity() {
    private companion object {
        const val CHANNEL_NAME = "com.example.streamer/cast"
    }

    private val castContext: CastContext by lazy {
        CastContext.getSharedInstance(applicationContext)
    }

    private val remoteMediaClient: RemoteMediaClient?
        get() = castContext.sessionManager.currentCastSession?.remoteMediaClient

    private var sessionManagerListener: SessionManagerListener<CastSession>? = null
    private var pendingMedia: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        setupSessionManagerListener()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSmartCasting" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title") ?: "Streamer Video"
                    val subtitles = call.argument<List<Map<String, String>>>("subtitles") ?: emptyList()
                    if (url != null) {
                        startSmartCasting(url, title, subtitles)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "URL kan niet null zijn", null)
                    }
                }
                "setActiveSubtitle" -> {
                    val trackId = call.argument<Int>("trackId")
                    if (trackId != null) {
                        if (trackId == 0) {
                            remoteMediaClient?.setActiveMediaTracks(longArrayOf())
                        } else {
                            remoteMediaClient?.setActiveMediaTracks(longArrayOf(trackId.toLong()))
                        }
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Track ID kan niet null zijn", null)
                    }
                }
                "play" -> {
                    remoteMediaClient?.play()
                    result.success(null)
                }
                "pause" -> {
                    remoteMediaClient?.pause()
                    result.success(null)
                }
                "stop" -> {
                    remoteMediaClient?.stop()
                    result.success(null)
                }
                "disconnect" -> {
                    castContext.sessionManager.endCurrentSession(true)
                    result.success(null)
                }
                "seekTo" -> {
                    val position = call.argument<Double>("position")
                    if (position != null) {
                        remoteMediaClient?.seek((position * 1000).toLong())
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Positie kan niet null zijn", null)
                    }
                }
                "skipForward" -> {
                    val seconds = call.argument<Int>("seconds") ?: 10
                    val currentPosition = remoteMediaClient?.approximateStreamPosition ?: 0
                    remoteMediaClient?.seek(currentPosition + (seconds * 1000))
                    result.success(null)
                }
                "skipBackward" -> {
                    val seconds = call.argument<Int>("seconds") ?: 10
                    val currentPosition = remoteMediaClient?.approximateStreamPosition ?: 0
                    remoteMediaClient?.seek(currentPosition - (seconds * 1000))
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = call.argument<Double>("volume")
                    if (volume != null) {
                        remoteMediaClient?.setStreamVolume(volume)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Volume kan niet null zijn", null)
                    }
                }
                "getStatus" -> {
                    val client = remoteMediaClient
                    val session = castContext.sessionManager.currentCastSession
                    if (client == null || session == null || !session.isConnected) {
                        result.success(mapOf("isConnected" to false))
                    } else {
                        val mediaStatus = client.mediaStatus
                        val statusMap = mapOf(
                            "isConnected" to true,
                            "isPlaying" to (mediaStatus?.playerState == MediaStatus.PLAYER_STATE_PLAYING),
                            "currentPosition" to (client.approximateStreamPosition / 1000.0),
                            "duration" to (mediaStatus?.mediaInfo?.streamDuration?.div(1000.0) ?: 0.0),
                            "volume" to (mediaStatus?.streamVolume ?: 1.0)
                        )
                        result.success(statusMap)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startSmartCasting(url: String, title: String, subtitles: List<Map<String, String>>) {
        val castSession = castContext.sessionManager.currentCastSession
        if (castSession != null && castSession.isConnected) {
            castVideo(url, title, subtitles)
        } else {
            pendingMedia = mapOf("url" to url, "title" to title, "subtitles" to subtitles)
            showCastDialog()
        }
    }

    private fun showCastDialog() {
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
            try {
                val themedContext = ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Light_Dialog)
                val dialog = MediaRouteChooserDialog(themedContext)
                val selector = MediaRouteSelector.Builder()
                    .addControlCategory(CastMediaControlIntent.categoryForCast(castContext.castOptions.receiverApplicationId))
                    .build()
                dialog.setRouteSelector(selector)
                dialog.show()
            } catch (e2: Exception) {
                try {
                    val dialog = MediaRouteChooserDialog(this)
                    val selector = MediaRouteSelector.Builder()
                        .addControlCategory(CastMediaControlIntent.categoryForCast(castContext.castOptions.receiverApplicationId))
                        .build()
                    dialog.setRouteSelector(selector)
                    dialog.show()
                } catch (e3: Exception) {
                }
            }
        }
    }

    private fun castVideo(url: String, title: String, subtitles: List<Map<String, String>>) {
        val castSession = castContext.sessionManager.currentCastSession ?: return
        val movieMetadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
        movieMetadata.putString(MediaMetadata.KEY_TITLE, title)

        val mediaTracks = mutableListOf<MediaTrack>()
        subtitles.forEachIndexed { index, sub ->
            val trackId = (index + 1).toLong() 
            val subUrl = sub["url"]
            val subLang = sub["lang"]
            val subName = sub["name"]

            if (subUrl != null && subLang != null && subName != null) {
                val subtitleTrack = MediaTrack.Builder(trackId, MediaTrack.TYPE_TEXT)
                    .setName(subName)
                    .setSubtype(MediaTrack.SUBTYPE_SUBTITLES)
                    .setContentId(subUrl)
                    .setContentType("text/vtt")
                    .setLanguage(subLang)
                    .build()
                mediaTracks.add(subtitleTrack)
            }
        }

        val contentType = if (url.contains(".m3u8")) "application/x-mpegURL" else "video/mp4"

        val mediaInfo = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(contentType)
            .setMetadata(movieMetadata)
            .setMediaTracks(mediaTracks)
            .build()

        val remoteMediaClient: RemoteMediaClient = castSession.remoteMediaClient ?: return
        val loadRequestData = MediaLoadRequestData.Builder().setMediaInfo(mediaInfo).build()
        remoteMediaClient.load(loadRequestData)
    }

    private fun setupSessionManagerListener() {
        sessionManagerListener = object : SessionManagerListener<CastSession> {
            override fun onSessionStarted(session: CastSession, sessionId: String) {
                pendingMedia?.let { media ->
                    val url = media["url"] as String
                    val title = media["title"] as String
                    val subtitles = media["subtitles"] as List<Map<String, String>>
                    castVideo(url, title, subtitles)
                    pendingMedia = null
                }
            }

            override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {
                pendingMedia?.let { media ->
                    val url = media["url"] as String
                    val title = media["title"] as String
                    val subtitles = media["subtitles"] as List<Map<String, String>>
                    castVideo(url, title, subtitles)
                    pendingMedia = null
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