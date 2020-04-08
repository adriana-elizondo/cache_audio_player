package com.ae.audio_player;
import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.exoplayer2.ExoPlayerFactory;
import com.google.android.exoplayer2.LoadControl;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.trackselection.AdaptiveTrackSelection;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.trackselection.TrackSelection;
import com.google.android.exoplayer2.trackselection.TrackSelector;
import com.google.android.exoplayer2.upstream.BandwidthMeter;
import com.google.android.exoplayer2.upstream.DefaultBandwidthMeter;
import static com.google.android.exoplayer2.DefaultLoadControl.*;

import io.flutter.Log;
import io.flutter.plugin.common.MethodChannel.Result;

public class AudioPlayer implements Player.EventListener {
    static int STATE_READYTOPLAY = 0;
    static int STATE_BUFFERING = 1;
    static int STATE_PLAYING = 2;
    static int STATE_PAUSED = 3;
    static int STATE_FAILED = 4;
    static int STATE_FINISHED = 5;

    private SimpleExoPlayer exoPlayer;
    private static AudioPlayer single_instance = null;
    private AudioPlayerListener listener;
    private final Handler bufferHandler = new Handler();
    private final Handler ellapsedTimeHandler = new Handler();

    @Override
    protected void finalize() throws Throwable {
        super.finalize();
        exoPlayer.release();
        ellapsedTimeHandler.removeCallbacks(timeElapsedRunnable);
        bufferHandler.removeCallbacks(bufferRunnable);
        listener = null;
    }

    // static method to create instance of Singleton class
    public static AudioPlayer getInstance()
    {
        if (single_instance == null)
            single_instance = new AudioPlayer();

        return single_instance;
    }

    final Runnable timeElapsedRunnable = new Runnable() {
        @Override
        public void run() {
            listener.onTimeElapsed( exoPlayer.getCurrentPosition() / 1000);
        }
    };

    final Runnable bufferRunnable = new Runnable() {
        @Override
        public void run() {
            if (exoPlayer == null) {return;}
            listener.onBufferUpdated(exoPlayer.getBufferedPercentage());
        }
    };

    public void setUp(String url, Context context) {
        BandwidthMeter bandwidthMeter = new DefaultBandwidthMeter();
        TrackSelection.Factory trackSelectionFactory =
                new AdaptiveTrackSelection.Factory(bandwidthMeter);
        TrackSelector trackSelector = new DefaultTrackSelector(trackSelectionFactory);
        LoadControl loadControl = new Builder().setBufferDurationsMs(
                DEFAULT_MIN_BUFFER_MS,
                300_000,
                DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS).createDefaultLoadControl();
        exoPlayer = ExoPlayerFactory.newSimpleInstance(context, trackSelector, loadControl);
        MediaSource audioSource = new ExtractorMediaSource(Uri.parse(url),
                new CacheDataSourceFactory(context, 100 * 1024 * 1024, 5 * 1024 * 1024),
                new DefaultExtractorsFactory(), null, null);
        exoPlayer.setPlayWhenReady(false);
        exoPlayer.addListener(this);
        exoPlayer.prepare(audioSource);
        if (listener != null)  { listener.onPlayerStateChanged(AudioPlayer.STATE_BUFFERING); }
    }

    public void registerListener(AudioPlayerListener newListener) {
        listener = newListener;
        bufferHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                bufferRunnable.run();
                bufferHandler.postDelayed(this, 1000);
            }
        }, 1000);
    }

    public void unregisterListeners() {
        listener = null;
    }

    public void play() {
        exoPlayer.setPlayWhenReady(true);
        ellapsedTimeHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                timeElapsedRunnable.run();
                ellapsedTimeHandler.postDelayed(this, 500);
            }
        }, 500);
        listener.onPlayerStateChanged(AudioPlayer.STATE_PLAYING);
    }

    public void stop() {
        exoPlayer.setPlayWhenReady(false);
        ellapsedTimeHandler.removeCallbacks(timeElapsedRunnable);
        listener.onPlayerStateChanged(AudioPlayer.STATE_PAUSED);
    }

    public void seek(double time, Result result) {
        double newValue = time * exoPlayer.getDuration();
        boolean shouldPlayAfterSeeking = exoPlayer.isPlaying();
        stop();
        exoPlayer.seekTo((long) newValue);
        result.success(true);
        if (shouldPlayAfterSeeking) {
            play();
        } else {
            listener.onTimeElapsed( exoPlayer.getCurrentPosition() / 1000);
        }
    }

    public void getAudioDuration(Result result) {
        double duration = exoPlayer.getDuration() / 1000;
        result.success(duration);
    }

    @Override
    public void onPlayerStateChanged(boolean playWhenReady, int playbackState) {
        if (listener == null)  { return; }
        switch (playbackState) {
            case Player.STATE_ENDED:
                exoPlayer.setPlayWhenReady(false);
                exoPlayer.seekTo(0);
                listener.onPlayerStateChanged(AudioPlayer.STATE_FINISHED);
            case Player.STATE_READY:
                if (exoPlayer.isPlaying()) { return; }
                listener.onPlayerStateChanged(AudioPlayer.STATE_READYTOPLAY);
                break;
        }
    }

    @Override
    public void onLoadingChanged(boolean isLoading) {
        if (!isLoading) { bufferHandler.removeCallbacks(bufferRunnable);}
    }

    @Override
    public void onPlayerError(ExoPlaybackException error) {
        if (listener == null)  { return; }
        listener.onPlayerStateChanged(AudioPlayer.STATE_FAILED);
        listener.onErroReceived(error.getMessage());
    }
}
