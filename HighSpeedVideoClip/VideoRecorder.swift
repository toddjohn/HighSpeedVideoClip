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

    var isRecording: Bool {
        return dataOutput.recording
    }

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
                device.activeVideoMaxFrameDuration = bestFrameRateRange.minFrameDuration
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
        let url = NSURL(fileURLWithPath: NSTemporaryDirectory() + "/clip.mov")
        dataOutput.startRecordingToOutputFileURL(url, recordingDelegate: self)
    }

    func stopRecording() {
        dataOutput.stopRecording()
    }

    func clipVideo(inputUrl: NSURL) {

        // input video
        let asset = AVAsset(URL: inputUrl)
        let duration = CMTimeGetSeconds(asset.duration)
        var startTime = CMTimeMakeWithSeconds(0, asset.duration.timescale)
        var endTime = asset.duration
        if duration > 4.0 {
            let fourSeconds = CMTimeMakeWithSeconds(4.0, asset.duration.timescale)
            startTime = CMTimeSubtract(asset.duration, fourSeconds)
            let oneSecond = CMTimeMakeWithSeconds(1.0, asset.duration.timescale)
            endTime = CMTimeSubtract(asset.duration, oneSecond)
        }
        let timeRange = CMTimeRangeFromTimeToTime(startTime, endTime)
//        let composition = AVMutableComposition()
//        composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
//        let clip = asset.tracksWithMediaType(AVMediaTypeVideo).first!

        // transform
//        let videoComposition = AVMutableVideoComposition()
//        videoComposition.renderSize = clip.naturalSize
//        videoComposition.frameDuration = device.activeVideoMaxFrameDuration
//        let instruction = AVMutableVideoCompositionInstruction()
//        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, timeRange.duration)
//        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: clip)
        // uncomment to use portrait
//        let t1 = CGAffineTransformMakeTranslation(clip.naturalSize.height, -(clip.naturalSize.width-clip.naturalSize.height)/2)
//        let t2 = CGAffineTransformRotate(t1, CGFloat(M_PI_2))
//        transformer.setTransform(t2, atTime: kCMTimeZero)
//        instruction.layerInstructions = [transformer]
//        videoComposition.instructions = [instruction]

        // output
        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
//        exporter?.videoComposition = videoComposition
        let docFolder = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        let outputUrl = docFolder.first!.URLByAppendingPathComponent("clip.mov")
        exporter?.outputURL = outputUrl
        exporter?.outputFileType = AVFileTypeQuickTimeMovie
        exporter?.timeRange = timeRange
        exporter?.exportAsynchronouslyWithCompletionHandler({
            switch exporter!.status {
            case .Unknown:
                NSLog("Export unknown")
            case .Waiting:
                NSLog("Export waiting")
            case .Exporting:
                NSLog("Export exporting")
            case .Completed:
                NSLog("Export complete to " + self.outputPath)
            case .Failed:
                NSLog("Export error: " + exporter!.error!.localizedDescription)
            case .Cancelled:
                NSLog("Export cancelled")
            }
        })
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        NSLog("Done recording, output saved in " + outputFileURL.absoluteString)
        if error != nil {
            NSLog("Video recording error: " + error.localizedDescription)
        }
        if NSFileManager.defaultManager().fileExistsAtPath(outputPath) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(outputPath)
            } catch let error as NSError {
                NSLog("unable to delete file: " + error.localizedDescription)
            }
        }
        clipVideo(outputFileURL)
    }
}
