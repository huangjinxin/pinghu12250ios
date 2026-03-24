//
//  QRCameraView.swift
//  pinghu12250
//
//  AVFoundation 二维码相机
//

import SwiftUI
import AVFoundation

struct QRCameraView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?

    func makeUIViewController(context: Context) -> QRCameraViewController {
        let vc = QRCameraViewController()
        vc.onCodeScanned = { code in
            DispatchQueue.main.async { scannedCode = code }
        }
        return vc
    }

    func updateUIViewController(_ vc: QRCameraViewController, context: Context) {}
}

class QRCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        hasScanned = true
        onCodeScanned?(code)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }
}
