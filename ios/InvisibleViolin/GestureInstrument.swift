import Foundation

struct HandPoint {
    let x: Double
    let y: Double
    var z: Double = 0
}

struct TrackedHand {
    let points: [HandPoint]
    let worldPoints: [HandPoint]
    init(points: [HandPoint], worldPoints: [HandPoint] = []) {
        self.points = points
        self.worldPoints = worldPoints
    }
}

struct InstrumentNote {
    let midi: Int
    let stringIndex: Int
    let amplitude: Double
    var finger: Int { GestureInstrument.notes[stringIndex].firstIndex(of: midi) ?? 0 }
    var frequency: Double { 440 * pow(2, Double(midi - 69) / 12) }
    var label: String {
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        return "\(names[midi % 12])\(midi / 12 - 1)"
    }
}

/// Coordinates are portrait, mirrored, and normalized to the camera image.
/// Roles use screen position, avoiding model handedness/mirroring ambiguity.
struct GestureInstrument {
    static let strings = ["E", "A", "D", "G"]
    // Requested natural-note fingering: open string, index, middle, ring, little.
    // E: E F G A B; A: A B C D E; D: D E F G A; G: G A B C D.
    // Whole/half steps follow the notes, not equal pitch increments per finger.
    static let notes = [[76, 77, 79, 81, 83], [69, 71, 72, 74, 76],
                        [62, 64, 65, 67, 69], [55, 57, 59, 60, 62]]
    var bowOnScreenLeft = true
    private(set) var stringIndex = 1
    private var previous: (x: Double, time: Double)?
    private var speed = 0.0
    private var bent = [false, false, false, false]
    var fingersDown: [Bool] { bent }
    var indexSensitivity = 0.6
    private(set) var indexPressAmount: Double?
    private var indexRest: (middle: Double, base: Double)?
    private var indexHistory: [(middle: Double, base: Double)] = []
    var canCalibrateIndex: Bool { indexHistory.count >= 3 }
    private struct Selection: Equatable {
        let string: Int
        let finger: Int
    }
    private var stable: Selection?
    private var pending: (selection: Selection, since: Double)?
    private var lastTime: Double?

    mutating func reset() {
        previous = nil
        speed = 0
        bent = [false, false, false, false]
        stable = nil
        pending = nil
        lastTime = nil
        indexPressAmount = nil
        indexHistory = []
    }

    /// Capture a few recent frames of the user's raised index finger as its rest pose.
    @discardableResult
    mutating func calibrateIndexUp() -> Bool {
        guard canCalibrateIndex else { return false }
        let middle = indexHistory.map(\.middle).sorted()
        let base = indexHistory.map(\.base).sorted()
        indexRest = (middle[middle.count / 2], base[base.count / 2])
        bent[0] = false
        stable = nil
        pending = nil
        indexPressAmount = 0
        return true
    }

    mutating func clearIndexCalibration() {
        indexRest = nil
        reset()
    }

    mutating func update(hands: [TrackedHand], time: Double) -> InstrumentNote? {
        guard time.isFinite, hands.count == 2,
              hands.allSatisfy({ $0.points.count == 21 && $0.points.allSatisfy { $0.x.isFinite && $0.y.isFinite } }) else {
            reset()
            return nil
        }
        if let lastTime, time <= lastTime || time - lastTime >= 0.2 { reset() }
        lastTime = time
        let sorted = hands.sorted { $0.points[0].x < $1.points[0].x }
        // Crossed/overlapping hands are ambiguous. Silence instead of swapping notes.
        guard sorted[1].points[0].x - sorted[0].points[0].x > 0.12 else {
            reset()
            return nil
        }
        let bow = sorted[bowOnScreenLeft ? 0 : 1].points[0]
        let fingers = sorted[bowOnScreenLeft ? 1 : 0].worldPoints
        guard fingers.count == 21,
              fingers.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
            reset()
            return nil
        }
        let boundaries = [0.35, 0.52, 0.68]
        while stringIndex < 3 && bow.y > boundaries[stringIndex] + 0.035 { stringIndex += 1 }
        while stringIndex > 0 && bow.y < boundaries[stringIndex - 1] - 0.035 { stringIndex -= 1 }

        var finger = 0
        for i in 0..<4 {
            let base = 5 + 4 * i
            guard let angle = Self.jointAngle(fingers[base], fingers[base + 1], fingers[base + 2]) else {
                reset()
                return nil
            }
            if i == 0 {
                guard let baseAngle = Self.jointAngle(fingers[0], fingers[5], fingers[6]) else {
                    reset()
                    return nil
                }
                let middleFlex = 180 - angle
                let baseFlex = 180 - baseAngle
                indexHistory.append((middleFlex, baseFlex))
                if indexHistory.count > 5 { indexHistory.removeFirst() }
                // Either knuckle can press the index finger. Subtract the user's
                // raised pose so a naturally curved finger does not count as down.
                let flex = max(0, max(middleFlex - (indexRest?.middle ?? 0), baseFlex - (indexRest?.base ?? 0)))
                let threshold = 45 - 30 * max(0, min(1, indexSensitivity))
                indexPressAmount = min(1, flex / threshold)
                bent[0] = flex > threshold * (bent[0] ? 0.55 : 1)
            } else {
                bent[i] = angle < (bent[i] ? 145 : 110)
            }
            if bent[i] { finger = i + 1 }
        }
        let selection = Selection(string: stringIndex, finger: finger)
        if selection == stable {
            pending = nil
        } else if pending?.selection != selection {
            pending = (selection, time)
        } else if let pending, time - pending.since >= 0.045 {
            stable = selection
            self.pending = nil
        }
        // Highest stopped finger wins, rather than sounding a chord per bent finger.
        var amplitude = 0.0
        if let old = previous {
            let dt = time - old.time
            let movement = abs(bow.x - old.x)
            if dt > 0 && dt < 0.2 && movement < 0.15 {
                let measured = movement / dt
                let weight = 1 - exp(-dt / 0.045)
                speed += (measured - speed) * weight
                amplitude = min(0.65, max(0, speed - 0.045) * 1.1)
            } else {
                speed = 0
            }
        }
        previous = (bow.x, time)
        // Reject one-frame finger/string flicker. After tracking loss, wait for a
        // stable pose before making sound rather than briefly playing an open string.
        let sounding = stable ?? selection
        return InstrumentNote(midi: Self.notes[sounding.string][sounding.finger],
                              stringIndex: sounding.string, amplitude: stable == nil ? 0 : amplitude)
    }

    private static func jointAngle(_ a: HandPoint, _ b: HandPoint, _ c: HandPoint) -> Double? {
        let u = (x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)
        let v = (x: c.x - b.x, y: c.y - b.y, z: c.z - b.z)
        let length = sqrt(u.x*u.x + u.y*u.y + u.z*u.z) * sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
        guard length > 1e-8 else { return nil }
        let cosine = (u.x*v.x + u.y*v.y + u.z*v.z) / length
        return acos(max(-1, min(1, cosine))) * 180 / .pi
    }
}
