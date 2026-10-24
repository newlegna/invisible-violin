import UIKit
import AVFoundation

private final class HandOverlay: UIView {
    weak var stage: StageView?
    override func draw(_ rect: CGRect) { stage?.drawHands(rect) }
}

final class StageView: UIView {
    let preview = AVCaptureVideoPreviewLayer()
    private let overlay = HandOverlay()
    var hands: [TrackedHand] = [] { didSet { overlay.setNeedsDisplay() } }
    var activeString = -1 { didSet { overlay.setNeedsDisplay() } }
    private let colors: [UIColor] = [.systemPink, .systemCyan, .systemYellow, .systemMint]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.07, alpha: 1)
        layer.cornerRadius = 24
        clipsToBounds = true
        preview.videoGravity = .resizeAspect
        preview.opacity = 0.45
        layer.addSublayer(preview)
        overlay.stage = self
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        addSubview(overlay)
        isAccessibilityElement = true
        accessibilityLabel = "Live camera and hand tracking"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        preview.frame = bounds
        overlay.frame = bounds
        if let connection = preview.connection {
            connection.videoOrientation = .portrait
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        overlay.setNeedsDisplay()
    }
    fileprivate func drawHands(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let points = [0.3, 0.45, 0.6, 0.75]
        for i in 0..<4 {
            let y = bounds.height * points[i]
            context.setStrokeColor(colors[i].withAlphaComponent(activeString == i ? 1 : 0.25).cgColor)
            context.setLineWidth(activeString == i ? 3 : 1)
            context.move(to: CGPoint(x: 12, y: y))
            context.addLine(to: CGPoint(x: bounds.width - 12, y: y))
            context.strokePath()
            (GestureInstrument.strings[i] as NSString).draw(at: CGPoint(x: 14, y: y - 24), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .semibold), .foregroundColor: colors[i]])
        }
        let edges = [[0,1,2,3,4], [0,5,6,7,8], [5,9,10,11,12], [9,13,14,15,16], [13,17,18,19,20], [0,17]]
        for hand in hands where hand.points.count == 21 {
            func point(_ i: Int) -> CGPoint {
                CGPoint(x: hand.points[i].x * bounds.width, y: hand.points[i].y * bounds.height)
            }
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(2)
            for edge in edges {
                context.move(to: point(edge[0]))
                for i in edge.dropFirst() { context.addLine(to: point(i)) }
                context.strokePath()
            }
            context.setFillColor(UIColor.systemYellow.cgColor)
            for i in [0, 4, 8, 12, 16, 20] {
                let p = point(i)
                context.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
            }
        }
    }
}

final class ViolinViewController: UIViewController {
    private let tracker = CameraTracker()
    private let audio = ViolinAudio()
    private var instrument = GestureInstrument()
    private var runID: UUID?
    private let stage = StageView()
    private let stageHolder = UIView()
    private var stageConstraints: [NSLayoutConstraint] = []
    private weak var fullScreen: FullScreenViolinViewController?
    private let status = UILabel()
    private let note = UILabel()
    private let fingering = UILabel()
    private let instructions = UILabel()
    private let start = UIButton(type: .system)
    private let swap = UIButton(type: .system)
    private let calibrateIndex = UIButton(type: .system)
    private let indexMeter = UIProgressView(progressViewStyle: .default)
    private var fingerIndicators: [UILabel] = []
    private var indexCalibrationRequested = false
    private var indexCalibrationSince: Double?
    private var observers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.035, green: 0.043, blue: 0.055, alpha: 1)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        let eyebrow = label("PLAY SOMETHING INVISIBLE", style: .caption1, color: .systemYellow)
        let title = label("Invisible Violin", style: .largeTitle)
        status.text = "Your hands. Four strings."
        status.font = .preferredFont(forTextStyle: .subheadline)
        status.textColor = .secondaryLabel
        status.numberOfLines = 0
        note.text = "NATURAL NOTES · READY"
        note.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
        note.textAlignment = .center
        fingering.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        fingering.textColor = .secondaryLabel
        fingering.textAlignment = .center
        fingering.numberOfLines = 0
        fingering.text = "Open → 1 → 2 → 3 → 4\nD → E → F → G → A"
        instructions.font = .preferredFont(forTextStyle: .subheadline)
        instructions.numberOfLines = 0
        instructions.textColor = .secondaryLabel
        updateInstructions()
        var config = UIButton.Configuration.filled()
        config.title = "Start playing"
        config.baseBackgroundColor = .systemYellow
        config.baseForegroundColor = .black
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        start.configuration = config
        start.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        swap.setTitle("Swap bow hand", for: .normal)
        swap.tintColor = .systemYellow
        swap.addTarget(self, action: #selector(swapHands), for: .touchUpInside)
        let fingerRow = UIStackView()
        fingerRow.axis = .horizontal
        fingerRow.distribution = .fillEqually
        fingerRow.spacing = 8
        for i in 1...4 {
            let indicator = label("\(i) —", style: .caption1, color: .secondaryLabel)
            indicator.textAlignment = .center
            indicator.backgroundColor = UIColor(white: 0.12, alpha: 1)
            indicator.layer.cornerRadius = 8
            indicator.clipsToBounds = true
            indicator.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
            fingerIndicators.append(indicator)
            fingerRow.addArrangedSubview(indicator)
        }
        indexMeter.progressTintColor = .systemYellow
        indexMeter.accessibilityLabel = "Index finger bend"
        let sensitivity = UISlider()
        sensitivity.minimumValue = 0
        sensitivity.maximumValue = 1
        sensitivity.value = Float(instrument.indexSensitivity)
        sensitivity.tintColor = .systemYellow
        sensitivity.accessibilityLabel = "Index sensitivity. Higher requires less movement."
        sensitivity.addTarget(self, action: #selector(indexSensitivityChanged(_:)), for: .valueChanged)
        let sensitivityRow = UIStackView(arrangedSubviews: [label("Index sensitivity", style: .caption1), sensitivity])
        sensitivityRow.axis = .horizontal
        sensitivityRow.spacing = 16
        calibrateIndex.setTitle("Set index finger up", for: .normal)
        calibrateIndex.tintColor = .systemYellow
        calibrateIndex.isEnabled = false
        calibrateIndex.addTarget(self, action: #selector(calibrateRaisedIndex), for: .touchUpInside)
        let privacyButton = UIButton(type: .system)
        privacyButton.setTitle("Privacy", for: .normal)
        privacyButton.addTarget(self, action: #selector(showPrivacy), for: .touchUpInside)
        let help = UIButton(type: .system)
        help.setTitle("How to play · Motion guide", for: .normal)
        help.tintColor = .systemYellow
        help.addTarget(self, action: #selector(showMotionGuide), for: .touchUpInside)
        let privacy = label("Camera processing stays on your phone.\nSynthesized string sound · No microphone needed", style: .caption2, color: .tertiaryLabel)
        privacy.textAlignment = .center
        let expand = UIButton(type: .system)
        expand.configuration = .tinted()
        expand.configuration?.title = "Full Screen"
        expand.configuration?.image = UIImage(systemName: "arrow.up.left.and.arrow.down.right")
        expand.configuration?.imagePadding = 8
        expand.tintColor = .systemYellow
        expand.addTarget(self, action: #selector(showFullScreen), for: .touchUpInside)
        stage.translatesAutoresizingMaskIntoConstraints = false
        stageHolder.addSubview(stage)
        for item in [eyebrow, title, help, status, expand, stageHolder, fingerRow, indexMeter, note, fingering, start,
                     sensitivityRow, calibrateIndex, instructions, swap, privacy, privacyButton] { stack.addArrangedSubview(item) }
        stageHolder.heightAnchor.constraint(equalToConstant: min((view.bounds.width - 48) * 4 / 3, view.bounds.height * 0.4)).isActive = true
        stageConstraints = [
            stage.heightAnchor.constraint(equalTo: stageHolder.heightAnchor),
            stage.widthAnchor.constraint(equalTo: stage.heightAnchor, multiplier: 0.75),
            stage.centerXAnchor.constraint(equalTo: stageHolder.centerXAnchor),
            stage.centerYAnchor.constraint(equalTo: stageHolder.centerYAnchor)
        ]
        NSLayoutConstraint.activate(stageConstraints)
        stage.preview.session = tracker.session
        tracker.onReady = { [weak self] id in
            guard let self, self.runID == id else { return }
            self.status.text = "Show both hands, then move your bow sideways."
            self.stage.setNeedsLayout()
            self.updateFullScreen()
        }
        tracker.onHands = { [weak self] id, hands in
            guard let self, self.runID == id else { return }
            self.stage.hands = hands
            let sound = self.instrument.update(hands: hands, time: ProcessInfo.processInfo.systemUptime)
            let calibrating = self.advanceIndexCalibration(tracking: sound != nil)
            self.updateFingerFeedback(tracking: sound != nil)
            self.audio.play(calibrating ? nil : sound)
            self.stage.activeString = sound?.stringIndex ?? -1
            self.note.text = sound.map { "\(GestureInstrument.strings[$0.stringIndex]) · \($0.label) · \($0.finger == 0 ? "OPEN" : "FINGER \($0.finger)")" } ?? "SHOW BOTH HANDS"
            if let sound {
                let names = GestureInstrument.notes[sound.stringIndex].map {
                    InstrumentNote(midi: $0, stringIndex: sound.stringIndex, amplitude: 0).label
                }
                self.fingering.text = "Open → 1 → 2 → 3 → 4\n" + names.joined(separator: " → ")
            }
            self.status.text = sound == nil ? "Keep both hands visible and apart." : "Raise or lower your bow hand to change strings."
            self.updateFullScreen()
        }
        tracker.onError = { [weak self] id, message in
            guard let self, self.runID == id else { return }
            self.stopPlaying(message: message)
        }
        for name in [UIApplication.willResignActiveNotification, AVAudioSession.interruptionNotification,
                     AVAudioSession.mediaServicesWereResetNotification,
                     AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.runID != nil else { return }
                self.stopPlaying(message: "Paused. Tap Start playing when you’re ready.")
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self, self.runID != nil,
                  let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                  reason == .oldDeviceUnavailable || reason == .newDeviceAvailable else { return }
            self.stopPlaying(message: "Audio output changed. Tap Start playing to continue.")
        })

    }

    private func label(_ text: String, style: UIFont.TextStyle, color: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !UserDefaults.standard.bool(forKey: OnboardingViewController.completedKey), presentedViewController == nil {
            showMotionGuide()
        }
    }

    @objc private func showMotionGuide() {
        guard presentedViewController == nil else { return }
        if runID != nil { stopPlaying(message: "Paused while you learn the motions.") }
        let guide = OnboardingViewController()
        guide.bowOnLeft = instrument.bowOnScreenLeft
        guide.modalPresentationStyle = .fullScreen
        present(guide, animated: true)
    }

    @objc private func toggle() {
        if runID != nil { stopPlaying(message: "Paused. Pick up where you left off."); return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: beginPlaying()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard UIApplication.shared.applicationState == .active else { return }
                    if granted { self?.beginPlaying() } else { self?.cameraDenied() }
                }
            }
        default: cameraDenied()
        }
    }

    private func beginPlaying() {
        do {
            try audio.start()
            let id = UUID()
            runID = id
            calibrateIndex.isEnabled = true
            instrument.reset()
        cancelIndexCalibration()
        updateFingerFeedback(tracking: false)
            UIApplication.shared.isIdleTimerDisabled = true
            status.text = "Preparing your violin…"
            start.configuration?.title = "Pause"
            tracker.start(id: id)
            updateFullScreen()
        } catch { stopPlaying(message: error.localizedDescription) }
    }

    private func stopPlaying(message: String) {
        runID = nil
        audio.stop()
        tracker.stop()
        instrument.reset()
        stage.hands = []
        stage.activeString = -1
        note.text = "NATURAL NOTES · READY"
        start.configuration?.title = "Start playing"
        status.text = message
        UIApplication.shared.isIdleTimerDisabled = false
        updateFullScreen()
    }

    @objc private func showFullScreen() {
        guard presentedViewController == nil else { return }
        NSLayoutConstraint.deactivate(stageConstraints)
        let screen = FullScreenViolinViewController(stage: stage)
        screen.onToggle = { [weak self] in self?.toggle() }
        screen.onClose = { [weak self] in
            guard let self else { return }
            self.fullScreen = nil
            self.stage.layer.cornerRadius = 24
            self.stageHolder.addSubview(self.stage)
            NSLayoutConstraint.activate(self.stageConstraints)
            self.stage.setNeedsLayout()
        }
        fullScreen = screen
        screen.loadViewIfNeeded()
        updateFullScreen()
        present(screen, animated: true)
    }

    private func updateFullScreen() {
        fullScreen?.update(note: note.text ?? "", hint: status.text ?? "", playing: runID != nil)
    }

    @objc private func showPrivacy() {
        let alert = UIAlertController(title: "Your privacy", message:
            "Camera images and hand positions are processed on your device. The app does not record or upload them, use your microphone, or include ads or analytics. Your motion-guide preference stays on your device. Your app purchase is handled by Apple; we do not receive your payment card details.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        alert.addAction(UIAlertAction(title: "Full privacy policy", style: .default) { _ in
            if let url = URL(string: "https://newlegna.github.io/invisible-violin/ios-privacy.html") {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }

    @objc private func swapHands() {
        instrument.bowOnScreenLeft.toggle()
        instrument.clearIndexCalibration()
        cancelIndexCalibration()
        updateFingerFeedback(tracking: false)
        audio.play(nil)
        updateInstructions()
    }

    private func updateInstructions() {
        let side = instrument.bowOnScreenLeft ? "left" : "right"
        instructions.text = "Screen \(side): bow sideways; height selects the string.\nKeep your fingering palm, index knuckles and fingertip visible.\nTap Set index finger up, then show both hands and hold the index up for two seconds. Lower it and watch 1 change to DOWN. Raise the other fingers when testing finger 1."
    }

    private func updateFingerFeedback(tracking: Bool) {
        for (i, label) in fingerIndicators.enumerated() {
            let down = tracking && instrument.fingersDown[i]
            label.text = "\(i + 1) \(tracking ? (down ? "DOWN" : "UP") : "—")"
            label.textColor = down ? .black : .secondaryLabel
            label.backgroundColor = down ? .systemYellow : UIColor(white: 0.12, alpha: 1)
        }
        indexMeter.progress = Float(instrument.indexPressAmount ?? 0)
        calibrateIndex.isEnabled = runID != nil && !indexCalibrationRequested
    }

    @objc private func calibrateRaisedIndex() {
        guard runID != nil else { return }
        indexCalibrationRequested = true
        indexCalibrationSince = nil
        audio.play(nil)
        calibrateIndex.setTitle("Show both hands · hold index up", for: .normal)
        calibrateIndex.isEnabled = false
    }

    private func advanceIndexCalibration(tracking: Bool) -> Bool {
        guard indexCalibrationRequested else { return false }
        guard tracking else {
            indexCalibrationSince = nil
            calibrateIndex.setTitle("Show both hands · hold index up", for: .normal)
            return true
        }
        let now = ProcessInfo.processInfo.systemUptime
        if indexCalibrationSince == nil { indexCalibrationSince = now }
        if now - (indexCalibrationSince ?? now) >= 2, instrument.calibrateIndexUp() {
            indexCalibrationRequested = false
            indexCalibrationSince = nil
            calibrateIndex.setTitle("Index calibrated ✓ · Set again", for: .normal)
        } else {
            calibrateIndex.setTitle("Hold index up…", for: .normal)
        }
        return true
    }

    private func cancelIndexCalibration() {
        indexCalibrationRequested = false
        indexCalibrationSince = nil
        calibrateIndex.setTitle("Set index finger up", for: .normal)
    }

    @objc private func indexSensitivityChanged(_ slider: UISlider) {
        instrument.indexSensitivity = Double(slider.value)
    }

    private func cameraDenied() {
        let alert = UIAlertController(title: "Camera access needed", message: "Enable Camera in Settings so your hands can play the violin.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        })
        (fullScreen ?? self).present(alert, animated: true)
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}
