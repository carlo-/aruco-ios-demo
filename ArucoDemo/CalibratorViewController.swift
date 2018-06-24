//
//  CalibratorViewController.swift
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 23/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

import UIKit

class CalibratorViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet private weak var camView: UIImageView!
    @IBOutlet private weak var rotatedBar: RotatedBar!

    private var counterLabel: UILabel!
    private var startStopButton: UIButton!
    private var undistortButton: UIButton!
    private var loadingIndicator: UIAlertController?

    private var shouldWarnUser = false
    private var captureSession: AVCaptureSession?
    private var device: AVCaptureDevice?
    private var calibrator: Calibrator!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupRotatedBar()
        setupCalibrator()
        setupSession()
        updateCounterLabel()
        updateActionButton()
    }

    func setupRotatedBar() {

        let thisTextDown = UILabel(frame: .zero)
        thisTextDown.translatesAutoresizingMaskIntoConstraints = false
        thisTextDown.text = "This text down"
        thisTextDown.sizeToFit()

        startStopButton = UIButton(type: .system)
        startStopButton.translatesAutoresizingMaskIntoConstraints = false
        startStopButton.setTitle("Start", for: .init(rawValue: 0))
        startStopButton.sizeToFit()
        startStopButton.addTarget(self, action: #selector(toggleCalibration), for: .touchUpInside)

        undistortButton = UIButton(type: .system)
        undistortButton.translatesAutoresizingMaskIntoConstraints = false
        undistortButton.setTitle("Undistort", for: .init(rawValue: 0))
        undistortButton.sizeToFit()
        undistortButton.addTarget(self, action: #selector(showUndistortedImage), for: .touchDown)
        undistortButton.addTarget(self, action: #selector(showDistortedImage), for: .touchUpInside)
        undistortButton.addTarget(self, action: #selector(showDistortedImage), for: .touchCancel)

        counterLabel = UILabel(frame: .zero)
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        counterLabel.text = "89/100"
        counterLabel.textAlignment = .right
        counterLabel.sizeToFit()

        rotatedBar.setup(
            with: [thisTextDown, startStopButton, undistortButton, counterLabel],
            insets: (dx: 0, dy: 10)
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        captureSession?.startRunning()    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession?.stopRunning()
    }

    func updateActionButton() {
        if calibrator.status == .capturing {
            startStopButton.setTitle("Stop", for: .init(rawValue: 0))
        } else {
            startStopButton.setTitle("Start", for: .init(rawValue: 0))
        }
    }

    func updateCounterLabel() {
        let acquired = calibrator.acquiredFrames;
        let total = calibrator.numberOfFrames;
        counterLabel.text = "\(acquired)/\(total)"
    }

    func showLoadingIndicator() {
        loadingIndicator?.dismiss(animated: false, completion: nil)
        loadingIndicator = UIAlertController(title: "Loading...", message: nil, preferredStyle: .alert)
        present(loadingIndicator!, animated: true, completion: nil)
    }

    @objc func toggleCalibration(_ sender: UIButton) {
        if calibrator.status == .capturing {
            calibrator.abort()
        } else {
            calibrator.start()
        }
    }

    @objc func showDistortedImage(_ sender: Any) {
        calibrator.undistortImage = false
    }

    @objc func showUndistortedImage(_ sender: Any) {
        calibrator.undistortImage = true
    }

    func setupCalibrator() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        let calibPath = "\(docsDir)/camera_parameters.yml"
        calibrator = Calibrator(outputFile: calibPath, delegate: self)
        calibrator.pattern = .chessboard
        calibrator.patternWidth = 8
        calibrator.patternHeight = 6
        calibrator.undistortImage = false
        calibrator.squareSize = 0.0175
    }

    func setupSession() {

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

        calibrator.previewRotation = .cw90
        calibrator.prepare(for: videoOutput, orientation: .landscapeRight)
    }
}

extension CalibratorViewController: CalibratorDelegate {

    func calibratorDidStartAcquisition(_ calibrator: Calibrator) {
        print("===> Calibration starting...")
        DispatchQueue.main.async { [unowned self] in
            self.updateActionButton()
            self.updateCounterLabel()
        }
    }

    func calibratorDidCancelAcquisition(_ calibrator: Calibrator) {
        print("===> Calibration cancelled.")
        DispatchQueue.main.async { [unowned self] in
            self.updateActionButton()
            self.updateCounterLabel()
        }
    }

    func calibrator(_ calibrator: Calibrator, didProcessFrame frame: UIImage) {
        DispatchQueue.main.async { [unowned self] in
            self.camView.image = frame
        }
    }

    func calibrator(_ calibrator: Calibrator, didAcquireFrame frame: UIImage, atStep step: Int32) {
        print("===> Step \(calibrator.acquiredFrames)/\(calibrator.numberOfFrames)")
        DispatchQueue.main.async { [unowned self] in
            self.updateCounterLabel()
        }
    }

    func calibratorDidCompleteAcquisition(_ calibrator: Calibrator) {
        DispatchQueue.main.async { [unowned self] in
            self.showLoadingIndicator()
        }
    }

    func calibrator(_ calibrator: Calibrator, didTerminateWithResult result: Bool, avgReprojectionError avgError: Double, rms: Double) {

        if result {
            print("===> Calibration completed successfully!")
            print("===> RMS: \(rms), Avg. reprojection error: \(avgError)")
        } else {
            print("===> Calibration failed!")
        }

        DispatchQueue.main.async { [unowned self] in
            self.updateActionButton()

            let title = result ? "Calibration completed!" : "Calibration failed!"
            let message = result ? "Avg. reprojection error: \(avgError)" : nil
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))

            self.loadingIndicator?.dismiss(animated: true) {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}
