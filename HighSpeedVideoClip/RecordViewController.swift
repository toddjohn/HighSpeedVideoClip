//
//  RecordViewController.swift
//  HighSpeedVideoClip
//
//  Created by Todd Johnson on 7/29/16.
//  Copyright © 2016 toddjohn. All rights reserved.
//

import AVFoundation
import UIKit

class RecordViewController: UIViewController {
    @IBOutlet var videoPreview: UIView!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var bufferLabel: UILabel!
    @IBOutlet var activityView: UIView!

    var path = NSTemporaryDirectory() + "/clip.mov"

    var recorder: VideoRecorder!
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        recorder = VideoRecorder(filePath: path)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        recorder.outputPath = path
        if previewLayer == nil {
            previewLayer = recorder.getPreviewLayer()
            previewLayer.frame = videoPreview.bounds
            videoPreview.layer.addSublayer(previewLayer)
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        previewLayer.frame = videoPreview.bounds
        bufferLabel.text = "0s"
        if AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) != AVAuthorizationStatus.Authorized {
            let requestComplete: (granted: Bool) -> () = { granted in
                NSLog("access granted: " + granted.description)
            }
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: requestComplete)
        }

        recorder.startPreview()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        if recorder.isRecording {
            recorder.stopRecording()
        }
        recorder.stopPreview()
    }

    @IBAction func recordButtonTapped(sender: UIButton) {
        if recorder.isRecording {
            recorder.stopRecording()
            sender.selected = false
        } else {
            recorder.startRecording()
            sender.selected = true
        }
    }
}
