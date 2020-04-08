package com.ae.audio_player;

public interface AudioPlayerListener {
    void onErroReceived(String errorMessage);
    void onPlayerStateChanged(int playbackState);
    void onTimeElapsed(double timeInSeconds);
    void onBufferUpdated(double bufferPercentage);
}
