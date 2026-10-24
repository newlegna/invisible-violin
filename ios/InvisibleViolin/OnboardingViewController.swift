import UIKit

private final class MotionIllustration: UIView {
    var step = 0 { didSet { setNeedsDisplay() } }
    var bowOnLeft = true
    private var link: CADisplayLink?
    private var phase = 0.0
    private let gold = UIColor.systemYellow
    private let stringColors: [UIColor] = [.systemPink, .systemCyan, .systemYellow, .systemMint]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.08, alpha: 1)
        layer.cornerRadius = 24
        clipsToBounds = true
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        link?.invalidate()
        link = nil
        if window != nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
            displayLink.add(to: .main, forMode: .common)
            link = displayLink
        }
    }
    @objc private func tick(_ displayLink: CADisplayLink) {
        phase = UIAccessibility.isReduceMotionEnabled ? 0.8 : displayLink.timestamp.truncatingRemainder(dividingBy: 4) / 4
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        c.saveGState()
        c.scaleBy(x: bounds.width / 340, y: bounds.height / 285)
        let bowX: CGFloat = bowOnLeft ? 88 : 252
        let fingerX: CGFloat = bowOnLeft ? 252 : 88
        let position = min(3, Int(phase * 4))
        let pressed = phase > 0.48
        let rows: [CGFloat] = step == 1 ? [122, 154, 186, 218] : [90, 128, 166, 204]
        for i in 0..<4 {
            let active = step == 1 && i == position
            stringColors[i].withAlphaComponent(active ? 0.9 : 0.16).setStroke()
            let line = UIBezierPath()
            line.move(to: CGPoint(x: 16, y: rows[i]))
            line.addLine(to: CGPoint(x: 324, y: rows[i]))
            line.lineWidth = active ? 3 : 1
            line.stroke()
            if step == 1 { text(["E", "A", "D", "G"][i], x: 170, y: rows[i] - 18, color: stringColors[i], size: 15) }
        }
        text(bowOnLeft ? "BOW HAND" : "NOTE HAND", x: 85, y: 12, color: .white, size: 12)
        text(bowOnLeft ? "NOTE HAND" : "BOW HAND", x: 255, y: 12, color: .white, size: 12)
        let bowShift = step == 0 ? CGFloat(sin(phase * .pi * 2)) * 24 : 0
        let bowY = step == 1 ? rows[position] : 174
        hand(at: CGPoint(x: bowX + bowShift, y: bowY), indexDown: false, highlight: false, context: c)
        hand(at: CGPoint(x: fingerX, y: 202), indexDown: step == 2 && pressed, highlight: step == 2, context: c)
        if step == 0 {
            arrow(from: CGPoint(x: bowX - 51, y: 221), to: CGPoint(x: bowX + 51, y: 221), both: true)
            text("BOW SIDEWAYS", x: bowX, y: 244, color: gold, size: 11)
            text("KEEP FINGERS UP", x: fingerX, y: 244, color: .secondaryLabel, size: 10)
        } else if step == 1 {
            let arrowX: CGFloat = bowOnLeft ? 25 : 315
            arrow(from: CGPoint(x: arrowX, y: 80), to: CGPoint(x: arrowX, y: 207), both: true)
            text("HEIGHT = STRING", x: bowX, y: 244, color: gold, size: 11)
            text("HOLD YOUR NOTES", x: fingerX, y: 244, color: .secondaryLabel, size: 11)
        } else {
            text(pressed ? "D STRING · E" : "D STRING · D", x: 170, y: 57, color: gold, size: 17)
            text(pressed ? "1 DOWN" : "1 UP", x: fingerX, y: 244, color: gold, size: 12)
            text("KEEP BOWING", x: bowX, y: 244, color: .secondaryLabel, size: 11)
            arrow(from: CGPoint(x: fingerX - 43, y: 108), to: CGPoint(x: fingerX - 43, y: 145), both: false)
        }
        c.restoreGState()
    }
    private func hand(at wrist: CGPoint, indexDown: Bool, highlight: Bool, context: CGContext) {
        context.saveGState()
        context.translateBy(x: wrist.x, y: wrist.y)
        context.scaleBy(x: 0.74, y: 0.74)
        UIColor(white: 0.20, alpha: 1).setFill()
        UIColor(white: 0.85, alpha: 1).setStroke()
        let palm = UIBezierPath(roundedRect: CGRect(x: -31, y: -70, width: 62, height: 65), cornerRadius: 18)
        palm.lineWidth = 2; palm.fill(); palm.stroke()
        let wristLine = UIBezierPath()
        wristLine.move(to: CGPoint(x: -19, y: -10)); wristLine.addLine(to: CGPoint(x: -19, y: 13))
        wristLine.move(to: CGPoint(x: 19, y: -10)); wristLine.addLine(to: CGPoint(x: 19, y: 13))
        wristLine.lineWidth = 2; wristLine.stroke()
        for i in 0..<4 {
            let x = CGFloat(i) * 17 - 25
            let length: CGFloat = i == 0 && indexDown ? 17 : [49, 61, 53, 38][i]
            let finger = UIBezierPath(roundedRect: CGRect(x: x - 6, y: -64 - length, width: 12, height: length + 10), cornerRadius: 6)
            (i == 0 && highlight ? gold : UIColor(white: 0.85, alpha: 1)).setStroke()
            (i == 0 && highlight ? gold.withAlphaComponent(0.30) : UIColor(white: 0.15, alpha: 1)).setFill()
            finger.lineWidth = 2; finger.fill(); finger.stroke()
        }
        UIColor(white: 0.85, alpha: 1).setStroke()
        let thumb = UIBezierPath()
        thumb.move(to: CGPoint(x: -28, y: -24))
        thumb.addQuadCurve(to: CGPoint(x: -50, y: -53), controlPoint: CGPoint(x: -64, y: -43))
        thumb.addLine(to: CGPoint(x: -29, y: -43))
        thumb.lineWidth = 2; thumb.stroke()
        context.restoreGState()
    }
    private func text(_ value: String, x: CGFloat, y: CGFloat, color: UIColor, size: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: size, weight: .semibold), .foregroundColor: color]
        let width = (value as NSString).size(withAttributes: attributes).width
        (value as NSString).draw(at: CGPoint(x: x - width / 2, y: y), withAttributes: attributes)
    }
    private func arrow(from start: CGPoint, to end: CGPoint, both: Bool) {
        gold.setStroke()
        let line = UIBezierPath()
        line.move(to: start); line.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        func head(_ tip: CGPoint, _ theta: CGFloat) {
            for offset: CGFloat in [-0.55, 0.55] {
                line.move(to: tip)
                line.addLine(to: CGPoint(x: tip.x - cos(theta + offset) * 9, y: tip.y - sin(theta + offset) * 9))
            }
        }
        head(end, angle)
        if both { head(start, angle + .pi) }
        line.lineWidth = 3; line.lineCapStyle = .round; line.stroke()
    }
}

final class OnboardingViewController: UIViewController {
    static let completedKey = "onboarding.motionGuide.v1"
    private let illustration = MotionIllustration()
    private let heading = UILabel()
    private let body = UILabel()
    private let tip = UILabel()
    private let page = UIPageControl()
    private let nextButton = UIButton(type: .system)
    private let back = UIButton(type: .system)
    private var step = 0
    var bowOnLeft = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.035, green: 0.043, blue: 0.055, alpha: 1)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        let eyebrow = UILabel()
        eyebrow.text = "YOUR FIRST INVISIBLE MELODY"
        eyebrow.font = .preferredFont(forTextStyle: .caption1)
        eyebrow.textColor = .systemYellow
        eyebrow.numberOfLines = 0
        heading.font = .preferredFont(forTextStyle: .largeTitle)
        heading.numberOfLines = 0; heading.adjustsFontForContentSizeCategory = true
        body.font = .preferredFont(forTextStyle: .body)
        body.numberOfLines = 0; body.adjustsFontForContentSizeCategory = true
        tip.font = .preferredFont(forTextStyle: .subheadline)
        tip.textColor = .secondaryLabel; tip.numberOfLines = 0; tip.adjustsFontForContentSizeCategory = true
        illustration.bowOnLeft = bowOnLeft
        illustration.heightAnchor.constraint(equalTo: illustration.widthAnchor, multiplier: 285.0/340).isActive = true
        page.numberOfPages = 3
        page.currentPageIndicatorTintColor = .systemYellow
        page.addTarget(self, action: #selector(pageChanged), for: .valueChanged)
        nextButton.configuration = .filled()
        nextButton.configuration?.baseBackgroundColor = .systemYellow
        nextButton.configuration?.baseForegroundColor = .black
        nextButton.configuration?.cornerStyle = .capsule
        nextButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        nextButton.addTarget(self, action: #selector(nextStep), for: .touchUpInside)
        back.setTitle("Back", for: .normal)
        back.addTarget(self, action: #selector(previousStep), for: .touchUpInside)
        let skip = UIButton(type: .system)
        skip.setTitle("Skip guide", for: .normal)
        skip.addTarget(self, action: #selector(finish), for: .touchUpInside)
        let bottom = UIStackView(arrangedSubviews: [back, UIView(), skip])
        for item in [eyebrow, heading, illustration, body, tip, page, nextButton, bottom] { stack.addArrangedSubview(item) }
        renderStep()
    }
    private func renderStep() {
        let side = bowOnLeft ? "left" : "right"
        let other = bowOnLeft ? "right" : "left"
        let headings = ["Move to make music.", "Four strings. One hand.", "Bend a finger. Change a note."]
        let descriptions = [
            "Place your iPhone upright on a stand. Show both palms to the camera. Move the hand on the \(side) side of your screen sideways like a bow. Keep the other hand’s fingers raised to hear an open string.",
            "Keep bowing sideways. Raise or lower your bow hand to choose a string: E at the top, then A, D, and G. Watch the colored line light up in the camera view.",
            "On the \(other) side of your screen, gently bend your index finger toward your palm while you keep bowing. On the D string, index down plays E. Raise it again to return to D."
        ]
        let tips = [
            "Use good light, keep both hands fully visible and apart, and turn up your volume. You can swap bow hands on the playing screen.",
            "The bow’s height chooses the string. Sideways movement creates the sound. A still bow is quiet.",
            "Try D → E → F → G → A using open, index, middle, ring, and little finger. The highest held finger wins. If index is hard to detect, tap Set index finger up, hold it raised for two seconds, then adjust Index sensitivity."
        ]
        heading.text = headings[step]; body.text = descriptions[step]; tip.text = tips[step]
        illustration.step = step
        illustration.accessibilityLabel = descriptions[step]
        page.currentPage = step
        back.isHidden = step == 0
        nextButton.configuration?.title = step == 2 ? "Try my violin" : "Next"
        UIAccessibility.post(notification: .screenChanged, argument: heading)
    }
    @objc private func nextStep() { if step == 2 { finish() } else { step += 1; renderStep() } }
    @objc private func previousStep() { step = max(0, step - 1); renderStep() }
    @objc private func pageChanged() { step = page.currentPage; renderStep() }
    @objc private func finish() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        dismiss(animated: true)
    }
}
