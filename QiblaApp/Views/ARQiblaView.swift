import SwiftUI
import AVFoundation
import CoreMotion
import CoreLocation

// MARK: - ARQiblaView

/// High-precision Augmented Reality Qibla Finder.
/// Overlays a live camera feed with a 3D-positioned Kaaba shrine,
/// directional guidance radar, holy light beam, and spirit-level reticle.
struct ARQiblaView: View {
    @Environment(AppState.self) private var appState
    var onDismiss: (() -> Void)? = nil

    private var lm: LocationManager { appState.locationManager }
    private var bearing: Double { appState.qiblaInfo?.bearing ?? 0 }
    private var distance: Double { appState.qiblaInfo?.distanceKm ?? 0 }
    private var heading: Double { lm.compassHeading }

    @State private var motion = ARMotionObserver()
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isTorchOn: Bool = false
    @State private var hasFiredHapticForLock: Bool = false

    /// Angle between camera facing direction and Qibla (-180...180)
    private var deltaHeading: Double {
        normalised(bearing - heading)
    }

    /// Whether the user is pointing straight at the Qibla
    private var isAligned: Bool {
        abs(deltaHeading) < 3.5 && abs(motion.pitchDegrees) < 18
    }

    /// Whether the Kaaba target is within the camera's horizontal FOV (~60°)
    private var isInView: Bool {
        abs(deltaHeading) <= 30
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                // ── 1. Live Camera Feed ──────────────────────────────────
                if cameraPermission == .authorized {
                    ARCameraFeedView()
                        .ignoresSafeArea()
                } else if cameraPermission == .notDetermined {
                    requestingCameraView
                } else {
                    cameraDeniedView
                }

                // ── 2. Atmospheric & Vignette Overlays ───────────────────
                VignetteOverlay(isAligned: isAligned)
                    .ignoresSafeArea()

                // ── 3. Central Reticle & Spirit Level ────────────────────
                CenterReticle(
                    isAligned: isAligned,
                    rollDegrees: motion.rollDegrees,
                    pitchDegrees: motion.pitchDegrees
                )
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                // ── 4. Floating 3D Kaaba Shrine Target ───────────────────
                if isInView {
                    floatingKaabaTarget(in: proxy.size)
                }

                // ── 5. Off-Screen Directional Guides ─────────────────────
                if !isInView {
                    offScreenGuide(in: proxy.size)
                }

                // ── 6. Top Header HUD ────────────────────────────────────
                VStack {
                    topBarHUD
                    Spacer()
                    bottomHUD(in: proxy.size)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            motion.start()
            checkCameraPermission()
        }
        .onDisappear {
            motion.stop()
            setTorch(false)
        }
        .onChange(of: isAligned) { _, newValue in
            if newValue && !hasFiredHapticForLock {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                hasFiredHapticForLock = true
            } else if !newValue {
                hasFiredHapticForLock = false
            }
        }
    }

    // MARK: - Subviews

    private var topBarHUD: some View {
        HStack {
            // Close / Switch Back to Compass
            Button {
                onDismiss?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "safari.fill")
                        .font(.body)
                    Text("البوصلة")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(AppPalette.gold.opacity(0.4), lineWidth: 1))
                .foregroundStyle(AppPalette.goldLight)
            }

            Spacer()

            // Flashlight Toggle
            if AVCaptureDevice.default(for: .video)?.hasTorch == true {
                Button {
                    toggleTorch()
                } label: {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.body)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(isTorchOn ? AppPalette.gold : Color.white.opacity(0.2), lineWidth: 1))
                        .foregroundStyle(isTorchOn ? AppPalette.gold : Color.white)
                }
            }
        }
    }

    private func bottomHUD(in size: CGSize) -> some View {
        VStack(spacing: 14) {
            // Status banner
            HStack(spacing: 8) {
                Image(systemName: isAligned ? "checkmark.seal.fill" : "camera.viewfinder")
                    .font(.headline)
                    .foregroundStyle(isAligned ? AppPalette.emeraldLight : AppPalette.gold)

                Text(statusMessage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isAligned ? AppPalette.emeraldLight : Color.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                isAligned
                    ? AnyShapeStyle(AppPalette.heroCardGradient)
                    : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    isAligned ? AppPalette.emeraldLight : AppPalette.cardBorder,
                    lineWidth: 1
                )
            )
            .shadow(color: isAligned ? AppPalette.green.opacity(0.4) : .clear, radius: 10)

            // Info & Mini Radar Card
            HStack(spacing: 16) {
                // Degrees & Distance
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(Int(bearing.rounded()))°")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppPalette.goldLight)

                        Text("زاوية القبلة")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if distance > 0 {
                        Text(formattedDistance)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppPalette.gold.opacity(0.9))
                    }
                }

                Spacer()

                // Mini 360° Radar
                MiniRadarView(
                    currentHeading: heading,
                    qiblaBearing: bearing
                )
                .frame(width: 52, height: 52)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.cardBorder, lineWidth: 1)
            )
        }
    }

    private var statusMessage: String {
        if isAligned {
            return "أنت تواجه القبلة المشرفة الآن تماماً! 🕋"
        } else if isInView {
            return "القبلة أمامك مباشرة — اضبط المحاذاة مع الدائرة"
        } else if deltaHeading > 0 {
            return "استدر يميناً نحو القبلة (\(Int(abs(deltaHeading)))°)"
        } else {
            return "استدر يساراً نحو القبلة (\(Int(abs(deltaHeading)))°)"
        }
    }

    // MARK: - Floating Kaaba 3D Target

    private func floatingKaabaTarget(in size: CGSize) -> some View {
        // Horizontal projection: -30° -> 10% width, 0° -> 50% width, +30° -> 90% width
        let screenCenterX = size.width / 2
        let fovSpan = 30.0
        let xOffset = CGFloat(deltaHeading / fovSpan) * (size.width * 0.42)
        let targetX = screenCenterX + xOffset

        // Vertical projection based on phone pitch
        let screenCenterY = size.height / 2
        let yOffset = CGFloat(motion.pitchDegrees * 6.5)
        let targetY = max(160, min(size.height - 200, screenCenterY + yOffset - 40))

        return ZStack {
            // Divine Light Beam rising to the sky
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppPalette.gold.opacity(isAligned ? 0.9 : 0.4),
                            AppPalette.goldLight.opacity(isAligned ? 0.6 : 0.2),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: isAligned ? 6 : 3, height: 350)
                .offset(y: -175)
                .blur(radius: isAligned ? 2 : 1)

            // Outer Pulsing Halo
            Circle()
                .stroke(
                    isAligned ? AppPalette.emeraldLight : AppPalette.gold,
                    lineWidth: isAligned ? 3 : 1.5
                )
                .frame(width: 88, height: 88)
                .scaleEffect(isAligned ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAligned)

            Circle()
                .fill((isAligned ? AppPalette.green : AppPalette.gold).opacity(0.18))
                .frame(width: 80, height: 80)
                .blur(radius: 6)

            // Kaaba Icon
            KaabaIcon(size: 38)
                .shadow(color: isAligned ? AppPalette.emeraldLight : AppPalette.gold, radius: 14)

            // Info Tag Floating Under Kaaba
            VStack(spacing: 2) {
                Text("مكة المكرمة")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.white)

                Text("\(Int(distance)) كم")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppPalette.goldLight)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.65), in: Capsule())
            .overlay(Capsule().stroke(AppPalette.gold.opacity(0.6), lineWidth: 0.8))
            .offset(y: 44)
        }
        .position(x: targetX, y: targetY)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: targetX)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: targetY)
    }

    // MARK: - Off-Screen Directional Guides

    private func offScreenGuide(in size: CGSize) -> some View {
        let isRight = deltaHeading > 0
        let degreesAway = Int(abs(deltaHeading))

        return HStack {
            if isRight {
                Spacer()
            }

            VStack(spacing: 8) {
                Image(systemName: isRight ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(AppPalette.goldLight)
                    .shadow(color: AppPalette.gold, radius: 8)

                Text(isRight ? "استدر يميناً" : "استدر يساراً")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white)

                Text("\(degreesAway)°")
                    .font(.headline.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.gold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.gold.opacity(0.6), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            if !isRight {
                Spacer()
            }
        }
    }

    // MARK: - Camera Permissions & Fallbacks

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermission = .authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        default:
            cameraPermission = .denied
        }
    }

    private var requestingCameraView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppPalette.gold)
            Text("جاري تشغيل الكاميرا…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var cameraDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 54))
                .foregroundStyle(AppPalette.gold)

            Text("إذن الكاميرا مطلوب لعرض الواقع المعزز")
                .font(.headline)
                .foregroundStyle(.white)

            Text("يرجى تفعيل إذن الكاميرا في الإعدادات لتتمكن من رؤية الكعبة الشريفة وشعاع القبلة في غرفتك مباشرة.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 32)

            Button("فتح الإعدادات") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.green)
        }
    }

    // MARK: - Torch & Helpers

    private func toggleTorch() {
        setTorch(!isTorchOn)
    }

    private func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        isTorchOn = on
    }

    private func normalised(_ a: Double) -> Double {
        var r = a.truncatingRemainder(dividingBy: 360)
        if r >  180 { r -= 360 }
        if r < -180 { r += 360 }
        return r
    }

    private var formattedDistance: String {
        let fmt = NumberFormatter()
        fmt.locale = Locale(identifier: "ar")
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        let s = fmt.string(from: NSNumber(value: distance)) ?? "\(Int(distance))"
        return "تبعد \(s) كم عن موقعك"
    }
}

// MARK: - Center Reticle & Spirit Level

private struct CenterReticle: View {
    let isAligned: Bool
    let rollDegrees: Double
    let pitchDegrees: Double

    var body: some View {
        ZStack {
            // Crosshair lines
            Rectangle()
                .fill((isAligned ? AppPalette.emeraldLight : AppPalette.gold).opacity(0.4))
                .frame(width: 80, height: 1)

            Rectangle()
                .fill((isAligned ? AppPalette.emeraldLight : AppPalette.gold).opacity(0.4))
                .frame(width: 1, height: 80)

            // Outer target circle
            Circle()
                .stroke(
                    isAligned ? AppPalette.emeraldLight : Color.white.opacity(0.3),
                    lineWidth: isAligned ? 2.5 : 1.2
                )
                .frame(width: 64, height: 64)

            // Center spirit bubble representing phone levelness
            Circle()
                .fill(isAligned ? AppPalette.emeraldLight : AppPalette.gold)
                .frame(width: 10, height: 10)
                .offset(
                    x: CGFloat(max(-22, min(22, rollDegrees * 1.5))),
                    y: CGFloat(max(-22, min(22, pitchDegrees * 1.5)))
                )
                .animation(.interactiveSpring(response: 0.15), value: rollDegrees)
                .animation(.interactiveSpring(response: 0.15), value: pitchDegrees)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Vignette & Atmosphere

private struct VignetteOverlay: View {
    let isAligned: Bool

    var body: some View {
        RadialGradient(
            colors: [
                .clear,
                (isAligned ? AppPalette.green : Color.black).opacity(isAligned ? 0.35 : 0.5)
            ],
            center: .center,
            startRadius: 120,
            endRadius: 400
        )
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.4), value: isAligned)
    }
}

// MARK: - Mini Radar View

private struct MiniRadarView: View {
    let currentHeading: Double
    let qiblaBearing: Double

    private var relativeAngle: Double {
        var r = (qiblaBearing - currentHeading).truncatingRemainder(dividingBy: 360)
        if r > 180 { r -= 360 }
        if r < -180 { r += 360 }
        return r
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.4))
                .overlay(Circle().stroke(AppPalette.gold.opacity(0.3), lineWidth: 1))

            // Field of view wedge
            Path { path in
                path.move(to: CGPoint(x: 26, y: 26))
                path.addArc(
                    center: CGPoint(x: 26, y: 26),
                    radius: 24,
                    startAngle: .degrees(-120),
                    endAngle: .degrees(-60),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(AppPalette.green.opacity(0.25))

            // Phone facing pointer (straight up)
            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(AppPalette.goldLight)
                .offset(y: -16)

            // Qibla dot on radar perimeter
            Circle()
                .fill(AppPalette.gold)
                .frame(width: 8, height: 8)
                .shadow(color: AppPalette.gold, radius: 4)
                .offset(y: -20)
                .rotationEffect(.degrees(relativeAngle))
                .animation(.interactiveSpring(response: 0.2), value: relativeAngle)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - AR Motion Observer

@Observable
final class ARMotionObserver {
    var pitchDegrees: Double = 0
    var rollDegrees: Double = 0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let g = motion.gravity
            // Pitch: upright portrait facing horizon is ~ 0°
            self.pitchDegrees = atan2(-g.z, -g.y) * 180.0 / .pi
            // Roll: side tilt
            self.rollDegrees = atan2(g.x, sqrt(g.y * g.y + g.z * g.z)) * 180.0 / .pi
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Camera Service & Preview

private final class CameraService: @unchecked Sendable {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "qibla.ar.camera.queue")

    func setupAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: camera),
               self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
}

private struct ARCameraFeedView: UIViewRepresentable {
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.startSession()
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}

    static func dismantleUIView(_ uiView: CameraPreviewUIView, coordinator: ()) {
        uiView.stopSession()
    }
}

private final class CameraPreviewUIView: UIView {
    private let cameraService = CameraService()
    private let previewLayer: AVCaptureVideoPreviewLayer

    override init(frame: CGRect) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.session)
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    func startSession() {
        cameraService.setupAndStart()
    }

    func stopSession() {
        cameraService.stop()
    }
}
