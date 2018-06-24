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
    @IBOutlet private weak var rotatedBar: RotatedBar!

    private var trackerSetup = false
    private var captureSession: AVCaptureSession?
    private var device: AVCaptureDevice?
    private var arucoTracker: ArucoTracker?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupRotatedBar()
    }

    func setupRotatedBar() {
        let thisTextDown = UILabel(frame: .zero)
        thisTextDown.translatesAutoresizingMaskIntoConstraints = false
        thisTextDown.text = "This text down"
        thisTextDown.sizeToFit()
        rotatedBar.setup(with: [thisTextDown], insets: (dx: 0, dy: 10))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupTrackerIfNeeded()
        captureSession?.startRunning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession?.stopRunning()
    }

    func setupTrackerIfNeeded() {

        if trackerSetup {return}

        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        let calibPath = "\(docsDir)/camera_parameters.yml"

        if !FileManager.default.fileExists(atPath: calibPath) {
            warnUser()
        } else {
            arucoTracker = ArucoTracker(calibrationFile: calibPath, delegate: self)
            setupSession()
            trackerSetup = true
        }
    }

    func setupSession() {

        guard let tracker = arucoTracker
            else { fatalError("prepareSession() must be called after initializing the tracker") }

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

        tracker.previewRotation = .cw90
        tracker.prepare(for: videoOutput, orientation: .landscapeRight)
    }

    func warnUser() {
        let alert = UIAlertController(
            title: "Warning",
            message: "Camera calibration file (camera_parameters.yml) not found in Documents folder; this is necessary for accurate pose detection.",
            preferredStyle: .alert
        )
        // alert.addAction(UIAlertAction(title: "Calibrate", style: .default, handler: showCalibrator))
        alert.addAction(UIAlertAction(title: "Ignore", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension TrackViewController: ArucoTrackerDelegate {

    func arucoTracker(_ tracker: ArucoTracker, didDetect markers: [ArucoMarker], preview: UIImage?) {
        DispatchQueue.main.async { [unowned self] in
            self.camView.image = preview
        }
    }
}
