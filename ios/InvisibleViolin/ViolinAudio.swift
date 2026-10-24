import AVFoundation

final class ViolinAudio {
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var dsp: OpaquePointer?
    private var lastFrequency: Float = 440

    func start() throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard rate > 0, let state = violin_create(rate),
              let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else {
            throw NSError(domain: "ViolinAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio output is unavailable."])
        }
        dsp = state
        let node = AVAudioSourceNode(format: format) { _, _, frames, list in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            if let data = buffers.first?.mData {
                violin_render(state, data.assumingMemoryBound(to: Float.self), frames)
            }
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        do { try engine.start() } catch { stop(); throw error }
    }

    func play(_ note: InstrumentNote?) {
        guard let dsp else { return }
        if let note { lastFrequency = Float(note.frequency) }
        // A lost hand should fade the current note, never retune the release to A4.
        violin_set(dsp, lastFrequency, Float(note?.amplitude ?? 0))
    }

    func stop() {
        if let dsp { violin_set(dsp, lastFrequency, 0) }
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
        if let dsp { violin_destroy(dsp) }
        dsp = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
