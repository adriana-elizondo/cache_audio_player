//
//  MediaDownloadStreamHandler.swift
//  audio_player
//
//  Created by Adriana Elizondo on 2020/3/28.
//

import Foundation
import Flutter

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


class MediaDownloadStreamHandler: NSObject, FlutterStreamHandler, AudioPlayerListener {
    private var sink: FlutterEventSink?
    private var audioPlayer = AudioPlayer.sharedInstance
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("started listening...")
        sink = events
        print("registering event listeners..")
        audioPlayer.registerListener(listener: self)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        removeEventSink()
        return nil
    }
    
    private func removeEventSink() {
        guard sink != nil else { return }
        audioPlayer.stop()
    }
    
    // MARK: - Audio Player listener
    func bufferWasUpdated(newValue: Double) {
        guard let sink = sink else { return }
        sink(["buffer" : newValue])
    }
    
    func stateWasUpdated(newState: AudioPlayerState) {
        guard let sink = sink else { return }
        sink(["state": newState.rawValue])
    }
    
    func timeElapsed(newTimeInSeconds: Double) {
        guard let sink = sink else { return }
        sink(["time_elapsed": newTimeInSeconds])
    }
    
    func errorReceived(error: NSError) {
        guard let sink = sink else { return }
        sink(FlutterError(code: "\(error.code)", message: error.domain, details: nil))
    }
}
