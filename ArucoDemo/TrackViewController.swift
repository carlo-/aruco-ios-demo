//
//  TrackViewController.swift
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 20/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

import UIKit
import AVFoundation

class TrackViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet private weak var camView: UIImageView!

    private var shouldWarnUser = false
    private var captureSession: AVCaptureSession?
    private var device: AVCaptureDevice?
    private var arucoTracker: ArucoTracker!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTracker()
        prepareSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        captureSession?.startRunning()
        if shouldWarnUser { warnUserAboutCalibration() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession?.stopRunning()
    }

    func setupTracker() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        let calibPath = "\(docsDir)/camera_parameters.yml"
        if !FileManager.default.fileExists(atPath: calibPath) {
            let exCalibPath = Bundle.main.path(forResource: "example_camera_parameters", ofType: "yml")!
            try? FileManager.default.copyItem(atPath: exCalibPath, toPath: calibPath)
            shouldWarnUser = true
        }
        arucoTracker = ArucoTracker(calibrationFile: calibPath, delegate: self)
    }

    func prepareSession() {

        device = AVCaptureDevice.default(for: .video)
        guard device != nil, let videoInput = try? AVCaptureDeviceInput(device: device!)
            else { fatalError("Device unavailable") }

        let videoOutput = AVCaptureVideoDataOutput()

        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .iFrame960x540

        guard captureSession!.canAddInput(videoInput), captureSession!.canAddOutput(videoOutput)
            else { fatalError("Cannot add video I/O to capture session") }

        captureSession?.addInput(videoInput)
        captureSession?.addOutput(videoOutput)

        arucoTracker.prepare(for: videoOutput)
    }

    func warnUserAboutCalibration() {
        let alert = UIAlertController(
            title: "Warning",
            message: "Camera calibration file (camera_parameters.yml) not found in Documents folder; this is necessary for accurate pose detection. An example calibration file will be copied and used temporarely. This message will not appear again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        shouldWarnUser = false
    }
}

extension TrackViewController: ArucoTrackerDelegate {

    func arucoTracker(_ tracker: ArucoTracker, didDetect markers: [ArucoMarker], preview: UIImage?) {
        DispatchQueue.main.async { [unowned self] in
            self.camView.image = preview
        }
    }
}
