import AVFoundation
import SwiftyTesseract
import QKMRZParser
import AudioToolbox
import Vision

enum DocumentType: String, CaseIterable {
   case passport = "P"
   case identityCard = "I"
}

// MARK: - MRZReaderView
public class MrzReaderView : UIView {
    fileprivate let tesseract = SwiftyTesseract(language: .custom("ocrb"), dataSource: Bundle(for: MrzReaderView.self), engineMode: .tesseractOnly)
    fileprivate let mrzParser = QKMRZParser(ocrCorrection: true)
    fileprivate let captureSession = AVCaptureSession()
    fileprivate let videoOutput = AVCaptureVideoDataOutput()
    fileprivate let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    fileprivate let notificationFeedback = UINotificationFeedbackGenerator()
    fileprivate let cutoutView = CutoutView()
    fileprivate var isScanningPaused = false
    fileprivate var observer: NSKeyValueObservation?
    fileprivate var segmentedControl: UISegmentedControl?
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    fileprivate var interfaceOrientation: UIInterfaceOrientation {
        return UIApplication.shared.statusBarOrientation
    }
    @objc private let cameraQueue = DispatchQueue(label: "camera_queue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    // MARK: Public properties
    @objc var onMrzResult: RCTDirectEventBlock?
    @objc var onError: RCTDirectEventBlock?
    @objc var isScanning = false
    @objc var vibrateOnResult = true
    
    @objc var items = ["Pasaportë", "Kartë ID"]
    @objc var passportLabel = "Skano faqen e fotos"
    @objc var idCardLabel = "Skano faqen e pasme të kartës"
    @objc var documentLabel = UILabel()
    @objc var torch = "off"
    
    public var cutoutRect: CGRect {
        return cutoutView.cutoutRect
    }
    
    // MARK: Initializers
    override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Overriden methods
    override public func prepareForInterfaceBuilder() {
        setViewStyle()
        addCutoutView()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        adjustVideoPreviewLayerFrame()
    }
    
    override public final func didSetProps(_ changedProps: [String]!) {
        let shouldUpdateTorch = changedProps.contains("torch")
        let shouldUpdateScanning = changedProps.contains("isScanning")
        
        cameraQueue.async {
            if shouldUpdateTorch {
                self.cameraQueue.asyncAfter(deadline: .now() + 0.1) {
                    self.setTorchMode(self.torch)
                }
            }
            
            if shouldUpdateScanning {
                self.changeScanningStatus(isScanning: self.isScanning)
            }
            
        }
        
    }
    
    private func changeScanningStatus(isScanning: Bool) {
        if self.captureSession.isRunning != self.isScanning {
            if self.isScanning {
                ReactLogger.log(level: .info, message: "Starting Session...")
                self.startScanning()
                ReactLogger.log(level: .info, message: "Started Session!")
            } else {
                ReactLogger.log(level: .info, message: "Stopping Session...")
                self.stopScanning()
                ReactLogger.log(level: .info, message: "Stopped Session!")
            }
        }
    }
    
    // MARK: Scanning
    public func startScanning() {
        guard !captureSession.inputs.isEmpty else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            self?.notificationFeedback.prepare()
            DispatchQueue.main.async { [weak self] in self?.adjustVideoPreviewLayerFrame() }
        }
    }
    
    private func addSegmentedControl() {
        segmentedControl = UISegmentedControl(items: items)
        
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        segmentedControl!.selectedSegmentIndex = 0
        segmentedControl!.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl!.addTarget(self, action: #selector(self.segmentedValueChanged(_:)), for: .valueChanged)

        self.addSubview(segmentedControl!)

        NSLayoutConstraint.activate([
            segmentedControl!.centerXAnchor.constraint(equalTo: centerXAnchor),
            segmentedControl!.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
        
        self.insertSubview(blurEffectView, belowSubview: segmentedControl!)
        NSLayoutConstraint.activate([
            blurEffectView.leadingAnchor.constraint(equalTo: segmentedControl!.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: segmentedControl!.trailingAnchor),
            blurEffectView.topAnchor.constraint(equalTo: segmentedControl!.topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: segmentedControl!.bottomAnchor)
        ])

        blurEffectView.layer.cornerRadius = 8
        blurEffectView.layer.masksToBounds = true
        
    }
    
    @objc func segmentedValueChanged(_ sender:UISegmentedControl!)
    {
        if sender.selectedSegmentIndex == 1 {
            cutoutView.documentFrameRatio = CGFloat(1.58)
            documentLabel.text = idCardLabel
        } else {
            cutoutView.documentFrameRatio = CGFloat(1.42)
            documentLabel.text = passportLabel
        }
        recalculateLabelPosition()
        cutoutView.setNeedsLayout()
    }
    
    public func stopScanning() {
        captureSession.stopRunning()
    }
    
    // MARK: MRZ
    fileprivate func mrz(from cgImage: CGImage) -> QKMRZResult? {
        let mrzTextImage = UIImage(cgImage: preprocessImage(cgImage))
        let recognizedString = try? tesseract.performOCR(on: mrzTextImage).get()
        
        if let string = recognizedString, let mrzLines = mrzLines(from: string) {
            return mrzParser.parse(mrzLines: mrzLines)
        }
        
        return nil
    }
    
    fileprivate func mrzLines(from recognizedText: String) -> [String]? {
        let mrzString = recognizedText.replacingOccurrences(of: " ", with: "")
        var mrzLines = mrzString.components(separatedBy: "\n").filter({ !$0.isEmpty })
        
        // Remove garbage strings located at the beginning and at the end of the result
        if !mrzLines.isEmpty {
            let averageLineLength = (mrzLines.reduce(0, { $0 + $1.count }) / mrzLines.count)
            mrzLines = mrzLines.filter({ $0.count >= averageLineLength })
        }
        
        return mrzLines.isEmpty ? nil : mrzLines
    }
    
    // MARK: Document Image from Photo cropping
    fileprivate func cutoutRect(for cgImage: CGImage) -> CGRect {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let rect = videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: cutoutRect)
        let videoOrientation = videoPreviewLayer.connection!.videoOrientation
        
        if videoOrientation == .portrait || videoOrientation == .portraitUpsideDown {
            return CGRect(x: (rect.minY * imageWidth), y: (rect.minX * imageHeight), width: (rect.height * imageWidth), height: (rect.width * imageHeight))
        }
        else {
            return CGRect(x: (rect.minX * imageWidth), y: (rect.minY * imageHeight), width: (rect.width * imageWidth), height: (rect.height * imageHeight))
        }
    }
    
    fileprivate func documentImage(from cgImage: CGImage) -> CGImage {
        let croppingRect = cutoutRect(for: cgImage)
        return cgImage.cropping(to: croppingRect) ?? cgImage
    }
    
    fileprivate func enlargedDocumentImage(from cgImage: CGImage) -> UIImage {
        var croppingRect = cutoutRect(for: cgImage)
        let margin = (0.05 * croppingRect.height) // 5% of the height
        croppingRect = CGRect(x: (croppingRect.minX - margin), y: (croppingRect.minY - margin), width: croppingRect.width + (margin * 2), height: croppingRect.height + (margin * 2))
        return UIImage(cgImage: cgImage.cropping(to: croppingRect)!)
    }
    
    // MARK: UIApplication Observers
    @objc fileprivate func appWillEnterForeground() {
        if isScanningPaused {
            isScanningPaused = false
            startScanning()
        }
    }
    
    @objc fileprivate func appDidEnterBackground() {
        if isScanning {
            isScanningPaused = true
            stopScanning()
        }
    }
    
    // MARK: Init methods
    fileprivate func initialize() {
        FilterVendor.registerFilters()
        setViewStyle()
        addCutoutView()
        initCaptureSession()
        addAppObservers()
        addSegmentedControl()
        addDocumentLabel()
    }
    
    fileprivate func setViewStyle() {
        backgroundColor = .black
    }
    
    fileprivate func addCutoutView() {
        cutoutView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(cutoutView)
        
        NSLayoutConstraint.activate([
            cutoutView.topAnchor.constraint(equalTo: topAnchor),
            cutoutView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cutoutView.leftAnchor.constraint(equalTo: leftAnchor),
            cutoutView.rightAnchor.constraint(equalTo: rightAnchor)
        ])
    }
    
    fileprivate func addDocumentLabel() {
        documentLabel.translatesAutoresizingMaskIntoConstraints = false
        documentLabel.text = passportLabel
        documentLabel.font = UIFont.systemFont(ofSize: 14)

        addSubview(documentLabel)
        
        NSLayoutConstraint.activate([
            documentLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
    
    fileprivate func initCaptureSession() {
        captureSession.sessionPreset = .hd1920x1080
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Camera not accessible")
            return
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: camera) else {
            print("Capture input could not be initialized")
            return
        }
        
        videoDeviceInput = deviceInput
        
        observer = captureSession.observe(\.isRunning, options: [.new]) { [unowned self] (model, change) in
            // CaptureSession is started from the global queue (background). Change the `isScanning` on the main
            // queue to avoid triggering the change handler also from the global queue as it may affect the UI.
            DispatchQueue.main.async { [weak self] in self?.isScanning = change.newValue! }
        }
        
        if captureSession.canAddInput(deviceInput) && captureSession.canAddOutput(videoOutput) {
            captureSession.addInput(deviceInput)
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video_frames_queue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem))
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any]
            videoOutput.connection(with: .video)!.videoOrientation = AVCaptureVideoOrientation(orientation: interfaceOrientation)
            
            videoPreviewLayer.session = captureSession
            videoPreviewLayer.videoGravity = .resizeAspectFill
            startScanning()
            layer.insertSublayer(videoPreviewLayer, at: 0)
        }
        else {
            print("Input & Output could not be added to the session")
        }
    }
    
    fileprivate func addAppObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    fileprivate func recalculateLabelPosition() {
        let (width, height): (CGFloat, CGFloat)

        if bounds.height > bounds.width {
            width = (bounds.width * 0.9)
            height = (width / cutoutView.documentFrameRatio)
        }
        else {
            height = (bounds.height * 0.75) // Fill 75% of the height
        }

        let topOffset = (bounds.height - height ) / 2
        
        documentLabel.frame.origin.y = topOffset - 20
    }
    
    // MARK: Misc
    fileprivate func adjustVideoPreviewLayerFrame() {
        videoOutput.connection(with: .video)?.videoOrientation = AVCaptureVideoOrientation(orientation: interfaceOrientation)
        videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation(orientation: interfaceOrientation)
        videoPreviewLayer.frame = bounds
        NSLayoutConstraint.activate([
            segmentedControl!.widthAnchor.constraint(equalToConstant: bounds.width * 0.6)
        ])
        recalculateLabelPosition()
    }
    
    fileprivate func preprocessImage(_ image: CGImage) -> CGImage {
        var inputImage = CIImage(cgImage: image)
        let averageLuminance = inputImage.averageLuminance
        var exposure = 0.5
        let threshold = (1 - pow(1 - averageLuminance, 0.2))
        
        if averageLuminance > 0.8 {
            exposure -= ((averageLuminance - 0.5) * 2)
        }
        
        if averageLuminance < 0.35 {
            exposure += pow(2, (0.5 - averageLuminance))
        }
        
        inputImage = inputImage.applyingFilter("CIExposureAdjust", parameters: ["inputEV": exposure])
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 2])
            .applyingFilter("LuminanceThresholdFilter", parameters: ["inputThreshold": threshold])
        
        return CIContext.shared.createCGImage(inputImage, from: inputImage.extent)!
    }
    
    internal final func setTorchMode(_ torchMode: String) {
        guard let device = videoDeviceInput?.device else {
          invokeOnError(.session(.cameraNotReady))
          return
        }
        guard var torchMode = AVCaptureDevice.TorchMode(withString: torchMode) else {
          invokeOnError(.parameter(.invalid(unionName: "TorchMode", receivedValue: torch)))
          return
        }
        if !captureSession.isRunning {
          torchMode = .off
        }
        if device.torchMode == torchMode {
          // no need to run the whole lock/unlock bs
          return
        }
        if !device.hasTorch || !device.isTorchAvailable {
          if torchMode == .off {
            // ignore it, when it's off and not supported, it's off.
            return
          } else {
            // torch mode is .auto or .on, but no torch is available.
            invokeOnError(.device(.torchUnavailable))
            return
          }
        }
        do {
          try device.lockForConfiguration()
          device.torchMode = torchMode
          if torchMode == .on {
            try device.setTorchModeOn(level: 1.0)
          }
          device.unlockForConfiguration()
        } catch let error as NSError {
          invokeOnError(.device(.configureError), cause: error)
          return
        }
      }
    
    // pragma MARK: Event Invokers
    internal final func invokeOnError(_ error: CameraError, cause: NSError? = nil) {
      ReactLogger.log(level: .error, message: "Invoking onError(): \(error.message)")
      guard let onError = onError else { return }

      var causeDictionary: [String: Any]?
      if let cause = cause {
        causeDictionary = [
          "code": cause.code,
          "domain": cause.domain,
          "message": cause.description,
          "details": cause.userInfo,
        ]
      }
      onError([
        "code": error.code,
        "message": error.message,
        "cause": causeDictionary ?? NSNull(),
      ])
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension MrzReaderView: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cgImage = CMSampleBufferGetImageBuffer(sampleBuffer)?.cgImage else {
            return
        }
        
        let documentImage = self.documentImage(from: cgImage)
        let imageRequestHandler = VNImageRequestHandler(cgImage: documentImage, options: [:])
        
        let detectTextRectangles = VNDetectTextRectanglesRequest { [unowned self] request, error in
            guard error == nil else {
                return
            }
            
            guard let results = request.results as? [VNTextObservation] else {
                return
            }
            
            let imageWidth = CGFloat(documentImage.width)
            let imageHeight = CGFloat(documentImage.height)
            let transform = CGAffineTransform.identity.scaledBy(x: imageWidth, y: -imageHeight).translatedBy(x: 0, y: -1)
            let mrzTextRectangles = results.map({ $0.boundingBox.applying(transform) }).filter({ $0.width > (imageWidth * 0.8) })
            let mrzRegionRect = mrzTextRectangles.reduce(into: CGRect.null, { $0 = $0.union($1) })
            
            guard mrzRegionRect.height <= (imageHeight * 0.4) else { // Avoid processing the full image (can occur if there is a long text in the header)
                return
            }
            
            if let mrzTextImage = documentImage.cropping(to: mrzRegionRect) {
                if let mrzResult = self.mrz(from: mrzTextImage), mrzResult.allCheckDigitsValid {
                    self.stopScanning()
                    
                    DispatchQueue.main.async {
                        let enlargedDocumentImage = self.enlargedDocumentImage(from: cgImage)
                        let scanResult = MRZScanResult(mrzResult: mrzResult, documentImage: enlargedDocumentImage)
                        let scanResultDictionary = scanResult.getMrzResultDictionary()
                        // Send result to jsi
                        guard self.onMrzResult != nil else { return }
                        self.onMrzResult!(scanResultDictionary)

                        if self.vibrateOnResult {
                            self.notificationFeedback.notificationOccurred(.success)
                        }
                    }
                }
            }
        }
        
        try? imageRequestHandler.perform([detectTextRectangles])
    }
}
