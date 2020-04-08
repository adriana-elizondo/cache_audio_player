import Flutter
import UIKit

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


public class SwiftCacheAudioPlayerPlugin: NSObject, FlutterPlugin {
    private var audioPlayer = AudioPlayer.sharedInstance
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "audio_player",
                                           binaryMessenger: registrar.messenger())
        let instance = SwiftCacheAudioPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        //Streaming
        let streamingChannel = FlutterEventChannel(name: "audio_player_streaming", binaryMessenger: registrar.messenger())
        streamingChannel.setStreamHandler(MediaDownloadStreamHandler())
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "load_from_url":
            if let url = call.arguments as? String {
                loadFromUrl(urlString: url, result: result)
            }
        case "length_in_seconds":
            audioPlayer.currentItemLengthInSeconds(result: result)
        case "play":
            audioPlayer.play()
        case "stop":
            audioPlayer.stop()
        case "seek":
            if let sliderValue = call.arguments as? Double {
                audioPlayer.sliderValue(value: sliderValue, result: result)
            }
        case "unregister_listeners":
            audioPlayer.unregisterListeners()
        default:
            print("\(call.method) is not supported.")
        }
    }
    
    private func loadFromUrl(urlString: String, result: @escaping FlutterResult) {
        guard let url = URL(string: urlString) else {
            result(FlutterError(code: "", message: "Malformed url", details: nil))
            return
        }
        AudioPlayer.sharedInstance.setup(with: url, result: result)
    }
}
