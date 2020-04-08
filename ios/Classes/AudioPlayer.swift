//
//  AudioPlayer.swift
//  AudioPlayerSample
//
//  Created by Adriana Elizondo on 2020/3/27.
//  Copyright © 2020 Adriana Elizondo. All rights reserved.
//

import Foundation
import AVFoundation

extension AVPlayer {
    var isPlaying: Bool {
        return self.rate != 0 && self.error == nil
    }
}

enum AudioPlayerState: Int {
    case readyToPlay, buffering, playing, paused, failed, finished
}

extension URL {
    func urlWithDefaultExtension() -> URL {
        var currentUrl = self
        if currentUrl.pathExtension.isEmpty {
            currentUrl.deletePathExtension()
            currentUrl.appendPathExtension("mp3")
        }
        return currentUrl
    }
    
    func urlWithCustomScheme(customScheme: String) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = customScheme
        return components?.url
    }
}

private class Cache {
    private class Key: NSObject {
        private let key: String
        
        init(with key: String) {
            self.key = key
        }
        
        static func == (lhs: Cache.Key, rhs: Cache.Key) -> Bool {
            return lhs.key == rhs.key
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? Key else {
                return false
            }
            return value.key == self.key
        }
    }
    
    private class DownloadData {
        let data: Data
        init(with data: Data) {
            self.data = data
        }
    }
    
    private let nscache = NSCache<Key, DownloadData>()
    
    func insert(_ data: Data?, forKey key: String) {
        let downloadData = DownloadData(with: data!)
        nscache.setObject(downloadData, forKey: Key(with: key))
    }
    
    func value(forKey key: String) -> Data? {
        let downloadData = nscache.object(forKey: Key(with: key))
        return downloadData?.data
    }
    
    func removeValue(forKey key: String) {
        nscache.removeObject(forKey: Key(with: key))
    }
}

protocol AudioPlayerListener: class {
    func bufferWasUpdated(newValue: Double)
    func stateWasUpdated(newState: AudioPlayerState)
    func timeElapsed(newTimeInSeconds: Double)
    func errorReceived(error: NSError)
}

class AudioPlayer: NSObject {
    static let sharedInstance = AudioPlayer()
    private var url: URL?
    private var session: URLSession?
    private var playerItem: AVPlayerItem?
    private var player: AVPlayer?
    private let scheme = "audioplayerscheme"
    private var downloadedData = Data()
    private var loadingRequests = [String: AVAssetResourceLoadingRequest]()
    private let cache = Cache()
    private var loadFromCache = false
    private weak var listener: AudioPlayerListener?
    private var timeObserverToken: Any?
    private var wasAllDataLoaded = false
    
    deinit {
        session?.invalidateAndCancel()
        NotificationCenter.default.removeObserver(self)
        removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
    }
    
    override init() {
        print("initializing audio player...")
        super.init()
    }
    
    func setup(with url: URL, result: @escaping FlutterResult) {
        self.url = url
        
        guard let customSchemeUrl = url.urlWithCustomScheme(customScheme: scheme) else {
            result(FlutterError(code: "", message: "Malformed url", details: nil))
            listener?.stateWasUpdated(newState: .failed)
            return
        }
        
        // Always use mp3 extension to load files if url has none
        let urlWithCustomSchemeAndDefaultExtension = customSchemeUrl.urlWithDefaultExtension()
        
        let asset = AVURLAsset(url: urlWithCustomSchemeAndDefaultExtension)
        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: nil)
        
        // Register as an observer of the player item's status property
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: nil)
        player = AVPlayer(playerItem: playerItem)
        addPeriodicTimeObserver()
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlay), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerEndedPlayingFile), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        result(true)
        listener?.stateWasUpdated(newState: .buffering)
    }
    
    @objc private func playerItemFailedToPlay() {
        listener?.errorReceived(error: NSError(domain: "Error.AVPlayerItemFailedToPlayToEndTime", code: 0, userInfo: nil))
    }
    
    @objc private func playerEndedPlayingFile() {
        player?.seek(to: CMTime.zero)
        listener?.stateWasUpdated(newState: .finished)
    }
    
    private func addPeriodicTimeObserver() {
        // Notify every half second
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.5, preferredTimescale: timeScale)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            self?.listener?.timeElapsed(newTimeInSeconds: Double(CMTimeGetSeconds(time)))
        }
    }
    
    private func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    public func registerListener(listener: AudioPlayerListener) {
        self.listener = listener
    }
    
    func unregisterListeners() {
        self.listener = nil
    }
    
    func play() {
        if #available(iOS 10.0, *) {
            player?.automaticallyWaitsToMinimizeStalling = false
        } else {
            // Fallback on earlier versions
        }
        player?.play()
        listener?.stateWasUpdated(newState: .playing)
    }
    
    func stop() {
        player?.pause()
        listener?.stateWasUpdated(newState: .paused)
        session?.finishTasksAndInvalidate()
        session = nil
    }
    
    func currentItemLengthInSeconds(result: @escaping FlutterResult) {
        guard let duration = playerItem?.duration, duration.value > 0 else {
            result(NSNumber(value: 0))
            return
        }
        result(NSNumber(value: Double(CMTimeGetSeconds(duration))))
    }
    
    func sliderValue(value: Double, result: @escaping FlutterResult) {
        guard let playerItem = playerItem, wasAllDataLoaded else {
            result(FlutterError(code: "", message: "Can only seek after buffering is finished", details: nil))
            return
        }
        
        let newTime = value * 1000 * CMTimeGetSeconds(playerItem.duration)
        let shouldPlayAfterSeek = player?.isPlaying
        stop()
        player?.seek(to: CMTime(value: CMTimeValue(newTime), timescale: 1000))
        result(true)
        if shouldPlayAfterSeek ?? false {
            play()
        } else {
            listener?.timeElapsed(newTimeInSeconds: value)
        }
    }
    
    // MARK: Load remote file
    private func loadMedia() {
        guard let url = url else { return }
        wasAllDataLoaded = false
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        session?.dataTask(with: url).resume()
    }
    
    // MARK: AudioPlayerState
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over status value
            switch status {
            case .readyToPlay:
                listener?.stateWasUpdated(newState: .readyToPlay)
            case .failed:
                listener?.errorReceived(error: NSError(domain: "Error.AvPlayerStateFailed", code: 0, userInfo: nil))
                listener?.stateWasUpdated(newState: .failed)
            default: break
            }
        }
    }
    
    // MARK: Process AVAssetResourceLoadingRequest
    private func processLoadingRequests(with data: Data?) {
        loadingRequests = loadingRequests.filter {
            let finished = didFinishProcessingData(dataRequest: $0.value.dataRequest!, data: data!)
            if finished { $0.value.finishLoading() }
            return !finished
        }
    }
    
    private func didFinishProcessingData(dataRequest : AVAssetResourceLoadingDataRequest, data: Data) -> Bool {
        let requestedOffset = Int(dataRequest.requestedOffset)
        let requestedLength = dataRequest.requestedLength
        let currentOffset = Int(dataRequest.currentOffset)
        
        guard data.count > currentOffset else { return false }
        
        let bytesToRespond = min(data.count - currentOffset, requestedLength)
        let dataToRespond = data.subdata(in: Range(uncheckedBounds: (currentOffset, currentOffset + bytesToRespond)))
        dataRequest.respond(with: dataToRespond)
        
        return data.count >= requestedLength + requestedOffset
    }
    
    private func processLoadingRequests(with response: URLResponse) {
        for request in loadingRequests.values {
            request.contentInformationRequest?.contentType = response.mimeType
            request.contentInformationRequest?.contentLength = response.expectedContentLength
            request.contentInformationRequest?.isByteRangeAccessSupported = true
        }
    }
    
    private func processLoadingRequestsFromCache(with data: Data) {
        for request in loadingRequests.values {
            request.contentInformationRequest?.contentType = "audio/mpeg"
            request.contentInformationRequest?.contentLength =  Int64(downloadedData.count)
            request.contentInformationRequest?.isByteRangeAccessSupported = true
        }
        
        processLoadingRequests(with: downloadedData)
    }
}

extension AudioPlayer: AVAssetResourceLoaderDelegate, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate
{
    /// - MARK: AVAssetResourceLoaderDelegate
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        let key = loadingRequest.request.url?.absoluteString
        loadingRequests[key!] = loadingRequest
        
        //Load data from cache if any first
        if let data = cache.value(forKey: url!.absoluteString) {
            downloadedData = data
            loadFromCache = true
            processLoadingRequestsFromCache(with: data)
        } else if session == nil {
            loadMedia()
        }
        
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let key = loadingRequest.request.url?.absoluteString
        loadingRequests[key!] = nil
    }
    
    /// - MARK: URLSession
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        downloadedData.append(data)
        processLoadingRequests(with: downloadedData)
        let percentageBufferered = Double(downloadedData.count) /  Double(dataTask.countOfBytesExpectedToReceive)
        listener?.bufferWasUpdated(newValue: percentageBufferered * 100)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(Foundation.URLSession.ResponseDisposition.allow)
        guard !loadFromCache else { processLoadingRequestsFromCache(with: downloadedData); return }
        downloadedData = Data()
        processLoadingRequests(with: response)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error == nil else {
            listener?.errorReceived(error: NSError(domain: "Error.UrlSessionCompletedWithError", code: 0, userInfo: nil))
            return
        }
        wasAllDataLoaded = true
        cache.insert(downloadedData, forKey: url!.absoluteString)
        //Remove finished requests if theres still some
        processLoadingRequests(with: downloadedData)
        if !(player?.isPlaying ?? false) {
            listener?.stateWasUpdated(newState: .readyToPlay)
        }
    }
}
