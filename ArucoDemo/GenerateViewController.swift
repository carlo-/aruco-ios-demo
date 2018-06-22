//
//  GenerateViewController.swift
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 22/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

import UIKit
import UIScreenExtension

class GenerateViewController: UIViewController {

    @IBOutlet private weak var imageViewSide: NSLayoutConstraint!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var markerField: UITextField!
    @IBOutlet private weak var sizeLabel: UILabel!
    @IBOutlet private weak var slider: UISlider!

    private let generator = ArucoGenerator()

    private let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.allowsFloats = false
        nf.alwaysShowsDecimalSeparator = false
        nf.isLenient = true
        nf.minimum = 0
        nf.maximum = Int32.max as NSNumber
        return nf
    }()

    private let devicePhysicalWidth: Float = {
        if let cm = UIScreen.dimensionInCentimeters?.width {
            return Float(cm) / 100.0
        } else {
            return .infinity
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setMarkerSize(meters: 0.04)
        setMarkerID(52)
    }

    func setMarkerSize(meters: Float) {
        slider.value = min(max(meters / devicePhysicalWidth, 0.0), 1.0)
        sliderValueChanged()
    }

    func setMarkerID(_ markerID: Int32) {
        markerField.text = markerID.description
        imageView.image = generator.generateMarkerImage(markerID)
    }

    @IBAction func sliderValueChanged() {
        let virtualSize = CGFloat(slider.value) * view.bounds.width
        let physicalSize = slider.value * devicePhysicalWidth
        imageViewSide.constant = virtualSize
        sizeLabel.text = "\(physicalSize)m"
        sizeLabel.isHidden = !physicalSize.isFinite
    }

    @IBAction func generate() {

        markerField.resignFirstResponder()

        if let text = markerField.text, let num = numberFormatter.number(from: text) {
            setMarkerID(num.int32Value)
        } else {
            markerField.text = nil
            imageView.image = nil
        }
    }
}
