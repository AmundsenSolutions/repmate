import SwiftUI
import AVFoundation

/// Full-screen barcode scanner with a dark glass overlay.
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var onBarcodeScanned: (String) -> Void
    
    @State private var scannedCode: String?
    @State private var hasScanned = false
    @State private var scanLineOffset: CGFloat = -100
    @State private var cameraPermissionGranted = false
    @State private var showPermissionDenied = false
    
    var body: some View {
        ZStack {
            // Camera Feed
            #if targetEnvironment(simulator)
            Color.black.ignoresSafeArea()
            
            // Simulator Mock UI
            VStack(spacing: 20) {
                Text("Simulator Mode")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top, 100)
                
                Text("Camera not available")
                    .foregroundColor(.gray)
                
                Button("Simulate Scan (Whey Isolate)") {
                    handleScan("9999999999999") // Magic barcode for simulation
                }
                .padding()
                .background(themeManager.palette.accent)
                .foregroundColor(.black)
                .clipShape(Capsule())
            }
            .zIndex(1)
            #else
            if cameraPermissionGranted {
                CameraPreview(onBarcodeDetected: handleScan)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            #endif
            
            // Dark overlay with cutout
            GeometryReader { geo in
                let scanWidth = geo.size.width * 0.75
                let scanHeight: CGFloat = 200
                let scanRect = CGRect(
                    x: (geo.size.width - scanWidth) / 2,
                    y: (geo.size.height - scanHeight) / 2 - 40,
                    width: scanWidth,
                    height: scanHeight
                )
                
                // Dim overlay
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .ignoresSafeArea()
                    .reverseMask {
                        RoundedRectangle(cornerRadius: 16)
                            .frame(width: scanRect.width, height: scanRect.height)
                            .position(x: scanRect.midX, y: scanRect.midY)
                    }
                
                // Scan frame border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.palette.accent, lineWidth: 2)
                    .frame(width: scanRect.width, height: scanRect.height)
                    .position(x: scanRect.midX, y: scanRect.midY)
                
                // Corner accents
                ForEach(0..<4, id: \.self) { corner in
                    CornerAccent(corner: corner, color: themeManager.palette.accent)
                        .frame(width: scanRect.width, height: scanRect.height)
                        .position(x: scanRect.midX, y: scanRect.midY)
                }
                
                // Animated scan line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, themeManager.palette.accent.opacity(0.8), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: scanRect.width - 20, height: 2)
                    .position(x: scanRect.midX, y: scanRect.midY + scanLineOffset)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                        ) {
                            scanLineOffset = 100
                        }
                    }
            }
            
            // UI Elements
            VStack {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                
                Spacer()
                
                // Instruction text
                Text(hasScanned ? "Product found!" : "Point camera at a barcode")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 60)
            }
            
            // Permission denied overlay
            if showPermissionDenied {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Camera Access Required")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Enable camera in Settings to scan barcodes")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(themeManager.palette.accent)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                }
                .padding(40)
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    private func checkCameraPermission() {
        #if targetEnvironment(simulator)
        cameraPermissionGranted = true
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionGranted = granted
                    showPermissionDenied = !granted
                }
            }
        default:
            showPermissionDenied = true
        }
        #endif
    }
    
    private func handleScan(_ code: String) {
        guard !hasScanned else { return }
        hasScanned = true
        HapticManager.shared.success()
        onBarcodeScanned(code)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Camera Preview (UIKit Bridge)

#if !targetEnvironment(simulator)
struct CameraPreview: UIViewControllerRepresentable {
    var onBarcodeDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onBarcodeDetected = onBarcodeDetected
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeDetected: ((String) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        // Optimizing Autofocus for macro/barcode scanning speed
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near // Forces macro-focus priority
            }
            device.unlockForConfiguration()
        } catch {
            print("Failed to lock camera for autofocus optimization")
        }
        
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128]
        }
        
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        
        // Ensure omnidirectional scanning works regardless of physical device rotation
        if let connection = layer.connection {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90.0) {
                    connection.videoRotationAngle = 90.0
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
        
        view.layer.addSublayer(layer)
        self.previewLayer = layer
        
        // Maximize the rectOfInterest to scan anywhere on screen
        output.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }
        
        captureSession.stopRunning()
        onBarcodeDetected?(code)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}
#endif

// MARK: - Corner Accent Shape

struct CornerAccent: View {
    let corner: Int // 0=TL, 1=TR, 2=BL, 3=BR
    let color: Color
    private let length: CGFloat = 24
    private let thickness: CGFloat = 3
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                let r: CGFloat = 16 // match corner radius
                
                switch corner {
                case 0: // Top-left
                    path.move(to: CGPoint(x: 0, y: length))
                    path.addLine(to: CGPoint(x: 0, y: r))
                    path.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
                    path.addLine(to: CGPoint(x: length, y: 0))
                case 1: // Top-right
                    path.move(to: CGPoint(x: w - length, y: 0))
                    path.addLine(to: CGPoint(x: w - r, y: 0))
                    path.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: length))
                case 2: // Bottom-left
                    path.move(to: CGPoint(x: 0, y: h - length))
                    path.addLine(to: CGPoint(x: 0, y: h - r))
                    path.addQuadCurve(to: CGPoint(x: r, y: h), control: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: length, y: h))
                case 3: // Bottom-right
                    path.move(to: CGPoint(x: w - length, y: h))
                    path.addLine(to: CGPoint(x: w - r, y: h))
                    path.addQuadCurve(to: CGPoint(x: w, y: h - r), control: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - length))
                default: break
                }
            }
            .stroke(color, lineWidth: thickness)
        }
    }
}

// MARK: - Reverse Mask Helper

extension View {
    @ViewBuilder
    func reverseMask<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                content()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}
