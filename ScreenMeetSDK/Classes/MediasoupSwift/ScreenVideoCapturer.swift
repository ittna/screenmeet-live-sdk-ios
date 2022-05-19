//
//  ScreenVideoCapturer.swift
//  iOS-Prototype-SDK
//
//  Created by Vasyl Morarash on 20.05.2020.
//

import Foundation
import WebRTC
import ReplayKit

class ScreenVideoCapturer: RTCVideoCapturer, SMVideoCapturer, AVCaptureVideoDataOutputSampleBufferDelegate {
        
    var frameQueue = DispatchQueue(label: "com.screenmeet.webrtc.screencapturer.video")
    let captureSession = AVCaptureSession()
    static let appStreamService = SMAppStreamService()
    
    override init(delegate: RTCVideoCapturerDelegate) {
        super.init(delegate: delegate)
    }
    
    func startCapture(_ completionHandler: SMCapturerOperationCompletion? = nil) {
        self.startCaptureScreen(completionHandler)
    }

    public func startCaptureScreen(_ completionHandler: SMCapturerOperationCompletion? = nil) {
        RTCDispatcher.dispatchAsync(on: .typeCaptureSession, block: {
            self.reconfigureCaptureSessionInput()
            self.captureSession.startRunning()
            
            ScreenVideoCapturer.appStreamService.startStream(completionHandler) { (result) in
                switch result {
                case .success(let pixelBuffer):
                    let rotation = RTCVideoRotation._0 // Default rotation
                    let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
                    let timeStampNs: Int64 = Int64(Date().timeIntervalSince1970 * 1000000000)
                    let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: rotation, timeStampNs: timeStampNs)
                    self.delegate?.capturer(self, didCapture: videoFrame)
                case .failure(let error):
                    switch error {
                        case .startCaptureFailed(let captureError):
                            completionHandler?(SMError(code: .capturerInternalError, message: captureError.localizedDescription))
                        case .stopCaptureFailed:
                            NSLog("Stop capture error ocurreced when starting capturing")
                    }
                }
            }
        })
    }
    
    public func setupCaptureSession(captureSession: AVCaptureSession) {
        let videoDataOutput = self.setupVideoDataOutput();
        if (!captureSession.canAddOutput(videoDataOutput)) {
            print("WARNING: Video data output unsupported.");
            //return false
        }
        captureSession.addOutput(videoDataOutput)
    }
    
    public func setupVideoDataOutput() -> AVCaptureVideoDataOutput {
        let videoDataOutput = AVCaptureVideoDataOutput()

        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: self.frameQueue)
        return videoDataOutput
    }
    
    public func reconfigureCaptureSessionInput() {
        self.captureSession.beginConfiguration()
        captureSession.usesApplicationAudioSession = false
        self.captureSession.commitConfiguration()
    }
    
    public func sendScreenshot(_ sampleBuffer: CMSampleBuffer, _ orientation: RTCVideoRotation) {
        if (self.delegate != nil) {
              if (CMSampleBufferGetNumSamples(sampleBuffer) != 1 || !CMSampleBufferIsValid(sampleBuffer) ||
                !CMSampleBufferDataIsReady(sampleBuffer)) {
              }
              else {
                let _rotation = orientation
                if let _pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    let _rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: _pixelBuffer)
                    let timeStampNs: Int64 = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000000000)
                    let _videoFrame = RTCVideoFrame(buffer:_rtcPixelBuffer, rotation:_rotation, timeStampNs:timeStampNs)
                    self.delegate?.capturer(self, didCapture:_videoFrame)
                }
              }
        }
    }
    
    public func stopCapture(_ completionHandler: SMCapturerOperationCompletion? = nil) {
        ScreenVideoCapturer.appStreamService.stopStream { (result) in
            switch result {
            case .success:
                RTCDispatcher.dispatchAsync(on: .typeCaptureSession, block: {
                    let inputs = self.captureSession.inputs.map { $0.copy() }
                    inputs.forEach({input in self.captureSession.removeInput(input as! AVCaptureInput)})
                    self.captureSession.stopRunning()
                    self.delegate = nil
                    completionHandler?(nil)
                })
            case .failure(let error):
                completionHandler?(SMError(code: .capturerInternalError, message: error.localizedDescription))
            }
        }
    }
    
    func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
}

extension CGImage {
    
    func newPixelBufferFromCGImage() -> CVPixelBuffer {
        let options = [kCVPixelBufferCGImageCompatibilityKey: NSNumber(booleanLiteral: true),
                       kCVPixelBufferCGBitmapContextCompatibilityKey: NSNumber(booleanLiteral: true)]
        
        var pxbuffer : CVPixelBuffer! = nil
        
        _ = CVPixelBufferCreate(kCFAllocatorDefault,
                                self.width,
                                self.height,
                                kCVPixelFormatType_32ARGB,
                                options as CFDictionary, &pxbuffer)
        
        CVPixelBufferLockBaseAddress(pxbuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pxdata = CVPixelBufferGetBaseAddress(pxbuffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pxdata,
                                width: self.width,
                                height: self.height,
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * self.width,
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context!.draw(self, in: CGRect(x: 0,y: 0,width: self.width,height: self.height))
        CVPixelBufferUnlockBaseAddress(pxbuffer, CVPixelBufferLockFlags(rawValue: 0))

        return pxbuffer
    }
}


