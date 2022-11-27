//
//  QKCutoutView.swift
//  QKMRZScanner
//
//  Created by Matej Dorcak on 05/10/2018.
//

import UIKit

class CutoutView: UIView {
    fileprivate(set) var cutoutRect: CGRect!
    // Passport's size (ISO/IEC 7810 ID-3) is 125mm × 88mm
    // ID Card's size (ISO/IEC 7810 ID-1) is 125mm × 88mm
    @objc var documentFrameRatio = CGFloat(1.42)
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.45)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Orientation or the view's size could change
        recalculateCutoutRect()
    }
    
    // MARK: Private
    public func recalculateCutoutRect() {
        let (width, height): (CGFloat, CGFloat)

        if bounds.height > bounds.width {
            width = (bounds.width * 0.9) // Fill 90% of the width
            height = (width / documentFrameRatio)
        }
        else {
            height = (bounds.height * 0.75) // Fill 75% of the height
            width = (height * documentFrameRatio)
        }

        let topOffset = (bounds.height - height) / 2
        let leftOffset = (bounds.width - width) / 2

        cutoutRect = CGRect(x: leftOffset, y: topOffset, width: width, height: height)

        addBorderAroundCutout()
    }

    public func addBorderAroundCutout() {
        let maskLayer = CAShapeLayer()
        let path = CGMutablePath()
        let cornerRadius = CGFloat(3)
        
        path.addRoundedRect(in: cutoutRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        path.addRect(bounds)
        
        maskLayer.path = path
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        
        layer.mask = maskLayer
        
        // Add border around the cutout
        let borderLayer = CAShapeLayer()
        
        borderLayer.path = UIBezierPath(roundedRect: cutoutRect, cornerRadius: cornerRadius).cgPath
        borderLayer.lineWidth = 3
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.frame = bounds
        
        layer.sublayers = [borderLayer]
    }
}
