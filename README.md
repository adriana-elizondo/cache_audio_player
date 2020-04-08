# cache_audio_player

A flutter plugin to play and **cache** audio files. Works for iOS and Android.
The plugin uses 2 channels, one to communicate events from flutter to native, and an event channel to stream the state changes of the native players back to flutter.

# Usage
Import package:cache_audio_player/cache_audio_player.dart and instantiate CacheAudioPlayer;

Example:
```dart in html

final CacheAudioPlayer audioPlayer = CacheAudioPlayer();

//Always register listeners in order to receive updates from event channel.
audioPlayer.registerListeners();

//Event channel callbacks:
audioPlayer.onStateChanged.listen((AudioPlayerState state) {
  setState(() {
      //or do whatever you need to do with the new state
     _state = state;
  });
});

audioPlayer.onPlayerBuffered.listen((double percentageBuffered) {
  setState(() {
     _bufferedPercentage = percentageBuffered;
  });
});

audioPlayer.onTimeElapsed.listen((double timeInSeconds) {
  setState(() {
      _timeInSeconds = timeInSeconds;
   });
  });

audioPlayer.onError.listen((Object error) {
   setState(() {
      _error = error;
  });
});

audioPlayer.loadUrl("your url");
audioPlayer.play();

```
## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/developing-packages/),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter, view our 
[online documentation](https://flutter.dev/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.
