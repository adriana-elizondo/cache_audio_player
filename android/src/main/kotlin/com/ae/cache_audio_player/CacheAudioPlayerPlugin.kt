package com.ae.cache_audio_player
import android.content.Context
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

/** AudioPlayerPlugin */
/// A 2-way communication channel with Flutter responsible for:
/// - loading a media file (only audio for now) from a URL to an AVPlayer and keeping the file's data in a cache.
/// - get the length in seconds of the media file loaded
/// - play
/// - stop playing
/// - retry playing the file if there was an error
/// - seek to a time in the file (in seconds)
/// - unregister listeners to the media stream handler. See MediaDownloadStreamHandler for more details on this class.
///
/// **Channel Name**
/// audio_player
/// audio_player_streaming
///
/// **Supported method invocations**
/// - *load_from_url*
///     Parameter: String url
///     Output: true if buffering started successfully or a FlutterError
/// - *length_in_seconds*
///     Output: Double - length in seconds of current loaded media file in player item
/// - *play*
///     Plays the loaded audio file, any player item updates will be transmitted through the streamingChannel
/// - *stop*
///     Stops playing, any player item updates will be transmitted through the streamingChannel
/// - *retry*
///
/// - *seek*
///    Parameter: Double: slider value to seek to, or percentage of the file to advance to. (i.e. If the value is 0.5 it will seek to the middle of the file)
/// - *unregister_listeners*
///    Removes listeners in the streaming channel.

public class CacheAudioPlayerPlugin: FlutterPlugin, MethodCallHandler {
  private val audioPlayer = CacheAudioPlayer.getInstance()
  private var context: Context? = null
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val channel = MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "audio_player")
    val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "audio_player_streaming")
    eventChannel.setStreamHandler(MediaDownloadStreamHandler(CacheAudioPlayer.getInstance()))

    val plugin = CacheAudioPlayerPlugin()
    plugin.context = flutterPluginBinding.applicationContext
    channel.setMethodCallHandler(plugin);
  }

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "audio_player")
      channel.setMethodCallHandler(CacheAudioPlayerPlugin())

      val eventChannel = EventChannel(registrar.messenger(), "audio_player_streaming")
      eventChannel.setStreamHandler(MediaDownloadStreamHandler(CacheAudioPlayer.getInstance()))
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when(call.method) {
      "load_from_url" -> audioPlayer.setUp(call.arguments as String, this.context);
      "play" -> audioPlayer.play()
      "stop" -> audioPlayer.stop()
      "unregister_listeners" -> audioPlayer.unregisterListeners()
      "seek" -> audioPlayer.seek(call.arguments as Double, result)
      "length_in_seconds" -> audioPlayer.getAudioDuration(result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
  }
}
