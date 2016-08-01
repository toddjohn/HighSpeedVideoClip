//
//  VideoRecorder.swift
//  HighSpeedVideoClip
//
//  Created by Todd Johnson on 7/29/16.
//  Copyright © 2016 toddjohn. All rights reserved.
//

import AVFoundation

class VideoRecorder: NSObject {
    var captureSession: AVCaptureSession!
    var device: AVCaptureDevice!
    var deviceInput: AVCaptureDeviceInput!
    var dataOutput: AVCaptureMovieFileOutput!
    var connection: AVCaptureConnection!

    var outputPath = NSTemporaryDirectory() + "/clip.mov"
    let maxSeconds = 30

    var isRecording = false

    required init(filePath: String) {
        super.init()

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720

        device = getBackCamera()

        do {
            deviceInput = try AVCaptureDeviceInput(device: device)
            captureSession.addInput(deviceInput)
        } catch let error as NSError {
            NSLog("device capture input failed: " + error.localizedDescription)
        }

        var bestFormat: AVCaptureDeviceFormat!
        var bestFrameRateRange: AVFrameRateRange!
        for format in device.formats as! [AVCaptureDeviceFormat] {
//            NSLog("Found format: " + format.description)
            for range in format.videoSupportedFrameRateRanges as! [AVFrameRateRange] {
                if bestFormat == nil {
                    bestFormat = format
                    bestFrameRateRange = range
                }

                if range.maxFrameRate > bestFrameRateRange.maxFrameRate {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }
        if bestFormat != nil {
            NSLog("Using format: " + bestFormat.description)
            do {
                try device.lockForConfiguration()
                device.activeFormat = bestFormat
                device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration
                device.activeVideoMaxFrameDuration = CMTimeMultiply(bestFrameRateRange.minFrameDuration, 2)
                device.unlockForConfiguration()
            } catch let error as NSError {
                NSLog("device lock failed: " + error.localizedDescription)
            }
        } else {
            NSLog("Using default format: " + device.activeFormat.description)
        }

        dataOutput = AVCaptureMovieFileOutput()
        let maxDuration = CMTimeMakeWithSeconds(Float64(maxSeconds), Int32(bestFrameRateRange.maxFrameRate))
        dataOutput.maxRecordedDuration = maxDuration
        let kb = Int64(1024)
        let mb = kb * kb
        dataOutput.minFreeDiskSpaceLimit = 10 * mb
        outputPath = filePath
        captureSession.addOutput(dataOutput)

        if let connection = dataOutput.connectionWithMediaType(AVMediaTypeVideo) {
            if device.activeFormat.isVideoStabilizationModeSupported(AVCaptureVideoStabilizationMode.Cinematic) {
                connection.preferredVideoStabilizationMode = .Cinematic
            }
            connection.videoOrientation = .LandscapeRight
        }
    }

    private func getBackCamera() -> AVCaptureDevice {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]!
        for camera in devices {
            if camera.position == AVCaptureDevicePosition.Back {
                return camera
            }
        }

        return AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill
        layer.connection.videoOrientation = .LandscapeRight
        return layer
    }

    func startPreview() {
        captureSession.startRunning()
    }

    func stopPreview() {
        captureSession.stopRunning()
    }

    func startRecording() {
        let url = NSURL(fileURLWithPath: outputPath)
        dataOutput.startRecordingToOutputFileURL(url, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() {
        dataOutput.stopRecording()
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        isRecording = false
        if error != nil {
            NSLog("Video recording error: " + error.localizedDescription)
        }
    }
}
