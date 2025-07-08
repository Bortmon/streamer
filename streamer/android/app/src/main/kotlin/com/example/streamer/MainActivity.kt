package com.example.streamer

import android.content.Context
import androidx.mediarouter.app.MediaRouteButton

import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MainActivity: FlutterActivity() {
    private companion object {
        const val CHANNEL_NAME = "com.example.streamer/cast"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("cast_button", CastButtonFactory())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).setMethodCallHandler {
                call, result ->
            if (call.method == "castVideo") {
                val url = call.argument<String>("url")
                if (url != null) {
                    castVideo(url)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "URL cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun castVideo(url: String) {
        val castContext = CastContext.getSharedInstance(this)
        val castSession = castContext.sessionManager.currentCastSession

        if (castSession == null || !castSession.isConnected) {
            println("Kan niet casten: geen actieve of verbonden Cast-sessie.")
            return
        }

        val movieMetadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
        movieMetadata.putString(MediaMetadata.KEY_TITLE, "Streamer Video")

        val mediaInfo = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType("application/x-mpegURL")
            .setMetadata(movieMetadata)
            .build()

        val remoteMediaClient: RemoteMediaClient? = castSession.remoteMediaClient
        if (remoteMediaClient == null) {
            println("Kan niet casten: RemoteMediaClient is niet beschikbaar.")
            return
        }

        remoteMediaClient.load(mediaInfo)
        println("Video wordt geladen op Chromecast: $url")
    }
}

class CastButtonFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return CastButtonPlatformView(context)
    }
}


class CastButtonPlatformView(context: Context) : PlatformView {
    private val mediaRouteButton = MediaRouteButton(context)

    override fun getView(): MediaRouteButton {
        return mediaRouteButton
    }

    override fun dispose() {}
}