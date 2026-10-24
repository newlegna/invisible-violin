import AVFoundation
import MediaPipeTasksVision
import UIKit

final class CameraTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    var onHands: ((UUID, [TrackedHand]) -> Void)?
    var onError: ((UUID, String) -> Void)?
    var onReady: ((UUID) -> Void)?
    private let queue = DispatchQueue(label: "violin.camera", qos: .userInitiated)
    private var landmarker: HandLandmarker?
    private var runID: UUID?
    private var configured = false
    private var timestamp = 0

    func start(id: UUID) {
        queue.async { [self] in
            runID = id
            do {
                if landmarker == nil {
                    guard let path = Bundle.main.path(forResource: "hand_landmarker", ofType: "task") else {
                        throw failure("The hand-tracking model is missing from the app bundle.")
                    }
                    let options = HandLandmarkerOptions()
                    options.baseOptions.modelAssetPath = path
                    // Synchronous inference on the capture queue lets AVFoundation drop late frames.
                    // Nothing blocks the UI, and there is no growing queue of stale gestures.
                    options.runningMode = .video
                    options.numHands = 2
                    options.minHandDetectionConfidence = 0.6
                    options.minHandPresenceConfidence = 0.6
                    options.minTrackingConfidence = 0.6
                    landmarker = try HandLandmarker(options: options)
                }
                if !configured { try configure() }
                session.startRunning()
                guard session.isRunning else { throw failure("The camera could not start. Please try again.") }
                DispatchQueue.main.async { [weak self] in self?.onReady?(id) }
            } catch {
                runID = nil
                DispatchQueue.main.async { [weak self] in self?.onError?(id, error.localizedDescription) }
            }
        }
    }

    func stop() {
        queue.async { [self] in
            runID = nil
            if session.isRunning { session.stopRunning() }
        }
    }

    private func failure(_ text: String) -> NSError {
        NSError(domain: "CameraTracker", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .vga640x480
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw failure("A front camera is required. Run this app on an iPhone.")
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw failure("The camera is unavailable.") }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            throw failure("Camera frames are unavailable.")
        }
        session.addOutput(output)
        if let connection = output.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let id = runID, let landmarker else { return }
        do {
            timestamp = max(timestamp + 1, Int(ProcessInfo.processInfo.systemUptime * 1000))
            let image = try MPImage(sampleBuffer: buffer, orientation: .up)
            let result = try landmarker.detect(videoFrame: image, timestampInMilliseconds: timestamp)
            let hands = result.landmarks.enumerated().map { index, landmarks in
                let world = index < result.worldLandmarks.count ? result.worldLandmarks[index] : []
                return TrackedHand(
                    points: landmarks.map { HandPoint(x: 1 - Double($0.x), y: Double($0.y)) },
                    worldPoints: world.map { HandPoint(x: Double($0.x), y: Double($0.y), z: Double($0.z)) })
            }
            DispatchQueue.main.async { [weak self] in self?.onHands?(id, hands) }
        } catch {
            runID = nil
            DispatchQueue.main.async { [weak self] in self?.onError?(id, error.localizedDescription) }
        }
    }
}
