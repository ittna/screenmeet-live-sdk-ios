//
//  SMSession.swift
//  ScreenMeet
//
//  Created by Ross on 11.01.2021.
//

import UIKit
import WebRTC

/// ScreenMeet initial connection callback
public typealias SMConnectCompletion = (_ error: SMError?) -> Void

/// Protocol to handle session events
public protocol ScreenMeetDelegate: class {
    
    /// on Audio stream created
    func onLocalAudioCreated()
    
    /// on Local Video stream created
    /// - Parameter videoTrack: Can be used to preview local video. See `RTCVideoTrack`
    func onLocalVideoCreated(_ videoTrack: RTCVideoTrack)
    
    /// Called when videosource for local video has changed (fro example from back camera to front camera, or fomr any camera to screen)
    func onLocalVideoSourceChanged()
    
    /// on Local Video stream stoped
    func onLocalVideoStopped()
    
    /// on Local Audio stream stoped
    func onLocalAudioStopped()
    
    // Participants
    
    /// On participant joins call.
    /// - Parameter participant: Participant details. See `SMParticipant`
    func onParticipantJoined(_ participant: SMParticipant)
    
    /// On receiving video stream from participant.
    /// - Parameter participant: Participant details. See `SMParticipant`
    func onParticipantVideoTrackCreated(_ participant: SMParticipant)
    
    /// On receiving audio stream from participant.
    /// - Parameter participant: Participant details. See `SMParticipant`
    func onParticipantAudioTrackCreated(_ participant: SMParticipant)
    
    /// On participant left call.
    /// - Parameter participant: Participant details. See `SMParticipant`
    func onParticipantLeft(_ participant: SMParticipant)
    
    /// When participant state was changed. For example participant muted, paused, resumed video, etc
    /// - Parameter participant: Participant details. See `SMParticipant`
    func onParticipantMediaStateChanged(_ participant: SMParticipant)
    
    /// When active speaker changed. 
    /// - Parameter participant: Participant details. See `SMParticipant`
    func onActiveSpeakerChanged(_ participant: SMParticipant)
    
    /// On connection state change
    /// - Parameter new session state: `SMState`
    func onConnectionStateChanged(_ newState: SMConnectionState)
}

class SMSession: NSObject {
    weak var delegate: ScreenMeetDelegate?
    
    private var connectCompletion: SMConnectCompletion? = nil
    private var session: Session!
    
    /// Connect to the room
    /// - Parameter code: The string code of the room
    /// - Parameter config: Initial session configuration. See `SMSessionConfig`
    func connect(_ code: String,
                 _ completion: @escaping SMConnectCompletion) {
        
            self.connectCompletion = completion
        
            SMHandshakeTransaction()
            .withCode(code)
            .withReconnectHandler({ [weak self] in self?.reconnect() })
            .withChannelMessageHandler { [weak self] channelMessage in
                self?.processIncomingChannelMessage(channelMessage)
            }.run { [weak self] session, error in
                if let error = error {
                    self?.connectCompletion?(SMError(code: .httpError, message: "Could not connect to server. " + error.message))
                }
                else {
                    self?.session = session
                    self?.startWebRTC(session!.turn)
                }
        }
    }
    
    /// Disconnect, cancel all tracks, cleanup data
    func disconnect() {
        SMDisconnectTransaction().run()
    }
    
    func toggleLocalVideo() {
        let channel = SMChannelsManager.shared.channel(for: .mediasoup) as! SMMediasoupChannel
        
        var state = channel.getVideoEnabled()
        state = !state
        channel.setVideoState(state)
        
        SMVideoStateTransaction().run(state) { [weak self] error in
            if let error = error {
                NSLog("Could not toggle local video: ", error.message)
                //Could not toggle state of local video, hit some onError in delegate
            }
            else {
                DispatchQueue.main.async {
                    if !state {
                        self?.delegate?.onLocalVideoStopped()
                    }
                    // state resumed will be delivered via onLocalVideoCreated later
                }
            }
        }
    }
    
    private func setVideoSourceDevice(videoDevice: AVCaptureDevice!) {
        if let msChannel = SMChannelsManager.shared.channel(for: .mediasoup) as? SMMediasoupChannel {
            msChannel.videoSourceDevice = videoDevice
        }
    }
    
    func getVideoEnabled() -> Bool {
        let channel = SMChannelsManager.shared.channel(for: .mediasoup) as! SMMediasoupChannel
        return channel.getVideoEnabled()
    }
    
    func getAudioEnabled() -> Bool {
        let channel = SMChannelsManager.shared.channel(for: .mediasoup) as! SMMediasoupChannel
        return channel.getAudioEnabled()
    }
    
    func getConnectionState() -> SMConnectionState {
        let channel = SMChannelsManager.shared.channel(for: .mediasoup) as! SMMediasoupChannel
        return channel.transport.webSocketClient.getConnectionState()
    }
    
    func getIceConnectionState() -> SMIceConnectionState {
        let channel = SMChannelsManager.shared.channel(for: .mediasoup) as! SMMediasoupChannel
        return channel.getIceConnectionState()
    }
    
    func getAppStreamService() -> SMAppStreamServiceProtocol {
        ScreenVideoCapturer.appStreamService
    }
    
    private func startWebRTC(_ turnUrl: String) {
        SMStartWebRTCTransaction(turnUrl)
            .run { [weak self] error in
            if let error = error {
                NSLog("WebRTC start failed: " + error.message)
            }
            else {
                self?.connectCompletion?(nil)
                NSLog("WebRTC started")
            }
        }
    }
    
    private func reconnect() {
        SMReconnectTransaction().run { session, error in
            if let error = error { NSLog("SMError: " + error.message) }
            else {
                self.session = session
            }
        }
    }
    
    /// Channels messaging
    
    private func processIncomingChannelMessage(_ message: SMChannelMessage) {
        SMChannelsManager.shared.process(message)
    }
    
}

extension SMSession {

   func getAVState() -> SMParticipantMediaState {
        var cState = SMCallerState()
        cState.audioEnabled = getAudioEnabled()
        cState.videoEnabled = getVideoEnabled()
        cState.screenEnabled = getVideoEnabled() && getVideoSourceDevice() == nil
        return SMParticipantMediaState(callerState: cState)
    }
    
    func startVideoSharing(_ cameraDevice: AVCaptureDevice) {
        let msChannel = SMChannelsManager.shared.channel(for: .mediasoup) as! SMMediasoupChannel

        if (getAVState().isVideoActive) {
            /* if the video is running and it's not camera or the devices are different, just switch the source*/
            if (getAVState().videoState != .CAMERA || getVideoSourceDevice()?.uniqueID != cameraDevice.uniqueID) {
                setVideoSourceDevice(videoDevice: cameraDevice)
                msChannel.changeCapturer(cameraDevice) { [weak self] error in
                    if (error == nil) {
                        DispatchQueue.main.async {
                            self?.delegate?.onLocalVideoSourceChanged()
                        }
                    }
                }
            }
            else {
                NSLog("[ScreenMeet]", "Camrea video with the exact same device has been started already")
            }
        }
        else {
            setVideoSourceDevice(videoDevice: cameraDevice)
            msChannel.setVideoState(true)
            SMVideoStateTransaction().run(true)
        }
    }
    
    func startScreenSharing() {
        let msChannel = SMChannelsManager.shared.channel(for: .mediasoup) as! SMMediasoupChannel
        let audioVideoState = getAVState()
        
        /*If the video is running and it's not a screen, just change the source*/
        if (audioVideoState.isVideoActive && audioVideoState.videoState != .SCREEN) {
            msChannel.changeCapturer(nil) { [weak self] error in
                if (error == nil) {
                    DispatchQueue.main.async {
                        self?.delegate?.onLocalVideoSourceChanged()
                    }
                }
            }
        }
        /*The video is stopped - create video track*/
        else if (!audioVideoState.isVideoActive) {
            setVideoSourceDevice(videoDevice: nil)
            msChannel.setVideoState(true)
        }
        
    }

    func stopVideoSharing() {
        if (getAVState().isVideoActive) {
            if let msChannel = SMChannelsManager.shared.channel(for: .mediasoup) as? SMMediasoupChannel {
                msChannel.setVideoState(false)
                
                SMVideoStateTransaction().run(false) { [weak self] error in
                    self?.delegate?.onLocalVideoStopped()
                }
            }
        }
        else {
            NSLog("[ScreenMeet]", "Video has been stopped already")
        }
    }
    
    func stopAudioSharing() {
        if let msChannel = SMChannelsManager.shared.channel(for: .mediasoup) as? SMMediasoupChannel {
            msChannel.setAudioState(false)
            
            SMAudioStateTransaction().run(false) { [weak self] error in
                self?.delegate?.onLocalAudioStopped()
            }
        }
    }
    
    func startAudioSharing() {
        if (getAVState().isAudioActive) {
            NSLog("[ScreenMeet]", "Audio is being shared already")
        }
        else {
            if let msChannel = SMChannelsManager.shared.channel(for: .mediasoup) as? SMMediasoupChannel {
                msChannel.setAudioState(true)
                
                SMAudioStateTransaction().run(true)
            }
        }
    }

    func getVideoSourceDevice() -> AVCaptureDevice! {
        if let msChannel = SMChannelsManager.shared.channel(for: .mediasoup) as? SMMediasoupChannel {
            return msChannel.videoSourceDevice
        } else {
            return nil
        }
    }
    
    func getParticipants() -> [SMParticipant] {
        if let participantsChannel = SMChannelsManager.shared.channel(for: .participants) as? SMParticipantsChannel {
            return participantsChannel.getParticipants()
        } else {
            return [SMParticipant]()
        }
    }

}
