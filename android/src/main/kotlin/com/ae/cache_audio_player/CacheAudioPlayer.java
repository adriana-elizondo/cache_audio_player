package com.ae.cache_audio_player;
import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.util.Log;

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
import io.flutter.plugin.common.MethodChannel.Result;

public class CacheAudioPlayer implements Player.EventListener {
    static int STATE_READYTOPLAY = 0;
    static int STATE_BUFFERING = 1;
    static int STATE_PLAYING = 2;
    static int STATE_PAUSED = 3;
    static int STATE_FAILED = 4;
    static int STATE_FINISHED = 5;

    private SimpleExoPlayer exoPlayer;
    private static CacheAudioPlayer single_instance = null;
    private AudioPlayerListener listener;
    private Handler bufferHandler = new Handler();
    private Handler ellapsedTimeHandler = new Handler();
    private CacheDataSourceFactory cache;

    @Override
    protected void finalize() throws Throwable {
        super.finalize();
        exoPlayer.release();
        ellapsedTimeHandler.removeCallbacks(timeElapsedRunnable);
        bufferHandler.removeCallbacks(bufferRunnable);
        listener = null;
    }

    // static method to create instance of Singleton class
    public static CacheAudioPlayer getInstance()
    {
        if (single_instance == null)
            single_instance = new CacheAudioPlayer();

        return single_instance;
    }

    final Runnable timeElapsedRunnable = new Runnable() {
        @Override
        public void run() {
            if (exoPlayer == null || listener == null) {return;}
            listener.onTimeElapsed( exoPlayer.getCurrentPosition() / 1000);
        }
    };

    final Runnable bufferRunnable = new Runnable() {
        @Override
        public void run() {
            if (exoPlayer == null || listener == null) {return;}
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
        cache = new CacheDataSourceFactory(context);
        MediaSource audioSource = new ExtractorMediaSource(Uri.parse(url),
                cache,
                new DefaultExtractorsFactory(), null, null);
        exoPlayer.setPlayWhenReady(false);
        exoPlayer.addListener(this);
        exoPlayer.prepare(audioSource);
        if (listener != null)  { listener.onPlayerStateChanged(CacheAudioPlayer.STATE_BUFFERING); }
    }

    public void registerListener(AudioPlayerListener newListener) {
        listener = newListener;
        bufferHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (listener == null) {return;}
                bufferRunnable.run();
                bufferHandler.postDelayed(this, 1000);
            }
        }, 1000);
    }

    public void unregisterListeners() {
        resetValues();
    }

    private void resetValues() {
        bufferHandler.removeCallbacks(bufferRunnable);
        ellapsedTimeHandler.removeCallbacks(timeElapsedRunnable);
        bufferHandler = new Handler();
        ellapsedTimeHandler = new Handler();
        listener = null;
        cache.releaseCache();
    }

    public void play() {
        exoPlayer.setPlayWhenReady(true);
        ellapsedTimeHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (listener == null) {return;}
                timeElapsedRunnable.run();
                ellapsedTimeHandler.postDelayed(this, 500);
            }
        }, 500);
        listener.onPlayerStateChanged(CacheAudioPlayer.STATE_PLAYING);
    }

    public void stop() {
        exoPlayer.setPlayWhenReady(false);
        ellapsedTimeHandler.removeCallbacks(timeElapsedRunnable);
        listener.onPlayerStateChanged(CacheAudioPlayer.STATE_PAUSED);
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
                listener.onPlayerStateChanged(CacheAudioPlayer.STATE_FINISHED);
            case Player.STATE_READY:
                if (exoPlayer.isPlaying()) { return; }
                listener.onPlayerStateChanged(CacheAudioPlayer.STATE_READYTOPLAY);
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
        listener.onPlayerStateChanged(CacheAudioPlayer.STATE_FAILED);
        listener.onErroReceived(error.getMessage());
    }
}
