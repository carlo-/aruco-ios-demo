//
//  Utilities.swift
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 24/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

import UIKit

class RotatedBar: UIView {

    private var insets: (dx: CGFloat, dy: CGFloat)?

    func setup(with subviews:[UIView], insets: (dx: CGFloat, dy: CGFloat)? = nil) {
        let stackView = UIStackView(arrangedSubviews: subviews)
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.transform = CGAffineTransform(rotationAngle: .pi/2)
        self.addSubview(stackView)
        self.insets = insets
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.first?.frame = bounds.insetBy(dx: insets?.dx ?? 0, dy: insets?.dy ?? 0)
        subviews.first?.center = CGPoint(x: frame.width/2, y: frame.height/2)
    }
}
