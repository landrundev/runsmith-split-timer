import SwiftUI
import AVFoundation

// MARK: – Public View

/// A full-screen QR code scanner presented as a SwiftUI view.
/// Wraps AVCaptureSession + AVCaptureMetadataOutput.
/// Calls `onScan` exactly once with the decoded string, then dismisses itself.
///
/// Usage:
///   .sheet(isPresented: $showScanner) {
///       QRScannerView { scannedString in
///           handleScan(scannedString)
///       }
///   }
struct QRScannerView: UIViewControllerRepresentable {

    /// Called on the main thread with the raw string content of the first scanned QR code.
    var onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

// MARK: – Coordinator

extension QRScannerView {

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {

        private let onScan: (String) -> Void
        private var hasScanned = false   // Prevent double-firing

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned else { return }

            guard
                let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                object.type == .qr,
                let stringValue = object.stringValue
            else { return }

            hasScanned = true

            DispatchQueue.main.async { [weak self] in
                self?.onScan(stringValue)
            }
        }
    }
}

// MARK: – UIViewController

final class ScannerViewController: UIViewController {

    weak var delegate: AVCaptureMetadataOutputObjectsDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermissionAndSetup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: Setup

    private func checkCameraPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async { self?.setupCaptureSession() }
                } else {
                    DispatchQueue.main.async { self?.showPermissionDeniedMessage() }
                }
            }
        default:
            showPermissionDeniedMessage()
        }
    }

    private func setupCaptureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showErrorMessage("No camera available on this device.")
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            showErrorMessage("Unable to access camera: \(error.localizedDescription)")
            return
        }

        guard session.canAddInput(videoInput) else {
            showErrorMessage("Cannot configure camera input.")
            return
        }
        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()

        guard session.canAddOutput(metadataOutput) else {
            showErrorMessage("Cannot configure metadata output.")
            return
        }
        session.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        addViewfinderOverlay()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    // MARK: Overlay

    private func addViewfinderOverlay() {
        let overlayView = UIView(frame: view.bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.backgroundColor = .clear

        let label = UILabel()
        label.text = "Align QR code in frame"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -60)
        ])

        view.addSubview(overlayView)
    }

    // MARK: Error States

    private func showPermissionDeniedMessage() {
        showErrorMessage("Camera access denied. Enable it in Settings → Privacy → Camera.")
    }

    private func showErrorMessage(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
