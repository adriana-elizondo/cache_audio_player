import 'dart:async';
import 'package:flutter/services.dart';

/// Enum representing the multiple states the Audio player can have.
enum AudioPlayerState {
  // [iOS] - State returned by AVPlayer, or set when buffering is finshed and audio is not being played.
  // [Android] - State returned by ExoPlayer
  // Value 0
  READYTOPLAY,
  // [iOS] - Set when the audio is being loaded successfully from URL, until loading completes.
  // [Android] - State returned by ExoPlayer.
  // Value 1
  BUFFERING,
  // [BOTH] - Set when player is playing audio file
  // Value 2
  PLAYING,
  // [BOTH] - Set when player is paused
  // Value 3
  PAUSED,
  // [BOTH] - Set if there is any error returned by player.
  // Value 4
  FAILED,
  // [BOTH] - Set when the player reaches the end of current media file.
  // Value 5
  FINISHED
}

///Main class of the plugin. Its functions are the following:
///Register listeners to the event channel where the player state, current time ellapsed, and buffer percentage, will be transmitted.
///Receive events from the client via the 'audio_player' MethodChannel and call the audio player methods accordingly.
class CacheAudioPlayer {
  ///Channel used to invoke AvPlayer methods on iOS and Exoplayer methods in Android
  ///Handles: play, stop, seek, load_from_url, length_in_seconds, unregister_listeners
  static const MethodChannel _channel = const MethodChannel('audio_player');

  ///Channel used to stream the state updates from native players.
  ///Handles: state, buffer, time, errors
  static const EventChannel _eventChannel =
      EventChannel('audio_player_streaming');

  ///Receives the percentage buffered in player.
  final StreamController<double> _bufferedMediaController =
      StreamController<double>.broadcast();

  ///Receives time elapsed (if player is playing) in seconds.
  final StreamController<double> _timeElapsedController =
      StreamController<double>.broadcast();

  ///Receives any error returned from native, player errors or network request errors.
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();

  ///Receives the player updated states: in AudioPlayerState.
  final StreamController<AudioPlayerState> _playerStateController =
      StreamController<AudioPlayerState>.broadcast();

  ///Stream that transmits the buffered percentage in a 'double' value that goes from 1 - 100.
  Stream<double> get onPlayerBuffered => _bufferedMediaController.stream;

  ///Stream that transmits the time ellapsed in a 'double' value that goes from 0 - audio duration.
  ///This stream will only transmit events if the audio player has a state of 'AudioPlayerState.PLAYING'
  Stream<double> get onTimeElapsed => _timeElapsedController.stream;

  ///Stream that transmits a change in the state of the audio player in a 'AudioPlayerState'.
  Stream<AudioPlayerState> get onStateChanged => _playerStateController.stream;

  ///Stream that transmits any error received while trying to load the audio into the player, or while playing the loaded audio.
  Stream<Object> get onError => _errorController.stream;

  ///Registers to receive updates from event channel. **If this method isn't called, no updates will be triggered**.
  void registerListeners() {
    _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      Map<String, dynamic> result = Map<String, dynamic>.from(event);
      if (result["buffer"] != null) {
        _bufferedMediaController.add(result["buffer"]);
      }

      if (result["state"] != null) {
        int index = result["state"];
        _playerStateController.add(AudioPlayerState.values[index]);
      }

      if (result["time_elapsed"] != null) {
        double time = result["time_elapsed"];
        _timeElapsedController.add(time);
      }
    }, onError: (dynamic error) {
      _errorController.add(error);
    });
  }

  ///Loads a file in the audio player from a url.
  ///The file will be loaded from the cache if any exists, otherwise it will load it from the network.
  ///The cache entries are generated with the absolute string of the url sent in this method.
  void loadUrl(String url) {
    _channel.invokeMethod('load_from_url', url);
  }

  ///Starts playing
  void play() {
    _channel.invokeMethod('play');
  }

  //Returns the total duration of the current file loaded in the player.
  Future<double> lengthInseconds() async {
    return await _channel.invokeMethod('length_in_seconds');
  }

  ///Pauses the audio player
  void stop() {
    _channel.invokeMethod('stop');
  }

  ///Seeks the player to the received value
  ///This value should go from 0 - 1, representing the percentage of the total duration you want to scroll to. (This is to make it easier to seek with a slider).
  ///For example: If the value sent is 0.5 the player will seek to the middle of the audio file.
  ///The seek function may fail in iOS if the data xwhasn't buffered completely, it will return true if successful.
  Future<bool> seek(double value) async {
    return await _channel.invokeMethod('seek', value);
  }

  ///The FlutterEventChannel 'audio_player_streaming' is registered as a listener to the AudioPlayer class in order to get the player event updates and send them to flutter via events.
  ///This method removes that listener.
  void unregisterListeners() {
    _channel.invokeMethod('unregister_listeners');
  }
}
