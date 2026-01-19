import AVFoundation
import SwiftUI

struct ScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    private var didSendCode = false
    private let focusLayer = CAShapeLayer()
    private let dimLayer = CAShapeLayer()
    private let focusCornerRadius: CGFloat = 16

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
        configureOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateFocusOverlay()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        captureDevice = device
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.sessionPreset = .high
        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        session.startRunning()
    }

    private func configureOverlay() {
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.45).cgColor
        dimLayer.fillRule = .evenOdd
        focusLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        focusLayer.lineWidth = 2
        focusLayer.fillColor = UIColor.clear.cgColor
        focusLayer.lineJoin = .round
        focusLayer.lineCap = .round

        view.layer.addSublayer(dimLayer)
        view.layer.addSublayer(focusLayer)
    }

    private func updateFocusOverlay() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let rect = focusRect(in: view.bounds)
        dimLayer.frame = view.bounds
        focusLayer.frame = view.bounds

        let cutoutPath = UIBezierPath(rect: view.bounds)
        cutoutPath.append(UIBezierPath(roundedRect: rect, cornerRadius: focusCornerRadius))
        dimLayer.path = cutoutPath.cgPath
        focusLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: focusCornerRadius).cgPath

        if let previewLayer {
            metadataOutput.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: rect)
            updateFocusPoint(rect, previewLayer: previewLayer)
        }
    }

    private func updateFocusPoint(_ rect: CGRect, previewLayer: AVCaptureVideoPreviewLayer) {
        guard let device = captureDevice else { return }
        let layerPoint = CGPoint(x: rect.midX, y: rect.midY)
        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            device.unlockForConfiguration()
        } catch {
            device.unlockForConfiguration()
        }
    }

    private func focusRect(in bounds: CGRect) -> CGRect {
        let maxWidth = min(bounds.width * 0.78, 320)
        let height = maxWidth * 0.42
        let originX = (bounds.width - maxWidth) / 2
        let originY = (bounds.height - height) / 2
        return CGRect(x: originX, y: originY, width: maxWidth, height: height).integral
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didSendCode else { return }
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue else { return }

        didSendCode = true
        session.stopRunning()
        onCode?(code)
    }
}
