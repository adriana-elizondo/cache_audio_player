import 'dart:math';
import 'package:cache_audio_player/cache_audio_player.dart';
import 'package:flutter/material.dart';
import 'dart:async';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final CacheAudioPlayer _audioPlayer = CacheAudioPlayer();
  final String _sampleURL =
      "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";

  StreamSubscription<AudioPlayerState> _stateSubscription;
  StreamSubscription<double> _bufferSubscription;
  StreamSubscription<double> _timeElapsedSubscription;
  StreamSubscription<Object> _errorSubscription;

  AudioPlayerState _state = AudioPlayerState.PAUSED;
  double _bufferedPercentage = 0;
  double _timeInSeconds = 0;
  double _percentageOfTimeElapsed = 0;
  int _totalDuration = 0;
  Object _error;
  bool _isSeekng = false;
  double _valueToSeekTo = 0;

  @override
  void initState() {
    super.initState();

    //Always register listeners in order to receive updates from event channel.
    _audioPlayer.registerListeners();
    _stateSubscription =
        _audioPlayer.onStateChanged.listen((AudioPlayerState state) {
      setState(() {
        _state = state;
      });
    });
    _bufferSubscription =
        _audioPlayer.onPlayerBuffered.listen((double percentageBuffered) {
      setState(() {
        _bufferedPercentage = percentageBuffered;
      });
    });
    _timeElapsedSubscription =
        _audioPlayer.onTimeElapsed.listen((double timeInSeconds) {
      setState(() {
        _timeInSeconds = timeInSeconds;
      });
    });
    _errorSubscription = _audioPlayer.onError.listen((Object error) {
      setState(() {
        _error = error;
      });
    });
    _loadPlayerWithSampleUrl();
  }

  _loadPlayerWithSampleUrl() {
    _audioPlayer.loadUrl(_sampleURL);
  }

  @override
  void dispose() {
    super.dispose();
    _stateSubscription.cancel();
    _bufferSubscription.cancel();
    _errorSubscription.cancel();
    _timeElapsedSubscription.cancel();
    _audioPlayer.unregisterListeners();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == AudioPlayerState.PLAYING || _isSeekng) {
      _updateSliderValue();
    }

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: _playerContainer(),
        ),
      ),
    );
  }

  _playerContainer() {
    return Container(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: _icon(),
                onPressed: () {
                  _onPressed();
                },
              ),
              SizedBox(
                width: 20,
              ),
              Slider(
                onChangeEnd: (double value) {
                  _valueToSeekTo = value;
                  _isSeekng = true;
                  _audioPlayer.seek(value).catchError((Object error) {
                    setState(() {
                      _isSeekng = false;
                      _error = error;
                    });
                  });
                },
                onChanged: (value) {},
                value: _percentageOfTimeElapsed,
              ),
            ],
          ),
          SizedBox(
            height: 20,
          ),
          Row(
            children: <Widget>[
              Text("Time: ${formattedTime()}"),
              SizedBox(width: 20,),
              Text("Buffer: $_bufferedPercentage"),
            ],
          ),
          _error == null ? SizedBox() : Text("there was an error $_error"),
        ],
      ),
    );
  }

  String formattedTime() {
    return Duration(seconds: _timeInSeconds.toInt()).toString();
  }

   _updateSliderValue() {
    if (_totalDuration == 0) {
      _audioPlayer.lengthInseconds().then((totalDuration) {
        _totalDuration = totalDuration.toInt();
      }).catchError((error) {
        _error = error;
      });
    } else {
      if (_isSeekng) {
        _isSeekng = false;
        final double value = _valueToSeekTo;
        _valueToSeekTo = 0;
        _percentageOfTimeElapsed = value;
      } else {
        _percentageOfTimeElapsed = min(_timeInSeconds / _totalDuration, 1.0);
      }
    }
  }

  Icon _icon() {
    switch (_state) {
      case AudioPlayerState.PLAYING:
        return Icon(Icons.pause);
      case AudioPlayerState.READYTOPLAY:
      case AudioPlayerState.BUFFERING:
      case AudioPlayerState.PAUSED:
      case AudioPlayerState.FINISHED:
        return Icon(Icons.play_arrow);
      default:
        return Icon(Icons.error);
    }
  }

  _onPressed() {
    switch (_state) {
      case AudioPlayerState.PLAYING:
        return _audioPlayer.stop();
      case AudioPlayerState.READYTOPLAY:
      case AudioPlayerState.BUFFERING:
      case AudioPlayerState.PAUSED:
        return _audioPlayer.play();
      case AudioPlayerState.FINISHED:
        _percentageOfTimeElapsed = 0;
        _timeInSeconds = 0;
        return _audioPlayer.play();
      default:
        {}
    }
  }
}
