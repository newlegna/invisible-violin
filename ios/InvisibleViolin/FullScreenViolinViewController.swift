import UIKit

final class FullScreenViolinViewController: UIViewController {
    let cameraStage: StageView
    var onToggle: (() -> Void)?
    var onClose: (() -> Void)?
    private let noteLabel = UILabel()
    private let hintLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private var cameraConstraints: [NSLayoutConstraint] = []

    init(stage: StageView) {
        cameraStage = stage
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var prefersStatusBarHidden: Bool { true }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let exit = UIButton(type: .system)
        exit.configuration = .tinted()
        exit.configuration?.title = "Exit Full Screen"
        exit.configuration?.image = UIImage(systemName: "arrow.down.right.and.arrow.up.left")
        exit.configuration?.imagePadding = 8
        exit.tintColor = .systemYellow
        exit.addTarget(self, action: #selector(close), for: .touchUpInside)
        noteLabel.font = .monospacedSystemFont(ofSize: 21, weight: .semibold)
        noteLabel.numberOfLines = 0
        noteLabel.textAlignment = .center
        noteLabel.textColor = .white
        hintLabel.font = .preferredFont(forTextStyle: .subheadline)
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center
        hintLabel.textColor = .secondaryLabel
        playButton.configuration = .filled()
        playButton.configuration?.baseBackgroundColor = .systemYellow
        playButton.configuration?.baseForegroundColor = .black
        playButton.configuration?.cornerStyle = .capsule
        playButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 25, bottom: 15, trailing: 25)
        playButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        let footer = UIStackView(arrangedSubviews: [hintLabel, playButton])
        footer.axis = .vertical
        footer.spacing = 12
        let cameraArea = UIView()
        for child in [exit, noteLabel, cameraArea, footer] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        cameraStage.removeFromSuperview()
        cameraStage.layer.cornerRadius = 0
        cameraArea.addSubview(cameraStage)
        cameraStage.translatesAutoresizingMaskIntoConstraints = false
        let width = cameraStage.widthAnchor.constraint(equalTo: cameraArea.widthAnchor)
        width.priority = .defaultHigh
        cameraConstraints = [
            width,
            cameraStage.widthAnchor.constraint(lessThanOrEqualTo: cameraArea.widthAnchor),
            cameraStage.heightAnchor.constraint(lessThanOrEqualTo: cameraArea.heightAnchor),
            cameraStage.widthAnchor.constraint(equalTo: cameraStage.heightAnchor, multiplier: 0.75),
            cameraStage.centerXAnchor.constraint(equalTo: cameraArea.centerXAnchor),
            cameraStage.centerYAnchor.constraint(equalTo: cameraArea.centerYAnchor)
        ]
        NSLayoutConstraint.activate([
            exit.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            exit.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            noteLabel.topAnchor.constraint(equalTo: exit.bottomAnchor, constant: 16),
            noteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            noteLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            cameraArea.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 12),
            cameraArea.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraArea.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraArea.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -16),
            footer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            footer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ] + cameraConstraints)
    }
    func update(note: String, hint: String, playing: Bool) {
        noteLabel.text = note
        hintLabel.text = hint
        playButton.configuration?.title = playing ? "Pause" : "Start playing"
    }
    @objc private func toggle() { onToggle?() }
    @objc private func close() {
        NSLayoutConstraint.deactivate(cameraConstraints)
        cameraStage.removeFromSuperview()
        onClose?()
        dismiss(animated: true)
    }
}
