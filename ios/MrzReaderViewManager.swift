import Foundation
import AVFoundation

@objc(MrzReaderViewManager)
class MrzReaderViewManager: RCTViewManager {
    
    override func view() -> (MrzReaderView) {
        return MrzReaderView()
    }
    
    @objc override static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    @objc
    final func getCameraPermissionStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        withPromise(resolve: resolve, reject: reject) {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            return status.descriptor
        }
    }
    
    @objc
    final func requestCameraPermission(_ resolve: @escaping RCTPromiseResolveBlock, reject _: @escaping RCTPromiseRejectBlock) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            let result: AVAuthorizationStatus = granted ? .authorized : .denied
            resolve(result.descriptor)
        }
    }
}

