package com.ae.cache_audio_player;
import java.util.HashMap;
import java.util.Map;
import io.flutter.plugin.common.EventChannel;

/// FlutterStreamHandler responsible for listening to events in the 'audio_player_streaming' event channel,
/// Implements AudioPlayerListener to receive updates from AudioPlayer class.
/// When a listener is setup on Flutter, this class will forward the events triggered from AudioPlayerListener into the FlutterEventSink.
///
/// The events forwarded have the following format:
/// **Supported events**
/// All the events are forwarded in a dictionary of [eventName: String: T: Event value]
/// - *bufferWasUpdated*
///     event name: 'buffer'
///     value type : Double - percentage up to which the media file has been downloaded so far.
/// - *stateWasUpdated*
///     event name: 'state'
///     value type : int (raw value of AudioPlayerState ) - state to which the audio player has moved.
/// - *timeElapsed*
///     event name: 'time_elapsed'
///     value type : Double - while audio player is playing, current time in seconds.

public class MediaDownloadStreamHandler implements EventChannel.StreamHandler, AudioPlayerListener {
    private CacheAudioPlayer audioPlayer;
    private EventChannel.EventSink eventSink;

    MediaDownloadStreamHandler(CacheAudioPlayer player){
        this.audioPlayer = player;
        audioPlayer.registerListener(this);
        registerIfActive();
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        this.eventSink = events;
        registerIfActive();
    }

    @Override
    public void onCancel(Object arguments) {
        unregisterIfActive();
    }

    private void registerIfActive() {
        if (eventSink == null) return;
        audioPlayer.registerListener(this);
    }
    private void unregisterIfActive() {
        if (eventSink == null) return;
    }

    @Override
    public void onPlayerStateChanged(int playbackState) {
        if (eventSink == null) return;
        Map<String, Integer> eventData = new HashMap<>();
        eventData.put("state", playbackState);
        eventSink.success(eventData);
    }

    @Override
    public void onTimeElapsed(double timeInSeconds) {
        if (eventSink == null) return;
        Map<String, Double> eventData = new HashMap<>();
        eventData.put("time_elapsed", timeInSeconds);
        eventSink.success(eventData);
    }

    @Override
    public void onBufferUpdated(double bufferPercentage) {
        if (eventSink == null) return;
        Map<String, Double> eventData = new HashMap<>();
        eventData.put("buffer", bufferPercentage);
        eventSink.success(eventData);
    }

    @Override
    public void onErroReceived(String errorMessage) {
        if (eventSink == null) return;
        eventSink.error("", errorMessage, null);
    }
}
