//
//  PreviewView.swift
//  MrzReader
//
//  Created by Orlando Karamani on 25.11.22.
//  Copyright © 2022 better. All rights reserved.
//

import AVFoundation
import UIKit

public class PreviewView: UIView {
  public var videoPreviewLayer: AVCaptureVideoPreviewLayer {
    guard let layer = layer as? AVCaptureVideoPreviewLayer else {
      fatalError("""
      Expected `AVCaptureVideoPreviewLayer` type for layer.
      Check PreviewView.layerClass implementation.
      """)
    }

    return layer
  }

  public var session: AVCaptureSession? {
    get { videoPreviewLayer.session }
    set { videoPreviewLayer.session = newValue }
  }

  // MARK: UIView

  override public class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }
}
