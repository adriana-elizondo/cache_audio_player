import 'package:cache_audio_player/cache_audio_player.dart';
@Timeout(const Duration(seconds: 5))
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MethodChannel channel = MethodChannel('audio_player');
  const MethodChannel eventChannel = MethodChannel('audio_player_streaming');
  CacheAudioPlayer _audioPlayer = CacheAudioPlayer();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'length_in_seconds':
          return 1500.0;
        case 'play':
          return {"state": 2};
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('load_url', () async {
    Map<String, int> buffering = {"state": 1};
    eventChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          "audio_player_streaming",
          const StandardMethodCodec().encodeSuccessEnvelope(buffering),
              (ByteData data) {});
    });

    AudioPlayerState result = AudioPlayerState.BUFFERING;
    print("loading url...");
    _audioPlayer.registerListeners();
    _audioPlayer.loadUrl("");
    _audioPlayer.onStateChanged.listen(
      expectAsync1((event) {
        expect(event, result);
      }),
    );
  });

  test('length_in_seconds', () async {
    Future audioLengthFuture = _audioPlayer.lengthInseconds();
    audioLengthFuture.then((value) {
      expect(value, 1500);
    });
  });

  test('play', () async {
    eventChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      Map<String, int> playing = {"state": 2};
      ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          "audio_player_streaming",
          const StandardMethodCodec().encodeSuccessEnvelope(playing),
              (ByteData data) {});
    });

    AudioPlayerState result = AudioPlayerState.PLAYING;
    print("playing...");
    _audioPlayer.registerListeners();
    _audioPlayer.play();
    _audioPlayer.onStateChanged.listen(
      expectAsync1((event) {
        expect(event, result);
      }),
    );
  });

  test('stop', () async {
    eventChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      Map<String, int> paused = {"state": 3};
      ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          "audio_player_streaming",
          const StandardMethodCodec().encodeSuccessEnvelope(paused),
              (ByteData data) {});
    });

    AudioPlayerState result = AudioPlayerState.PAUSED;
    print("stopping player...");
    _audioPlayer.registerListeners();
    _audioPlayer.play();
    _audioPlayer.onStateChanged.listen(
      expectAsync1((event) {
        expect(event, result);
      }),
    );
  });
}
